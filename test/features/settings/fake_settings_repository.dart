import 'package:partilha/core/errors/failure.dart';
import 'package:partilha/core/result/result.dart';
import 'package:partilha/features/settings/domain/domain.dart';

/// In-memory [SettingsRepository] for tests.
///
/// Deliberately not a mock: these tests are about how the layers above behave
/// when storage succeeds or fails, and a mock would only re-state the
/// expectations. A fake that actually stores and can be told to fail tests the
/// real thing (`AGENTS.md` §60).
class FakeSettingsRepository implements SettingsRepository {
  FakeSettingsRepository({this.failure, DeviceName? initial})
    : _stored = initial;

  /// When set, both operations fail with this instead of working.
  Failure? failure;

  /// What was written, so a test can assert the write happened rather than that
  /// it was requested.
  DeviceName? written;

  int readCount = 0;

  DeviceName? _stored;

  @override
  Future<Result<DeviceName, Failure>> readDeviceName() async {
    readCount++;
    final Failure? problem = failure;
    if (problem != null) return Result<DeviceName, Failure>.failure(problem);
    return Result<DeviceName, Failure>.success(_stored ?? DeviceName.fallback);
  }

  @override
  Future<Result<void, Failure>> saveDeviceName(DeviceName name) async {
    final Failure? problem = failure;
    if (problem != null) return Result<void, Failure>.failure(problem);
    _stored = name;
    written = name;
    return const Result<void, Failure>.success(null);
  }
}
