import 'package:partilha/core/errors/failure.dart';
import 'package:partilha/core/platform/platform.dart';
import 'package:partilha/core/result/result.dart';

/// Records lock transitions so tests can assert the lifecycle directly rather
/// than inferring it from whether a socket happened to work.
class FakeMulticastLock implements MulticastLock {
  FakeMulticastLock({this.failAcquire = false});

  /// Set to make acquisition fail, exercising the path where discovery must
  /// surface a typed failure instead of silently returning nothing.
  final bool failAcquire;

  /// Holds actually taken, so a failed attempt is not counted as a hold.
  int acquires = 0;
  int releases = 0;

  /// Whether a hold is currently outstanding.
  bool get isHeld => acquires > releases;

  @override
  Future<Result<void, Failure>> acquire() async {
    if (failAcquire) {
      return const Result<void, Failure>.failure(
        DiscoveryFailure.multicastUnavailable,
      );
    }
    acquires++;
    return const Result<void, Failure>.success(null);
  }

  @override
  Future<Result<void, Failure>> release() async {
    releases++;
    return const Result<void, Failure>.success(null);
  }
}
