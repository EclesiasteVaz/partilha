import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:partilha/core/errors/failure.dart';
import 'package:partilha/core/logging/app_logger.dart';
import 'package:partilha/core/protocol/protocol.dart';
import 'package:partilha/core/result/result.dart';
import 'package:partilha/features/file_transfer/data/dart_io_transfer_server.dart';
import 'package:partilha/features/file_transfer/domain/domain.dart';

final class FakeStorageValidationService implements StorageValidationService {
  FakeStorageValidationService({this.hasEnoughSpace = true});

  bool hasEnoughSpace;

  @override
  Future<Result<StorageStatus, Failure>> check({
    required String path,
    required int? sizeInBytes,
  }) async {
    return Result.success(StorageStatus(hasEnoughSpace: hasEnoughSpace));
  }
}

void main() {
  late Directory tempDir;
  late DartIoTransferServer server;
  late FakeStorageValidationService storageValidation;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('server_test_');
    storageValidation = FakeStorageValidationService(hasEnoughSpace: true);
    server = DartIoTransferServer(
      StructuredLogger(sink: RecordingLogSink()),
      storageValidation: storageValidation,
      destinationDirectoryProvider: () => tempDir,
      expectedTokenProvider: () => 'valid-token',
    );
  });

  tearDown(() async {
    await server.stop();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  test('happy path: handshake -> offer -> binary frames -> complete', () async {
    final startRes = await server.start(port: 0);
    expect(startRes.isSuccess, isTrue);

    final port = server.port!;

    final ws = await WebSocket.connect('ws://127.0.0.1:$port');
    final responses = <ControlMessage>[];

    final doneCompleter = Completer<void>();
    ws.listen((data) {
      if (data is String) {
        final decoded = ControlMessageCodec.decode(data);
        if (decoded is ControlDecoded) {
          responses.add(decoded.message);
          if (decoded.message.type == ProtocolMessageTypes.transferComplete) {
            doneCompleter.complete();
          }
        }
      }
    });

    // 1. Handshake
    ws.add(
      jsonEncode(
        const ControlMessage(
          type: ProtocolMessageTypes.pairRequest,
          id: 'p-1',
          payload: <String, dynamic>{
            'deviceId': 'd1',
            'deviceName': 'Device 1',
            'token': 'valid-token',
          },
        ).toJson(),
      ),
    );

    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(
      responses.any(
        (m) =>
            m.type == ProtocolMessageTypes.pairResponse &&
            m.payload['accepted'] == true,
      ),
      isTrue,
    );

    // 2. Offer
    final fileBytes = utf8.encode('Hello World Stream Data');
    ws.add(
      jsonEncode(
        ControlMessage(
          type: ProtocolMessageTypes.transferOffer,
          id: 'o-1',
          payload: TransferOfferPayload(
            wireTransferId: 'w-1',
            fileName: 'file.txt',
            size: fileBytes.length,
          ).toJson(),
        ).toJson(),
      ),
    );

    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(
      responses.any((m) => m.type == ProtocolMessageTypes.transferAccept),
      isTrue,
    );

    // 3. Binary stream
    ws.add(fileBytes);

    await doneCompleter.future;

    final writtenFile = File('${tempDir.path}/file.txt');
    expect(writtenFile.existsSync(), isTrue);
    expect(writtenFile.readAsStringSync(), 'Hello World Stream Data');

    await ws.close();
  });

  test(
    'rule §33.3: control frame during active stream triggers protocol violation and cleans partial file',
    () async {
      final startRes = await server.start(port: 0);
      expect(startRes.isSuccess, isTrue);

      final port = server.port!;

      final ws = await WebSocket.connect('ws://127.0.0.1:$port');
      final responses = <ControlMessage>[];

      ws.listen((data) {
        if (data is String) {
          final decoded = ControlMessageCodec.decode(data);
          if (decoded is ControlDecoded) {
            responses.add(decoded.message);
          }
        }
      });

      // Handshake
      ws.add(
        jsonEncode(
          const ControlMessage(
            type: ProtocolMessageTypes.pairRequest,
            id: 'p-1',
            payload: <String, dynamic>{
              'deviceId': 'd1',
              'deviceName': 'Device 1',
              'token': 'valid-token',
            },
          ).toJson(),
        ),
      );

      await Future<void>.delayed(const Duration(milliseconds: 30));

      // Offer 100 bytes
      ws.add(
        jsonEncode(
          ControlMessage(
            type: ProtocolMessageTypes.transferOffer,
            id: 'o-1',
            payload: const TransferOfferPayload(
              wireTransferId: 'w-viol',
              fileName: 'partial.txt',
              size: 100,
            ).toJson(),
          ).toJson(),
        ),
      );

      await Future<void>.delayed(const Duration(milliseconds: 30));

      // Send only 10 bytes (active stream ongoing)
      ws.add(List<int>.filled(10, 1));
      await Future<void>.delayed(const Duration(milliseconds: 20));

      // Send a forbidden control frame while streaming!
      ws.add(
        jsonEncode(
          const ControlMessage(
            type: 'ping',
            id: 'ping-1',
            payload: <String, dynamic>{},
          ).toJson(),
        ),
      );

      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Must have closed socket or sent error, and partial file must NOT exist!
      final partialFile = File('${tempDir.path}/partial.txt');
      expect(partialFile.existsSync(), isFalse);
      expect(responses.any((m) => m.isError), isTrue);
      await ws.close();
    },
  );

  test('insufficient storage rejects transfer offer', () async {
    storageValidation.hasEnoughSpace = false;

    final startRes = await server.start(port: 0);
    expect(startRes.isSuccess, isTrue);

    final port = server.port!;

    final ws = await WebSocket.connect('ws://127.0.0.1:$port');
    final responses = <ControlMessage>[];

    ws.listen((data) {
      if (data is String) {
        final decoded = ControlMessageCodec.decode(data);
        if (decoded is ControlDecoded) {
          responses.add(decoded.message);
        }
      }
    });

    // Handshake
    ws.add(
      jsonEncode(
        const ControlMessage(
          type: ProtocolMessageTypes.pairRequest,
          id: 'p-1',
          payload: <String, dynamic>{
            'deviceId': 'd1',
            'deviceName': 'Device 1',
            'token': 'valid-token',
          },
        ).toJson(),
      ),
    );

    await Future<void>.delayed(const Duration(milliseconds: 30));

    // Offer
    ws.add(
      jsonEncode(
        ControlMessage(
          type: ProtocolMessageTypes.transferOffer,
          id: 'o-space',
          payload: const TransferOfferPayload(
            wireTransferId: 'w-space',
            fileName: 'huge.iso',
            size: 1000000000,
          ).toJson(),
        ).toJson(),
      ),
    );

    await Future<void>.delayed(const Duration(milliseconds: 40));

    expect(
      responses.any((m) => m.type == ProtocolMessageTypes.transferReject),
      isTrue,
    );

    await ws.close();
  });
}
