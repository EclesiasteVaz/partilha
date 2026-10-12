import 'dart:convert';

import 'package:partilha/core/errors/failure.dart';
import 'package:partilha/core/protocol/qr_payload.dart';
import 'package:partilha/core/result/result.dart';
import 'package:partilha/features/pairing/domain/domain.dart';

/// Concrete [QrCodeService] validating and encoding [QrPayload] according to
/// `PROTOCOL_IMPLEMENTATION_PLAN.md` §10:
/// `{"v": 1, "deviceId", "deviceName", "host", "port", "token"}`.
final class JsonQrCodeService implements QrCodeService {
  const JsonQrCodeService();

  @override
  String encode(QrPayload payload) {
    return jsonEncode(payload.toJson());
  }

  @override
  Result<PairingContext, Failure> validateScanned(String rawQrContent) {
    if (rawQrContent.trim().isEmpty) {
      return const Result.failure(PairingFailure.invalidPayload);
    }

    try {
      final decoded = jsonDecode(rawQrContent);
      if (decoded is! Map<String, dynamic> && decoded is! Map) {
        return const Result.failure(PairingFailure.invalidPayload);
      }

      final map = Map<String, dynamic>.from(decoded as Map);

      // Verify protocol version
      final v = map['v'];
      if (v != 1) {
        return const Result.failure(PairingFailure.invalidPayload);
      }

      final deviceId = map['deviceId'] as String?;
      final deviceName = map['deviceName'] as String?;
      final host = map['host'] as String?;
      final port = map['port'] as int?;
      final token = map['token'] as String?;

      if (deviceId == null || deviceId.trim().isEmpty) {
        return const Result.failure(PairingFailure.invalidPayload);
      }
      if (deviceName == null || deviceName.trim().isEmpty) {
        return const Result.failure(PairingFailure.invalidPayload);
      }
      if (host == null || host.trim().isEmpty) {
        return const Result.failure(PairingFailure.invalidPayload);
      }
      if (port == null || port <= 0 || port > 65535) {
        return const Result.failure(PairingFailure.invalidPayload);
      }
      if (token == null || token.trim().isEmpty) {
        return const Result.failure(PairingFailure.invalidPayload);
      }

      return Result.success(
        PairingContext(
          peerDeviceId: deviceId,
          peerDeviceName: deviceName,
          peerHost: host,
          peerPort: port,
          token: token,
          certificateFingerprint: map['fingerprint'] as String?,
        ),
      );
    } on Object catch (_) {
      return const Result.failure(PairingFailure.invalidPayload);
    }
  }
}
