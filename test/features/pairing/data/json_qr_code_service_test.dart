import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:partilha/core/errors/failure.dart';
import 'package:partilha/core/protocol/qr_payload.dart';
import 'package:partilha/features/pairing/data/json_qr_code_service.dart';

void main() {
  const service = JsonQrCodeService();

  const validPayload = QrPayload(
    v: 1,
    deviceId: 'device-123',
    deviceName: 'Test Phone',
    host: '192.168.1.100',
    port: 8080,
    token: 'super-secret-token',
  );

  group('JsonQrCodeService', () {
    test('encode produces valid json containing all payload fields', () {
      final encoded = service.encode(validPayload);
      final decoded = jsonDecode(encoded) as Map<String, dynamic>;

      expect(decoded['v'], 1);
      expect(decoded['deviceId'], 'device-123');
      expect(decoded['deviceName'], 'Test Phone');
      expect(decoded['host'], '192.168.1.100');
      expect(decoded['port'], 8080);
      expect(decoded['token'], 'super-secret-token');
    });

    test('validateScanned succeeds with well-formed QR payload', () {
      final encoded = service.encode(validPayload);
      final result = service.validateScanned(encoded);

      expect(result.isSuccess, isTrue);
      final context = result.valueOrNull!;
      expect(context.peerDeviceId, 'device-123');
      expect(context.peerDeviceName, 'Test Phone');
      expect(context.peerHost, '192.168.1.100');
      expect(context.peerPort, 8080);
      expect(context.token, 'super-secret-token');
    });

    test('validateScanned rejects empty or whitespace string', () {
      expect(service.validateScanned('').isFailure, isTrue);
      expect(service.validateScanned('   ').isFailure, isTrue);
    });

    test('validateScanned rejects non-json string', () {
      final result = service.validateScanned('not-valid-json');
      expect(result.isFailure, isTrue);
      expect(result.errorOrNull, isA<PairingFailure>());
    });

    test('validateScanned rejects invalid protocol version', () {
      final invalidVersion = jsonEncode({
        'v': 2,
        'deviceId': 'd1',
        'deviceName': 'name',
        'host': '1.1.1.1',
        'port': 80,
        'token': 'tok',
      });
      final result = service.validateScanned(invalidVersion);
      expect(result.isFailure, isTrue);
    });

    test('validateScanned rejects missing mandatory fields', () {
      final missingToken = jsonEncode({
        'v': 1,
        'deviceId': 'd1',
        'deviceName': 'name',
        'host': '1.1.1.1',
        'port': 80,
      });
      expect(service.validateScanned(missingToken).isFailure, isTrue);

      final invalidPort = jsonEncode({
        'v': 1,
        'deviceId': 'd1',
        'deviceName': 'name',
        'host': '1.1.1.1',
        'port': 70000,
        'token': 'tok',
      });
      expect(service.validateScanned(invalidPort).isFailure, isTrue);
    });
  });
}
