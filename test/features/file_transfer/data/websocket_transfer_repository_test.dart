import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:partilha/core/errors/failure.dart';
import 'package:partilha/core/network/transport_frame.dart';
import 'package:partilha/core/network/websocket_transport.dart';
import 'package:partilha/core/protocol/protocol.dart';
import 'package:partilha/core/result/result.dart';
import 'package:partilha/features/file_transfer/data/websocket_transfer_repository.dart';
import 'package:partilha/features/file_transfer/domain/domain.dart';
import 'package:partilha/features/pairing/application/get_device_identity_use_case.dart';
import 'package:partilha/features/pairing/domain/domain.dart';
import 'package:partilha/features/settings/application/get_device_name_use_case.dart';
import 'package:partilha/features/settings/domain/domain.dart';

final class FakeWebSocketTransport implements WebSocketTransport {
  final StreamController<TransportEvent> _eventsController =
      StreamController<TransportEvent>.broadcast();

  final List<String> sentControlMessages = <String>[];
  final List<List<int>> sentDataChunks = <List<int>>[];
  bool connected = true;

  @override
  Stream<TransportEvent> get events => _eventsController.stream;

  @override
  bool get isConnected => connected;

  @override
  Future<Result<void, Failure>> connect(TransportTarget target) async {
    connected = true;
    _eventsController.add(const TransportConnected());
    return const Result.success(null);
  }

  @override
  Future<Result<void, Failure>> sendControl(String json) async {
    sentControlMessages.add(json);
    return const Result.success(null);
  }

  @override
  Future<Result<void, Failure>> sendData(List<int> bytes) async {
    sentDataChunks.add(bytes);
    return const Result.success(null);
  }

  @override
  Future<Result<void, Failure>> sendStream(
    Stream<List<int>> source, {
    Future<void>? stop,
  }) async {
    final completer = Completer<Result<void, Failure>>();
    final sub = source.listen(
      sentDataChunks.add,
      onError: (Object error) {
        if (!completer.isCompleted) {
          completer.complete(
            const Result.failure(TransferFailure.connectionLost),
          );
        }
      },
      onDone: () {
        if (!completer.isCompleted) {
          completer.complete(const Result.success(null));
        }
      },
    );

    if (stop != null) {
      unawaited(
        stop.then((_) {
          unawaited(sub.cancel());
          if (!completer.isCompleted) {
            completer.complete(const Result.failure(TransferFailure.cancelled));
          }
        }),
      );
    }

    return completer.future;
  }

  @override
  Future<void> close() async {
    connected = false;
    _eventsController.add(const TransportDisconnected(null));
  }

  void emitControl(ControlMessage message) {
    _eventsController.add(ControlReceived(jsonEncode(message.toJson())));
  }
}

