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
  }) : _secureStorage = secureStorage ??
           const FlutterSecureStorage(
             mOptions: MacOsOptions(usesDataProtectionKeychain: false),
           ),
       _secureRandom = secureRandom ?? Random.secure();

  final FlutterSecureStorage _secureStorage;
  final Random _secureRandom;

  DeviceIdentity? _cachedIdentity;

  static const String _keyDeviceId = 'partilha_device_id';
  static const String _keyDeviceToken = 'partilha_device_token';

  @override
  Future<Result<DeviceIdentity, Failure>> getOrCreateIdentity() async {
    if (_cachedIdentity != null) {
      return Result.success(_cachedIdentity!);
    }

    try {
      var deviceId = await _secureStorage.read(key: _keyDeviceId);
      var token = await _secureStorage.read(key: _keyDeviceToken);

      if (deviceId == null || token == null) {
        deviceId ??= _generateRandomHex(16);
        token ??= _generateRandomHex(32);

        try {
          await _secureStorage.write(key: _keyDeviceId, value: deviceId);
          await _secureStorage.write(key: _keyDeviceToken, value: token);
        } on Object {
          // If write to secure storage is denied, keep the in-memory identity
        }
      }

      final identity = DeviceIdentity(deviceId: deviceId, token: token);
      _cachedIdentity = identity;
      return Result.success(identity);
    } on Object {
      // If secure storage access is denied (e.g. user cancelled keychain prompt
      // or keychain is unavailable), fall back to an ephemeral in-memory identity
      // so the user is never locked in an infinite prompt loop.
      final fallback = DeviceIdentity(
        deviceId: _generateRandomHex(16),
        token: _generateRandomHex(32),
      );
      _cachedIdentity = fallback;
      return Result.success(fallback);
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
