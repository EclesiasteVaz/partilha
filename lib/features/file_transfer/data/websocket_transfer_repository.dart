import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:partilha/core/errors/failure.dart';
import 'package:partilha/core/logging/app_logger.dart';
import 'package:partilha/core/network/certificate_fingerprint.dart';
import 'package:partilha/core/network/dart_io_websocket_transport.dart';
import 'package:partilha/core/network/transport_frame.dart';
import 'package:partilha/core/network/websocket_transport.dart';
import 'package:partilha/core/protocol/protocol.dart';
import 'package:partilha/features/file_transfer/domain/domain.dart';

/// Sender implementation of [TransferRepository] over [WebSocketTransport].
///
/// Implements the approved flow:
/// 1. Handshake (if token present): `pair_request` -> `pair_response`.
/// 2. Offer: `transfer_offer` -> `transfer_accept` (or `transfer_reject`).
/// 3. Data stream: binary frames via [WebSocketTransport.sendStream] in chunks <= 64 KiB.
/// 4. Confirmation: awaits `transfer_complete` before declaring success.
/// 5. Cancellation: emits `transfer_cancel` and signals stop to the stream.
class WebSocketTransferRepository implements TransferRepository {
  WebSocketTransferRepository({
    this.transport,
    this.transportFactory,
    AppLogger? logger,
  }) : _logger =
           logger ??
           StructuredLogger(
             sink: const ConsoleLogSink(),
             threshold: LogLevel.error,
           );

  final WebSocketTransport? transport;
  final WebSocketTransport Function()? transportFactory;
  final AppLogger _logger;

  @override
  Stream<FileTransferProgress> send(TransferRequest request) {
    // ignore: close_sinks
    final controller = StreamController<FileTransferProgress>();
    final stopCompleter = Completer<void>();
    var cancelled = false;
    String? activeWireTransferId;
    WebSocketTransport? activeTransport;

    controller.onCancel = () {
      cancelled = true;
      if (!stopCompleter.isCompleted) {
        stopCompleter.complete();
      }
      if (activeWireTransferId != null &&
          activeTransport?.isConnected == true) {
        final cancelMsg = ControlMessage(
          type: ProtocolMessageTypes.transferCancel,
          id: 'cancel_${DateTime.now().millisecondsSinceEpoch}',
          payload: TransferCancelPayload(
            wireTransferId: activeWireTransferId!,
          ).toJson(),
        );
        unawaited(activeTransport!.sendControl(jsonEncode(cancelMsg.toJson())));
      }
    };

    unawaited(
      _executeSend(
        request: request,
        controller: controller,
        stopCompleter: stopCompleter,
        onSessionReady: (transport, wireId) {
          activeTransport = transport;
          activeWireTransferId = wireId;
        },
        isCancelled: () => cancelled,
      ),
    );

    return controller.stream;
  }