void main() {
  late Directory tempDir;
  late File testFile;
  late FakeWebSocketTransport fakeTransport;
  late WebSocketTransferRepository repository;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('repo_test_');
    testFile = File('${tempDir.path}/sample.txt')
      ..writeAsStringSync('Hello Partilha Stream!');
    fakeTransport = FakeWebSocketTransport();
    repository = WebSocketTransferRepository(transport: fakeTransport);
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  test('happy path: handshake -> offer -> stream -> complete', () async {
    const destination = TransferDestination(
      deviceId: 'receiver-1',
      deviceName: 'Receiver Device',
      address: '127.0.0.1',
      port: 8080,
      token: 'valid-token',
    );

    final request = TransferRequest(
      id: 'req-1',
      destination: destination,
      file: SelectedFile(
        name: 'sample.txt',
        path: testFile.path,
        sizeInBytes: testFile.lengthSync(),
      ),
    );

    final progressEvents = <FileTransferProgress>[];
    final progressCompleter = Completer<void>();

    // Listen to sentControlMessages and reply accordingly
    Timer.periodic(const Duration(milliseconds: 10), (timer) {
      for (final msgJson in fakeTransport.sentControlMessages) {
        final decoded = ControlMessageCodec.decode(msgJson);
        if (decoded is ControlDecoded) {
          final msg = decoded.message;
          if (msg.type == ProtocolMessageTypes.pairRequest) {
            fakeTransport.emitControl(
              ControlMessage(
                type: ProtocolMessageTypes.pairResponse,
                id: 'resp-pair',
                payload: const PairResponsePayload(accepted: true).toJson(),
              ),
            );
          } else if (msg.type == ProtocolMessageTypes.transferOffer) {
            final wireId = msg.payload['wireTransferId'] as String;
            fakeTransport.emitControl(
              ControlMessage(
                type: ProtocolMessageTypes.transferAccept,
                id: 'resp-accept',
                payload: TransferAcceptPayload(wireTransferId: wireId).toJson(),
              ),
            );

            // After data chunks arrive, emit complete
            Future.delayed(const Duration(milliseconds: 30), () {
              fakeTransport.emitControl(
                ControlMessage(
                  type: ProtocolMessageTypes.transferComplete,
                  id: 'resp-complete',
                  payload: TransferCompletePayload(
                    wireTransferId: wireId,
                  ).toJson(),
                ),
              );
            });
            timer.cancel();
            break;
          }
        }
      }
    });

    final stream = repository.send(request);
    stream.listen(
      progressEvents.add,
      onDone: progressCompleter.complete,
      onError: progressCompleter.completeError,
    );

    await progressCompleter.future;

    expect(progressEvents, isNotEmpty);
    expect(progressEvents.first.bytesTransferred, 0);
    expect(progressEvents.last.bytesTransferred, testFile.lengthSync());
    expect(fakeTransport.sentDataChunks, isNotEmpty);
  });

  test(
    'offer rejected by receiver emits TransferFailure.remoteRejected',
    () async {
      const destination = TransferDestination(
        deviceId: 'receiver-1',
        deviceName: 'Receiver Device',
        address: '127.0.0.1',
        port: 8080,
      );

      final request = TransferRequest(
        id: 'req-2',
        destination: destination,
        file: SelectedFile(
          name: 'sample.txt',
          path: testFile.path,
          sizeInBytes: testFile.lengthSync(),
        ),
      );

      Timer.periodic(const Duration(milliseconds: 10), (timer) {
        for (final msgJson in fakeTransport.sentControlMessages) {
          final decoded = ControlMessageCodec.decode(msgJson);
          if (decoded is ControlDecoded) {
            final msg = decoded.message;
            if (msg.type == ProtocolMessageTypes.transferOffer) {
              final wireId = msg.payload['wireTransferId'] as String;
              fakeTransport.emitControl(
                ControlMessage(
                  type: ProtocolMessageTypes.transferReject,
                  id: 'resp-reject',
                  payload: TransferRejectPayload(
                    wireTransferId: wireId,
                    reason: 'No space',
                  ).toJson(),
                ),
              );
              timer.cancel();
              break;
            }
          }
        }
      });

      expect(
        () => repository.send(request).drain<void>(),
        throwsA(isA<TransferFailure>()),
      );
    },
  );

  test(
    'connects when transport is disconnected and certificateFingerprint is null',
    () async {
      fakeTransport.connected = false;
      const destination = TransferDestination(
        deviceId: 'receiver-plain',
        deviceName: 'Plain Receiver',
        address: '127.0.0.1',
        port: 8080,
      );

      final request = TransferRequest(
        id: 'req-unpinned',
        destination: destination,
        file: SelectedFile(
          name: 'sample.txt',
          path: testFile.path,
          sizeInBytes: testFile.lengthSync(),
        ),
      );

      Timer.periodic(const Duration(milliseconds: 10), (timer) {
        for (final msgJson in fakeTransport.sentControlMessages) {
          final decoded = ControlMessageCodec.decode(msgJson);
          if (decoded is ControlDecoded &&
              decoded.message.type == ProtocolMessageTypes.transferOffer) {
            final wireId = decoded.message.payload['wireTransferId'] as String;
            fakeTransport.emitControl(
              ControlMessage(
                type: ProtocolMessageTypes.transferAccept,
                id: 'accept-1',
                payload: TransferAcceptPayload(wireTransferId: wireId).toJson(),
              ),
            );
            Future.delayed(const Duration(milliseconds: 20), () {
              fakeTransport.emitControl(
                ControlMessage(
                  type: ProtocolMessageTypes.transferComplete,
                  id: 'comp-1',
                  payload: TransferCompletePayload(
                    wireTransferId: wireId,
                  ).toJson(),
                ),
              );
            });
            timer.cancel();
            break;
          }
        }
      });

      final events = await repository.send(request).toList();
      expect(fakeTransport.isConnected, isTrue);
      expect(events.last.bytesTransferred, testFile.lengthSync());
    },
  );

  test('closeSession disconnects active transport and clears it', () async {
    expect(fakeTransport.isConnected, isTrue);
    await repository.closeSession();
    expect(fakeTransport.isConnected, isFalse);
  });

  test('send uses device identity and device name in handshake', () async {
    final fakePairingRepo = _FakePairingRepository();
    final fakeSettingsRepo = _FakeSettingsRepository();
    final customRepo = WebSocketTransferRepository(
      transport: fakeTransport,
      getDeviceIdentityUseCase: GetDeviceIdentityUseCase(fakePairingRepo),
      getDeviceNameUseCase: GetDeviceNameUseCase(fakeSettingsRepo),
    );

    const destination = TransferDestination(
      deviceId: 'receiver-1',
      deviceName: 'Receiver Device',
      address: '127.0.0.1',
      port: 8080,
      token: 'valid-token',
    );

    final request = TransferRequest(
      id: 'req-handshake',
      destination: destination,
      file: SelectedFile(
        name: 'sample.txt',
        path: testFile.path,
        sizeInBytes: testFile.lengthSync(),
      ),
    );

    Timer.periodic(const Duration(milliseconds: 10), (timer) {
      for (final msgJson in fakeTransport.sentControlMessages) {
        final decoded = ControlMessageCodec.decode(msgJson);
        if (decoded is ControlDecoded) {
          final msg = decoded.message;
          if (msg.type == ProtocolMessageTypes.pairRequest) {
            fakeTransport.emitControl(
              ControlMessage(
                type: ProtocolMessageTypes.pairResponse,
                id: 'resp-pair',
                payload: const PairResponsePayload(accepted: true).toJson(),
              ),
            );
          } else if (msg.type == ProtocolMessageTypes.transferOffer) {
            final wireId = msg.payload['wireTransferId'] as String;
            fakeTransport.emitControl(
              ControlMessage(
                type: ProtocolMessageTypes.transferAccept,
                id: 'resp-accept',
                payload: TransferAcceptPayload(wireTransferId: wireId).toJson(),
              ),
            );
            Future.delayed(const Duration(milliseconds: 20), () {
              fakeTransport.emitControl(
                ControlMessage(
                  type: ProtocolMessageTypes.transferComplete,
                  id: 'resp-complete',
                  payload: TransferCompletePayload(
                    wireTransferId: wireId,
                  ).toJson(),
                ),
              );
            });
            timer.cancel();
            break;
          }
        }
      }
    });

    await customRepo.send(request).drain<void>();

    final pairReqMsg = fakeTransport.sentControlMessages
        .map(ControlMessageCodec.decode)
        .whereType<ControlDecoded>()
        .firstWhere((d) => d.message.type == ProtocolMessageTypes.pairRequest);
    expect(pairReqMsg.message.payload['deviceId'], 'rec-dev');
    expect(pairReqMsg.message.payload['deviceName'], 'Receiver Mac');
    expect(pairReqMsg.message.payload['token'], 'valid-token');
  });
}

class _FakePairingRepository implements PairingRepository {
  @override
  Future<Result<DeviceIdentity, Failure>> getOrCreateIdentity() async {
    return const Result.success(
      DeviceIdentity(deviceId: 'rec-dev', token: 'secret-tok'),
    );
  }
}

class _FakeSettingsRepository implements SettingsRepository {
  @override
  Future<Result<DeviceName, Failure>> readDeviceName() async {
    return Result.success(DeviceName.create('Receiver Mac').valueOrNull!);
  }

  @override
  Future<Result<void, Failure>> saveDeviceName(DeviceName name) async {
    return const Result.success(null);
  }
}
