import 'package:partilha/core/errors/failure.dart';
import 'package:partilha/core/result/result.dart';
import 'package:partilha/features/pairing/domain/device_identity.dart';

/// Contract for persistent device identity management.
///
/// Follows `features/pairing/FEATURE.md` §17 and `AGENTS.md` §33.
abstract interface class PairingRepository {
  /// Reads or creates the local persistent device identity (deviceId and secure token).
  Future<Result<DeviceIdentity, Failure>> getOrCreateIdentity();
}
