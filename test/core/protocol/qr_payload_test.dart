import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:partilha/core/protocol/protocol.dart';

void main() {
  group('QrPayload', () {
    test('serializes and deserializes correctly', () {
      const payload = QrPayload(
        v: 1,
        deviceId: 'dev-123',
        deviceName: 'MacBook Pro',
        host: '192.168.1.50',
        port: 8080,
        token: 'auth-token-xyz',
      );

      final jsonMap = payload.toJson();
      expect(jsonMap['v'], 1);
      expect(jsonMap['deviceId'], 'dev-123');
      expect(jsonMap['deviceName'], 'MacBook Pro');
      expect(jsonMap['host'], '192.168.1.50');
      expect(jsonMap['port'], 8080);
      expect(jsonMap['token'], 'auth-token-xyz');

      final jsonString = jsonEncode(jsonMap);
      final decodedMap = jsonDecode(jsonString) as Map<String, dynamic>;
      final parsed = QrPayload.fromJson(decodedMap);

      expect(parsed, payload);
    });
  });
}
