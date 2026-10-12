import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:partilha/core/errors/failure.dart';
import 'package:partilha/core/result/result.dart';
import 'package:partilha/features/pairing/domain/domain.dart';

/// Secure storage backed implementation of [PairingRepository].
///
/// Follows `features/pairing/FEATURE.md` §19 and §26 (token stored strictly
/// in secure platform storage, generated via cryptographically secure random).
final class SecureStoragePairingRepository implements PairingRepository {
  SecureStoragePairingRepository({
    FlutterSecureStorage? secureStorage,
    Random? secureRandom,
  }) : _secureStorage = secureStorage ?? const FlutterSecureStorage(),
       _secureRandom = secureRandom ?? Random.secure();

  final FlutterSecureStorage _secureStorage;
  final Random _secureRandom;

  static const String _keyDeviceId = 'partilha_device_id';
  static const String _keyDeviceToken = 'partilha_device_token';

  @override
  Future<Result<DeviceIdentity, Failure>> getOrCreateIdentity() async {
    try {
      var deviceId = await _secureStorage.read(key: _keyDeviceId);
      var token = await _secureStorage.read(key: _keyDeviceToken);

      if (deviceId == null || token == null) {
        deviceId ??= _generateRandomHex(16);
        token ??= _generateRandomHex(32);

        await _secureStorage.write(key: _keyDeviceId, value: deviceId);
        await _secureStorage.write(key: _keyDeviceToken, value: token);
      }

      return Result.success(DeviceIdentity(deviceId: deviceId, token: token));
    } on Object catch (e) {
      return Result.failure(
        StorageFailure(
          cause: e,
          context: const <String, Object?>{'operation': 'getOrCreateIdentity'},
        ),
      );
    }
  }

  String _generateRandomHex(int byteCount) {
    final values = List<int>.generate(
      byteCount,
      (_) => _secureRandom.nextInt(256),
    );
    return values.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }
}
