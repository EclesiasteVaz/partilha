import 'package:partilha/core/errors/failure.dart';
import 'package:partilha/core/result/result.dart';
import 'package:partilha/features/settings/domain/device_name.dart';

/// Stores the settings the user has chosen.
///
/// Expressed in application terms rather than as key/value access: "read the
/// device name" is something a caller needs, "select from the settings table
/// where key = ?" is not (`AGENTS.md` §13).
///
/// Exactly one source of truth for the device name, per the feature's own
/// functional requirements. A second store — a cached copy in preferences, a
/// file beside the database — would let the two disagree with no way to decide
/// which is right.
abstract interface class SettingsRepository {
  /// The stored device name.
  ///
  /// Returns [DeviceName.fallback] when nothing has been stored yet, rather than
  /// a failure: an unconfigured name is a normal first run, not an error, and
  /// modelling it as one would force every caller to handle a case that is the
  /// expected path.
  Future<Result<DeviceName, Failure>> readDeviceName();

  /// Replaces the stored device name.
  ///
  /// Takes a validated [DeviceName] rather than a [String] so no implementation
  /// can persist something the domain already rejected.
  Future<Result<void, Failure>> saveDeviceName(DeviceName name);
}
