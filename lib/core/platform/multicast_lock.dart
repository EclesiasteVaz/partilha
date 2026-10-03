import 'package:partilha/core/errors/failure.dart';
import 'package:partilha/core/result/result.dart';

/// Holds the OS multicast lock while local-network discovery is active.
///
/// Exists because Android will silently drop multicast traffic for an app that
/// has not acquired `WifiManager.MulticastLock`. The failure is silent, which is
/// the dangerous part: discovery simply finds nothing and looks like an empty
/// network rather than a bug. Holding the lock also has a real cost, so it must
/// be acquired only while discovery runs and released as soon as it stops.
///
/// This is the project-owned seam for that behaviour (`AGENTS.md` §40, §41).
/// The Android implementation lives in `android_multicast_lock.dart` and is
/// reached only through a method channel, so no feature code imports an Android
/// API.
///
/// Deliberately free of any Flutter import. Every consumer of this contract
/// needs it, including development tooling that runs on the plain Dart VM, and a
/// contract that forced Flutter on them would be a contract in the wrong place.
abstract interface class MulticastLock {
  /// Acquires the lock, or increments its hold count.
  Future<Result<void, Failure>> acquire();

  /// Releases the lock, or decrements its hold count.
  ///
  /// Releasing more times than acquiring must not throw: cleanup paths run
  /// during teardown where throwing hides the original error
  /// (`AGENTS.md` §81).
  Future<Result<void, Failure>> release();
}

/// Used on platforms that do not restrict multicast, such as macOS.
class UnrestrictedMulticastLock implements MulticastLock {
  const UnrestrictedMulticastLock();

  @override
  Future<Result<void, Failure>> acquire() async =>
      const Result<void, Failure>.success(null);

  @override
  Future<Result<void, Failure>> release() async =>
      const Result<void, Failure>.success(null);
}
