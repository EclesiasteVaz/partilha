import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:partilha/core/errors/failure.dart';
import 'package:partilha/core/logging/app_logger.dart';
import 'package:partilha/core/network/transport_frame.dart';
import 'package:partilha/core/platform/platform.dart';
import 'package:partilha/core/protocol/protocol.dart';
import 'package:partilha/core/result/result.dart';
import 'package:partilha/features/file_transfer/domain/domain.dart';

/// Receiver implementation of [TransferServer] using `dart:io`.
///
/// Enforces:
/// - Framing rules: JSON text for control, binary for data chunks (<= 64 KiB).
/// - Rule §33.3: Receiving a control frame during active streaming (other than
///   explicit `transfer_cancel`) is a protocol violation, aborting the transfer
///   and closing the connection.
/// - Storage validation: rejects transfer offer if destination space is insufficient.
/// - Deterministic filename conflict resolution on the receiving folder.
/// - Zero incomplete files: partial files are deleted immediately on error or cancel.
final class DartIoTransferServer implements TransferServer {
  DartIoTransferServer(
    this._logger, {
    this.storageValidation,
    this.destinationDirectoryProvider,
    this.expectedTokenProvider,
    this.receivedFileService,
  });

  final AppLogger _logger;
  final StorageValidationService? storageValidation;
  final Directory Function()? destinationDirectoryProvider;
  final String? Function()? expectedTokenProvider;
  final ReceivedFileService? receivedFileService;

  final StreamController<TransferServerEvent> _events =
      StreamController<TransferServerEvent>.broadcast();

  HttpServer? _server;
  final Set<WebSocket> _clients = <WebSocket>{};
  StreamSubscription<HttpRequest>? _subscription;

  /// The active bound port of the server, or `null` if not running.
  @override
  int? get port => _server?.port;

  @override
  Stream<TransferServerEvent> get events => _events.stream;

  @override
  Future<Result<void, Failure>> start({required int port}) async {
    if (_server != null) {
      return const Result.failure(TransferFailure.connectionLost);
    }
    try {
      final HttpServer server = await HttpServer.bind(
        InternetAddress.anyIPv4,
        port,
        shared: true,
      );
      _server = server;
      _subscription = server.listen(_handleRequest);
      _events.add(TransferServerListening(port: server.port));
      return const Result.success(null);
    } on SocketException catch (e, st) {
      _logger.warning(
        'Failed to bind transfer server',
        error: e,
        stackTrace: st,
      );
      return const Result.failure(TransferFailure.connectionLost);
    } on Object catch (e, st) {
      _logger.failure(
        'Failed to start transfer server',
        TransferFailure.connectionLost,
        context: <String, Object?>{},
        stackTrace: st,
      );
      return const Result.failure(TransferFailure.connectionLost);
    }
  }

  @override
  Future<Result<void, Failure>> stop() async {
    if (_server == null) return const Result.success(null);
    await _subscription?.cancel();
    _subscription = null;
    for (final WebSocket ws in _clients.toList()) {
      await ws.close();
    }
    _clients.clear();
    await _server?.close(force: true);
    _server = null;
    return const Result.success(null);
  }

