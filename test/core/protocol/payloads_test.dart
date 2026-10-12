import 'package:flutter_test/flutter_test.dart';
import 'package:partilha/core/protocol/protocol.dart';

void main() {
  group('PairRequestPayload', () {
    test('round-trips through JSON', () {
      const payload = PairRequestPayload(
        deviceId: 'dev-1',
        deviceName: 'MacBook',
        token: 'secret-token-123',
      );

      final json = payload.toJson();
      final decoded = PairRequestPayload.fromJson(json);

      expect(decoded.deviceId, 'dev-1');
      expect(decoded.deviceName, 'MacBook');
      expect(decoded.token, 'secret-token-123');
    });

    test('throws FormatException on missing or invalid fields', () {
      expect(
        () => PairRequestPayload.fromJson(<String, dynamic>{
          'deviceId': '',
          'deviceName': 'MacBook',
          'token': 'tok',
        }),
        throwsFormatException,
      );
      expect(
        () => PairRequestPayload.fromJson(<String, dynamic>{
          'deviceId': 'dev-1',
          'deviceName': '',
          'token': 'tok',
        }),
        throwsFormatException,
      );
      expect(
        () => PairRequestPayload.fromJson(<String, dynamic>{
          'deviceId': 'dev-1',
          'deviceName': 'MacBook',
          'token': '',
        }),
        throwsFormatException,
      );
    });
  });

  group('PairResponsePayload', () {
    test('round-trips through JSON', () {
      const payload = PairResponsePayload(accepted: true, reason: 'All good');

      final json = payload.toJson();
      final decoded = PairResponsePayload.fromJson(json);

      expect(decoded.accepted, isTrue);
      expect(decoded.reason, 'All good');
    });

    test('handles optional reason', () {
      const payload = PairResponsePayload(accepted: false);
      final json = payload.toJson();
      expect(json.containsKey('reason'), isFalse);

      final decoded = PairResponsePayload.fromJson(json);
      expect(decoded.accepted, isFalse);
      expect(decoded.reason, isNull);
    });

    test('throws FormatException on missing accepted flag', () {
      expect(
        () => PairResponsePayload.fromJson(<String, dynamic>{}),
        throwsFormatException,
      );
    });
  });

  group('TransferOfferPayload', () {
    test('round-trips through JSON', () {
      const payload = TransferOfferPayload(
        wireTransferId: 'w-100',
        fileName: 'photo.jpg',
        size: 1024,
        mimeType: 'image/jpeg',
      );

      final json = payload.toJson();
      final decoded = TransferOfferPayload.fromJson(json);

      expect(decoded.wireTransferId, 'w-100');
      expect(decoded.fileName, 'photo.jpg');
      expect(decoded.size, 1024);
      expect(decoded.mimeType, 'image/jpeg');
    });

    test('throws FormatException on invalid values', () {
      expect(
        () => TransferOfferPayload.fromJson(<String, dynamic>{
          'wireTransferId': '',
          'fileName': 'photo.jpg',
          'size': 1024,
        }),
        throwsFormatException,
      );
      expect(
        () => TransferOfferPayload.fromJson(<String, dynamic>{
          'wireTransferId': 'w-100',
          'fileName': '',
          'size': 1024,
        }),
        throwsFormatException,
      );
      expect(
        () => TransferOfferPayload.fromJson(<String, dynamic>{
          'wireTransferId': 'w-100',
          'fileName': 'photo.jpg',
          'size': -1,
        }),
        throwsFormatException,
      );
    });
  });

  group('TransferAcceptPayload', () {
    test('round-trips through JSON', () {
      const payload = TransferAcceptPayload(wireTransferId: 'w-100');
      final json = payload.toJson();
      final decoded = TransferAcceptPayload.fromJson(json);
      expect(decoded.wireTransferId, 'w-100');
    });

    test('throws FormatException on empty id', () {
      expect(
        () => TransferAcceptPayload.fromJson(<String, dynamic>{
          'wireTransferId': '',
        }),
        throwsFormatException,
      );
    });
  });

  group('TransferRejectPayload', () {
    test('round-trips through JSON', () {
      const payload = TransferRejectPayload(
        wireTransferId: 'w-100',
        reason: 'User declined',
      );
      final json = payload.toJson();
      final decoded = TransferRejectPayload.fromJson(json);
      expect(decoded.wireTransferId, 'w-100');
      expect(decoded.reason, 'User declined');
    });
  });

  group('TransferCancelPayload', () {
    test('round-trips through JSON', () {
      const payload = TransferCancelPayload(wireTransferId: 'w-100');
      final json = payload.toJson();
      final decoded = TransferCancelPayload.fromJson(json);
      expect(decoded.wireTransferId, 'w-100');
    });
  });

  group('TransferCompletePayload', () {
    test('round-trips through JSON', () {
      const payload = TransferCompletePayload(wireTransferId: 'w-100');
      final json = payload.toJson();
      final decoded = TransferCompletePayload.fromJson(json);
      expect(decoded.wireTransferId, 'w-100');
    });
  });

  group('TransferErrorPayload', () {
    test('round-trips through JSON', () {
      const payload = TransferErrorPayload(
        code: ProtocolErrorCodes.insufficientSpace,
        message: 'Disk is full',
      );
      final json = payload.toJson();
      final decoded = TransferErrorPayload.fromJson(json);
      expect(decoded.code, ProtocolErrorCodes.insufficientSpace);
      expect(decoded.message, 'Disk is full');
    });

    test('throws FormatException on missing code', () {
      expect(
        () => TransferErrorPayload.fromJson(<String, dynamic>{}),
        throwsFormatException,
      );
    });
  });

  group('TransferProgressPayload', () {
    test('round-trips through JSON', () {
      const payload = TransferProgressPayload(
        wireTransferId: 'w-100',
        bytesReceived: 512,
      );
      final json = payload.toJson();
      final decoded = TransferProgressPayload.fromJson(json);
      expect(decoded.wireTransferId, 'w-100');
      expect(decoded.bytesReceived, 512);
    });
  });
}
