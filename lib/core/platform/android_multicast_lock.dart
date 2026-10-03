import 'dart:io';

import 'package:flutter/services.dart';
import 'package:partilha/core/errors/failure.dart';
import 'package:partilha/core/platform/multicast_lock.dart';
import 'package:partilha/core/result/result.dart';

/// Android implementation, delegating to `WifiManager.MulticastLock`.
///
/// Lives apart from the contract in `multicast_lock.dart` so that importing the
/// contract does not drag Flutter in behind it. The native side is
/// `MainActivity.kt`, and `CHANGE_WIFI_MULTICAST_STATE` is declared in the
/// manifest.
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

/// Returns the lock appropriate to the current platform.
///
/// The single place in the app that branches on the platform for multicast
/// (`AGENTS.md` §41).
MulticastLock createMulticastLock() => Platform.isAndroid
    ? MethodChannelMulticastLock()
    : const UnrestrictedMulticastLock();
