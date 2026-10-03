import 'dart:io';

import 'package:flutter/services.dart';
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
/// Platform checks live in the factory below rather than being scattered through
/// call sites, and the Android implementation is reached only through a method
/// channel, so no feature code imports an Android API.
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

/// Android implementation, delegating to `WifiManager.MulticastLock`.
class MethodChannelMulticastLock implements MulticastLock {
  MethodChannelMulticastLock({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(_channelName);

  static const String _channelName = 'partilha/multicast_lock';

  final MethodChannel _channel;

  @override
  Future<Result<void, Failure>> acquire() =>
      _invoke('acquire', DiscoveryFailure.multicastUnavailable);

  @override
  Future<Result<void, Failure>> release() =>
      _invoke('release', DiscoveryFailure.transportFailed);

  Future<Result<void, Failure>> _invoke(String method, Failure failure) async {
    try {
      await _channel.invokeMethod<void>(method);
      return const Result<void, Failure>.success(null);
    } on PlatformException {
      return Result<void, Failure>.failure(failure);
    } on MissingPluginException {
      // The host side is absent, which means this is not a platform that needs
      // a lock. Treated as success so callers do not need a platform check.
      return const Result<void, Failure>.success(null);
    }
  }
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

/// Returns the lock appropriate to the current platform.
///
/// The single place in the app that branches on the platform for multicast
/// (`AGENTS.md` §41).
MulticastLock createMulticastLock() => Platform.isAndroid
    ? MethodChannelMulticastLock()
    : const UnrestrictedMulticastLock();
