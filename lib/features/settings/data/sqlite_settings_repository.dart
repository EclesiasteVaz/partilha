import 'package:partilha/core/errors/failure.dart';
import 'package:partilha/core/result/result.dart';
import 'package:partilha/features/settings/domain/domain.dart';

import 'settings_local_data_source.dart';

/// Stores settings in SQLite.
///
/// Named for the technology it uses rather than for the interface it satisfies:
/// the name should tell a reader which implementation they are looking at
/// (`AGENTS.md` §16, §56).
///
/// Every `DatabaseException` is converted to a typed [StorageFailure] here, at
/// the infrastructure boundary, so no sqflite type escapes into domain or
/// presentation (§15).
class SqliteSettingsRepository implements SettingsRepository {
  const SqliteSettingsRepository(this._dataSource);

  final SettingsLocalDataSource _dataSource;

  /// Storage key for the device name.
  ///
  /// Namespaced by feature so a future key cannot collide, and kept in one place
  /// because the read and the write must agree on it — a mismatch would silently
  /// create a second "source of truth" that always reads as unset.
  static const String deviceNameKey = 'settings.device_name';

  @override
  Future<Result<DeviceName, Failure>> readDeviceName() async {
    try {
      final String? stored = await _dataSource.read(deviceNameKey);

      if (stored == null) {
        // First run is not a failure: returning the fallback keeps "no name yet"
        // an ordinary value instead of an error every caller must special-case.
        return const Result<DeviceName, Failure>.success(DeviceName.fallback);
      }

      // Re-validated on read as well as on write. The row is this device's own
      // data, but it can predate a rule change, and a name that no longer
      // validates must degrade to the fallback rather than be advertised as
      // something it is not (§7.2).
      return switch (DeviceName.create(stored)) {
        Success(:final value) => Result<DeviceName, Failure>.success(value),
        Err() => const Result<DeviceName, Failure>.success(DeviceName.fallback),
      };
    } on StorageFailure {
      rethrow;
    } on Object catch (error) {
      return Result<DeviceName, Failure>.failure(
        StorageFailure(
          cause: error,
          context: const <String, Object?>{'operation': 'readDeviceName'},
        ),
      );
    }
  }

  @override
  Future<Result<void, Failure>> saveDeviceName(DeviceName name) async {
    try {
      await _dataSource.write(deviceNameKey, name.value);
      return const Result<void, Failure>.success(null);
    } on Object catch (error) {
      return Result<void, Failure>.failure(
        StorageFailure(
          cause: error,
          context: const <String, Object?>{'operation': 'saveDeviceName'},
        ),
      );
    }
  }
}