  Future<void> _executeSend({
    required TransferRequest request,
    required StreamController<FileTransferProgress> controller,
    required Completer<void> stopCompleter,
    required void Function(WebSocketTransport transport, String wireId)
    onSessionReady,
    required bool Function() isCancelled,
  }) async {
    try {
      final file = File(request.file.path);
      if (!file.existsSync()) {
        controller.addError(
          const StorageFailure(userMessage: 'The file to send does not exist.'),
        );
        await controller.close();
        return;
      }

      final totalBytes = request.sizeInBytes ?? file.lengthSync();
      final factory = transportFactory;
      final transport =
          this.transport ??
          (factory != null ? factory() : DartIoWebSocketTransport(_logger));

      // 1. Connect if needed
      if (!transport.isConnected) {
        final fingerprintStr = request.destination.certificateFingerprint;
        final fingerprint = fingerprintStr != null
            ? CertificateFingerprint.parse(fingerprintStr).valueOrNull
            : null;

        if (fingerprint == null) {
          // If no certificate fingerprint was provided, connection cannot be pinned.
          // In production, unpinned connections violate security policy (§26.1).
          controller.addError(PairingFailure.invalidPayload);
          await controller.close();
          return;
        }

        final target = TransportTarget(
          host: request.destination.address,
          port: request.destination.port,
          certificateFingerprint: fingerprint,
        );

        final connectResult = await transport.connect(target);
        if (connectResult.isFailure) {
          controller.addError(connectResult.errorOrNull!);
          await controller.close();
          return;
        }
      }

      if (isCancelled()) return;

      // 2. Handshake if token present
      final token = request.destination.token;
      if (token != null && token.isNotEmpty) {
        final pairId = 'pair_${DateTime.now().millisecondsSinceEpoch}';
        final pairPayload = PairRequestPayload(
          deviceId: 'local_device',
          deviceName: 'Partilha Device',
          token: token,
        );
        final pairMsg = ControlMessage(
          type: ProtocolMessageTypes.pairRequest,
          id: pairId,
          payload: pairPayload.toJson(),
        );

        final sendPairResult = await transport.sendControl(
          jsonEncode(pairMsg.toJson()),
        );
        if (sendPairResult.isFailure) {
          controller.addError(sendPairResult.errorOrNull!);
          await controller.close();
          return;
        }

        final pairRespMsg = await _waitForControlResponse(
          transport,
          expectedType: ProtocolMessageTypes.pairResponse,
        );

        final pairResp = PairResponsePayload.fromJson(pairRespMsg.payload);
        if (!pairResp.accepted) {
          controller.addError(PairingFailure.rejected);
          await controller.close();
          return;
        }
      }

      if (isCancelled()) return;

      // 3. Transfer Offer
      final wireTransferId = WireTransferId.generate().value;
      onSessionReady(transport, wireTransferId);

      final offerId = 'offer_${DateTime.now().millisecondsSinceEpoch}';
      final offerPayload = TransferOfferPayload(
        wireTransferId: wireTransferId,
        fileName: request.file.name,
        size: totalBytes,
      );
      final offerMsg = ControlMessage(
        type: ProtocolMessageTypes.transferOffer,
        id: offerId,
        payload: offerPayload.toJson(),
      );

      final sendOfferResult = await transport.sendControl(
        jsonEncode(offerMsg.toJson()),
      );
      if (sendOfferResult.isFailure) {
        controller.addError(sendOfferResult.errorOrNull!);
        await controller.close();
        return;
      }

      final acceptOrRejectMsg = await _waitForControlResponse(
        transport,
        expectedTypes: <String>[
          ProtocolMessageTypes.transferAccept,
          ProtocolMessageTypes.transferReject,
        ],
        wireTransferId: wireTransferId,
      );

      if (acceptOrRejectMsg.type == ProtocolMessageTypes.transferReject) {
        controller.addError(TransferFailure.remoteRejected);
        await controller.close();
        return;
      }

      if (isCancelled()) return;

      // 4. Initial progress
      controller.add(
        FileTransferProgress(
          transferId: request.id,
          bytesTransferred: 0,
          totalBytes: totalBytes,
        ),
      );

      // 5. Stream data in <= 64 KiB frames
      var bytesSent = 0;
      final readStream = file.openRead().transform<List<int>>(
        StreamTransformer<List<int>, List<int>>.fromHandlers(
          handleData: (chunk, sink) {
            for (
              var offset = 0;
              offset < chunk.length;
              offset += kMaxFrameBytes
            ) {
              final end = (offset + kMaxFrameBytes < chunk.length)
                  ? offset + kMaxFrameBytes
                  : chunk.length;
              final slice = chunk.sublist(offset, end);
              bytesSent += slice.length;
              if (!controller.isClosed) {
                controller.add(
                  FileTransferProgress(
                    transferId: request.id,
                    bytesTransferred: bytesSent,
                    totalBytes: totalBytes,
                  ),
                );
              }
              sink.add(slice);
            }
          },
        ),
      );

      final streamResult = await transport.sendStream(
        readStream,
        stop: stopCompleter.future,
      );

      if (streamResult.isFailure) {
        controller.addError(streamResult.errorOrNull!);
        await controller.close();
        return;
      }

      if (isCancelled()) return;

      // 6. Wait for transfer_complete from receiver
      final completeMsg = await _waitForControlResponse(
        transport,
        expectedType: ProtocolMessageTypes.transferComplete,
        wireTransferId: wireTransferId,
      );

      if (completeMsg.type == ProtocolMessageTypes.transferComplete) {
        controller.add(
          FileTransferProgress(
            transferId: request.id,
            bytesTransferred: totalBytes,
            totalBytes: totalBytes,
          ),
        );
      }

      await controller.close();
    } on Failure catch (failure) {
      if (!controller.isClosed) {
        controller.addError(failure);
        await controller.close();
      }
    } on Object catch (error, st) {
      _logger.warning(
        'Unexpected error during send',
        error: error,
        stackTrace: st,
      );
      if (!controller.isClosed) {
        controller.addError(TransferFailure.connectionLost);
        await controller.close();
      }
    }
  }

  Future<ControlMessage> _waitForControlResponse(
    WebSocketTransport transport, {
    List<String>? expectedTypes,
    String? expectedType,
    String? wireTransferId,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final completer = Completer<ControlMessage>();
    late StreamSubscription<TransportEvent> sub;

    final timer = Timer(timeout, () {
      if (!completer.isCompleted) {
        unawaited(sub.cancel());
        completer.completeError(NetworkFailure.timedOut);
      }
    });

    sub = transport.events.listen(
      (event) {
        if (event is ControlReceived) {
          final decoded = ControlMessageCodec.decode(event.payload);
          if (decoded is ControlDecoded) {
            final msg = decoded.message;
            if (msg.isError) {
              unawaited(sub.cancel());
              timer.cancel();
              completer.completeError(
                decoded.error?.failure ?? TransferFailure.protocolViolation,
              );
              return;
            }

            if (msg.type == ProtocolMessageTypes.transferCancel) {
              unawaited(sub.cancel());
              timer.cancel();
              completer.completeError(TransferFailure.cancelled);
              return;
            }

            final matchesType = expectedType != null
                ? msg.type == expectedType
                : (expectedTypes != null && expectedTypes.contains(msg.type));

            if (matchesType) {
              if (wireTransferId != null) {
                final payloadWireId = msg.payload['wireTransferId'];
                if (payloadWireId != wireTransferId) {
                  return;
                }
              }
              unawaited(sub.cancel());
              timer.cancel();
              completer.complete(msg);
            }
          }
        } else if (event is TransportDisconnected) {
          unawaited(sub.cancel());
          timer.cancel();
          if (!completer.isCompleted) {
            completer.completeError(
              event.reason ?? TransferFailure.connectionLost,
            );
          }
        } else if (event is ControlDuringDataStream) {
          unawaited(sub.cancel());
          timer.cancel();
          if (!completer.isCompleted) {
            completer.completeError(TransferFailure.protocolViolation);
          }
        }
      },
      onError: (Object error) {
        unawaited(sub.cancel());
        timer.cancel();
        if (!completer.isCompleted) {
          completer.completeError(TransferFailure.connectionLost);
        }
      },
      onDone: () {
        timer.cancel();
        if (!completer.isCompleted) {
          completer.completeError(TransferFailure.connectionLost);
        }
      },
    );

    return completer.future;
  }
}