  Future<void> _handleRequest(HttpRequest request) async {
    try {
      final WebSocket ws = await WebSocketTransformer.upgrade(request);
      _clients.add(ws);

      // Session state for this connection
      var isPaired = expectedTokenProvider == null;
      String? activeWireTransferId;
      String? activeFileName;
      int? activeTotalBytes;
      var bytesReceived = 0;
      IOSink? activeSink;
      File? activeFile;
      var isStreaming = false;

      Future<void> cleanupPartialFile() async {
        try {
          if (activeSink != null) {
            await activeSink?.close();
            activeSink = null;
          }
          if (activeFile != null && activeFile!.existsSync()) {
            await activeFile?.delete();
            activeFile = null;
          }
        } on Object catch (e, st) {
          _logger.warning(
            'Error cleaning partial file',
            error: e,
            stackTrace: st,
          );
        }
      }

      void sendControlMessage(ControlMessage msg) {
        try {
          ws.add(jsonEncode(msg.toJson()));
        } on Object catch (e) {
          _logger.warning('Failed to send control message: $e');
        }
      }

      final StreamSubscription<Object?> sub = ws.listen(
        (Object? data) async {
          if (data is String) {
            // Text frame -> Control message
            final decoded = ControlMessageCodec.decode(data);
            if (decoded is ControlMalformed) {
              if (isStreaming) {
                await cleanupPartialFile();
                isStreaming = false;
              }
              sendControlMessage(
                ControlMessageCodec.errorMessage(
                  id: 'err_malformed',
                  code: ProtocolErrorCode.invalidMessage,
                ),
              );
              unawaited(
                ws.close(WebSocketStatus.protocolError, decoded.reason),
              );
              return;
            }

            if (decoded is ControlDecoded) {
              final msg = decoded.message;

              // Rule §33.3: if streaming, NO control frame allowed except transfer_cancel
              if (isStreaming) {
                if (msg.type == ProtocolMessageTypes.transferCancel) {
                  await cleanupPartialFile();
                  isStreaming = false;
                  activeWireTransferId = null;
                  _events.add(
                    TransferServerError(failure: TransferFailure.cancelled),
                  );
                  return;
                } else {
                  // Protocol violation
                  await cleanupPartialFile();
                  isStreaming = false;
                  sendControlMessage(
                    ControlMessageCodec.errorMessage(
                      id: msg.id,
                      code: ProtocolErrorCode.invalidMessage,
                      message:
                          'Control frame during active binary stream (§33.3)',
                    ),
                  );
                  _events.add(
                    TransferServerError(
                      failure: TransferFailure.protocolViolation,
                    ),
                  );
                  unawaited(
                    ws.close(
                      WebSocketStatus.protocolError,
                      'Control frame during active binary stream (§33.3)',
                    ),
                  );
                  return;
                }
              }

              // Normal control dispatch (when not streaming)
              if (msg.type == ProtocolMessageTypes.pairRequest) {
                try {
                  final pairPayload = PairRequestPayload.fromJson(msg.payload);
                  final expectedToken = expectedTokenProvider?.call();
                  final valid =
                      expectedToken == null ||
                      expectedToken == pairPayload.token;
                  isPaired = valid;

                  sendControlMessage(
                    ControlMessage(
                      type: ProtocolMessageTypes.pairResponse,
                      id: 'resp_${msg.id}',
                      payload: PairResponsePayload(
                        accepted: valid,
                        reason: valid ? null : 'Unauthorized token',
                      ).toJson(),
                    ),
                  );
                } on Object catch (_) {
                  sendControlMessage(
                    ControlMessage(
                      type: ProtocolMessageTypes.pairResponse,
                      id: 'resp_${msg.id}',
                      payload: const PairResponsePayload(
                        accepted: false,
                        reason: 'Malformed pair request',
                      ).toJson(),
                    ),
                  );
                }
              } else if (msg.type == ProtocolMessageTypes.transferOffer) {
                try {
                  final offer = TransferOfferPayload.fromJson(msg.payload);

                  if (!isPaired) {
                    sendControlMessage(
                      ControlMessage(
                        type: ProtocolMessageTypes.transferReject,
                        id: 'reject_${msg.id}',
                        payload: TransferRejectPayload(
                          wireTransferId: offer.wireTransferId,
                          reason: 'Not paired',
                        ).toJson(),
                      ),
                    );
                    return;
                  }

                  final destDir =
                      destinationDirectoryProvider?.call() ??
                      Directory.systemTemp;

                  // Validate storage space
                  final validator = storageValidation;
                  if (validator != null) {
                    final spaceCheck = await validator.check(
                      path: destDir.path,
                      sizeInBytes: offer.size,
                    );
                    final status = spaceCheck.valueOrNull;
                    if (spaceCheck.isFailure ||
                        (status != null && !status.hasEnoughSpace)) {
                      sendControlMessage(
                        ControlMessage(
                          type: ProtocolMessageTypes.transferReject,
                          id: 'reject_${msg.id}',
                          payload: TransferRejectPayload(
                            wireTransferId: offer.wireTransferId,
                            reason: 'Insufficient storage',
                          ).toJson(),
                        ),
                      );
                      sendControlMessage(
                        ControlMessageCodec.errorMessage(
                          id: msg.id,
                          code: ProtocolErrorCode.insufficientStorage,
                        ),
                      );
                      _events.add(
                        TransferServerError(
                          failure:
                              spaceCheck.errorOrNull ??
                              StorageFailure.insufficientSpace,
                        ),
                      );
                      return;
                    }
                  }

                  // Resolve filename conflict
                  final resolvedName = resolveFilenameConflict(
                    offer.fileName,
                    (candidate) =>
                        File('${destDir.path}/$candidate').existsSync(),
                  );

                  final destinationFile = File('${destDir.path}/$resolvedName');
                  activeFile = destinationFile;
                  activeSink = destinationFile.openWrite();
                  activeWireTransferId = offer.wireTransferId;
                  activeFileName = resolvedName;
                  activeTotalBytes = offer.size;
                  bytesReceived = 0;
                  isStreaming = true;

                  sendControlMessage(
                    ControlMessage(
                      type: ProtocolMessageTypes.transferAccept,
                      id: 'accept_${msg.id}',
                      payload: TransferAcceptPayload(
                        wireTransferId: offer.wireTransferId,
                      ).toJson(),
                    ),
                  );

                  _events.add(
                    TransferServerOfferReceived(
                      offer: TransferOffer(
                        id: offer.wireTransferId,
                        name: resolvedName,
                        sizeInBytes: offer.size,
                        meta: const <String, String>{},
                      ),
                    ),
                  );
                } on Object catch (e) {
                  _logger.warning('Failed to handle transfer offer: $e');
                  sendControlMessage(
                    ControlMessageCodec.errorMessage(
                      id: msg.id,
                      code: ProtocolErrorCode.invalidMessage,
                    ),
                  );
                }
              } else if (msg.type == ProtocolMessageTypes.transferCancel) {
                if (activeWireTransferId != null &&
                    activeWireTransferId == msg.payload['wireTransferId']) {
                  await cleanupPartialFile();
                  isStreaming = false;
                  activeWireTransferId = null;
                }
              }
            }
          } else if (data is List<int>) {
            // Binary frame -> Data chunk
            if (!isStreaming || activeSink == null) {
              unawaited(
                ws.close(
                  WebSocketStatus.protocolError,
                  'Unexpected binary frame',
                ),
              );
              return;
            }

            if (data.length > kMaxFrameBytes) {
              await cleanupPartialFile();
              isStreaming = false;
              _events.add(
                TransferServerError(failure: TransferFailure.protocolViolation),
              );
              sendControlMessage(
                ControlMessageCodec.errorMessage(
                  id: 'err_oversized',
                  code: ProtocolErrorCode.invalidMessage,
                  message: 'Frame exceeds maximum allowed size (§33.2)',
                ),
              );
              unawaited(
                ws.close(WebSocketStatus.protocolError, 'Frame too large'),
              );
              _clients.remove(ws);
              return;
            }

            try {
              activeSink!.add(data);
              bytesReceived += data.length;

              _events.add(
                TransferServerBytesReceived(
                  transferId: activeWireTransferId!,
                  bytes: Uint8List.fromList(data),
                ),
              );

              if (activeTotalBytes != null &&
                  bytesReceived >= activeTotalBytes!) {
                await activeSink!.flush();
                await activeSink!.close();
                activeSink = null;
                isStreaming = false;

                final String stagedPath = activeFile!.path;
                final String stagedName = activeFileName!;
                final String finalPath = receivedFileService != null
                    ? await receivedFileService!.finalizeReceivedFile(
                        sourcePath: stagedPath,
                        fileName: stagedName,
                      )
                    : stagedPath;

                sendControlMessage(
                  ControlMessage(
                    type: ProtocolMessageTypes.transferComplete,
                    id: 'complete_${DateTime.now().millisecondsSinceEpoch}',
                    payload: TransferCompletePayload(
                      wireTransferId: activeWireTransferId!,
                    ).toJson(),
                  ),
                );

                _events.add(
                  TransferServerDone(
                    transferId: activeWireTransferId!,
                    file: SelectedFile(
                      name: stagedName,
                      path: finalPath,
                      sizeInBytes: bytesReceived,
                    ),
                  ),
                );

                activeWireTransferId = null;
                activeFile = null;
              }
            } on Object catch (e) {
              _logger.warning('Failed writing data chunk to storage: $e');
              await cleanupPartialFile();
              isStreaming = false;
              activeWireTransferId = null;
              activeFile = null;
              _events.add(
                TransferServerError(failure: StorageFailure.writeFailed),
              );
              sendControlMessage(
                ControlMessageCodec.errorMessage(
                  id: 'err_write',
                  code: ProtocolErrorCode.insufficientStorage,
                  message: 'Write failed: $e',
                ),
              );
            }
          }
        },
        onDone: () async {
          if (isStreaming) {
            await cleanupPartialFile();
          }
          _clients.remove(ws);
        },
        onError: (Object error) async {
          if (isStreaming) {
            await cleanupPartialFile();
          }
          _clients.remove(ws);
        },
      );

      ws.done.then((_) => sub.cancel());
    } on Object catch (e, st) {
      _logger.warning('Rejected WebSocket upgrade', error: e, stackTrace: st);
      await request.response.close();
    }
  }
}
