import 'dart:io';

import 'package:mdns_dart/mdns_dart.dart';
import 'package:partilha/core/errors/failure.dart';
import 'package:partilha/core/platform/platform.dart';
import 'package:partilha/core/result/result.dart';
import 'package:partilha/features/discovery/data/discovered_device_mapper.dart';
import 'package:partilha/features/discovery/data/local_address_resolver.dart';
import 'package:partilha/features/discovery/domain/discovered_device.dart';
import 'package:partilha/features/discovery/domain/discovery_service.dart';

/// mDNS-backed [DiscoveryService].
///
/// Owns `mdns_dart` completely. Nothing above this class imports the package
/// (`AGENTS.md` §35, §51), and every package exception is translated into a
/// project-owned [Failure] (`AGENTS.md` §15).
///
/// Provider choice is provisional: see `docs/decisions/0002-mdns-provider.md`.
class MdnsDiscoveryService implements DiscoveryService {
  MdnsDiscoveryService({
    required this.hostName,
    required this.multicastLock,
    this.responseTimeout = const Duration(seconds: 3),
    this.addressResolver = const AllNonLoopbackAddresses(),
  });

  /// Host name announced in the SRV record.
  ///
  /// Falls back to `local` in the record when empty, because an empty
  /// `hostName` produces a malformed SRV record that peers cannot parse.
  final String hostName;

  /// Trust boundary where untrusted records are validated and translated.
  final DiscoveredDeviceMapper _mapper = const DiscoveredDeviceMapper();

  /// Held while multicast traffic flows, because Android drops it otherwise.
  final MulticastLock multicastLock;

  /// Decides which local addresses are announced. Injected so the selection
  /// policy is one testable decision rather than logic inside the socket call.
  final LocalAddressResolver addressResolver;

  /// Whether this service currently holds the platform multicast lock.
  bool get holdsMulticastLock => _multicastLockHeld;
  bool _multicastLockHeld = false;

  /// mDNS service type for Partilha receivers.
  ///
  /// Not yet a protocol contract: `docs/PROTOCOL.md` §7.2 still lists the final
  /// type and TXT keys as `OPEN — APPROVAL REQUIRED`.
  static const String serviceType = '_partilha._tcp';
  static const String _domain = 'local';

  /// TXT keys this device advertises. The token is absent by construction.
  static const String _txtDeviceName = DiscoveredDeviceMapper.txtDeviceName;
  static const String _txtDeviceId = DiscoveredDeviceMapper.txtDeviceId;

  /// How long to collect responses before returning what was found.
  ///
  /// Bounded on purpose: an unbounded mDNS query would leave the caller
  /// awaiting a stream that never completes, which reads as a hang rather than
  /// as "no devices found" (`AGENTS.md` §83).
  final Duration responseTimeout;

  /// Held so [stopAdvertising] can stop the exact instance that was started.
  ///
  /// Losing this reference is what leaves a phantom advertisement on the
  /// network, so it is a field rather than a local (`AGENTS.md` §80, §81).
  MDNSServer? _server;

  bool get isAdvertising => _server?.isRunning ?? false;

  @override
  Future<Result<List<DiscoveredDevice>, Failure>> discover() async {
    // Acquired for the duration of the query only. Held longer it would keep the
    // Wi-Fi radio awake for no benefit; not held at all, Android silently drops
    // the traffic and discovery looks like an empty network.
    final Result<void, Failure> lockResult = await _acquireLock();
    if (lockResult case Err(:final error)) {
      return Result<List<DiscoveredDevice>, Failure>.failure(error);
    }

    try {
      final List<ServiceEntry> entries = await MDNSClient.discover(
        '$serviceType.$_domain.',
        timeout: responseTimeout,
      );

      // Duplicate suppression: a device answers a query more than once, and the
      // list must not gain a second row for it (§28).
      final Map<String, DiscoveredDevice> byIdentity =
          <String, DiscoveredDevice>{};
      for (final ServiceEntry entry in entries) {
        final DiscoveredDevice? device = _mapper.fromEntry(entry);
        if (device == null) continue;
        byIdentity['${device.deviceId}|${device.address}|${device.port}'] =
            device;
      }

      return Result<List<DiscoveredDevice>, Failure>.success(
        List<DiscoveredDevice>.unmodifiable(byIdentity.values),
      );
    } on SocketException {
      return const Result<List<DiscoveredDevice>, Failure>.failure(
        DiscoveryFailure.transportFailed,
      );
    } on Object {
      // Deliberately broad: an unrecognised socket-level failure from the
      // provider must still surface as a typed Failure rather than an
      // exception escaping into presentation (§15).
      return const Result<List<DiscoveredDevice>, Failure>.failure(
        DiscoveryFailure.transportFailed,
      );
    } finally {
      await _releaseLock();
    }
  }

  Future<Result<void, Failure>> _acquireLock() async {
    if (_multicastLockHeld) return const Result<void, Failure>.success(null);
    final Result<void, Failure> result = await multicastLock.acquire();
    if (result.isSuccess) _multicastLockHeld = true;
    return result;
  }

  Future<void> _releaseLock() async {
    if (!_multicastLockHeld) return;
    _multicastLockHeld = false;
    await multicastLock.release();
  }

  @override
  Future<Result<void, Failure>> startAdvertising({
    required String deviceId,
    required String deviceName,
    required int port,
    required Map<String, String> capabilities,
    String? interfaceName,
  }) async {
    if (isAdvertising) {
      // Re-advertising without stopping leaks the previous socket and can leave
      // a stale record behind (§7, §15).
      return const Result<void, Failure>.failure(
        DiscoveryFailure.transportFailed,
      );
    }

    // Held for as long as the advertisement is live, then released by
    // stopAdvertising. A lock left held keeps the Wi-Fi radio awake indefinitely.
    final Result<void, Failure> lockResult = await _acquireLock();
    if (lockResult case Err(:final error)) {
      return Result<void, Failure>.failure(error);
    }

    try {
      final List<InternetAddress> addresses = await addressResolver.resolve(
        interfaceName: interfaceName,
      );
      if (addresses.isEmpty) {
        // Advertising a loopback address would produce an announcement no peer
        // can reach, which is worse than not announcing at all.
        return const Result<void, Failure>.failure(
          DiscoveryFailure.multicastUnavailable,
        );
      }

      final MDNSService service = MDNSService(
        instance: deviceName,
        service: serviceType,
        domain: _domain,
        hostName: hostName.isEmpty ? 'local' : '$hostName.local.',
        port: port,
        ips: addresses,
        txt: <String>[
          '$_txtDeviceName=$deviceName',
          '$_txtDeviceId=$deviceId',
          ...capabilities.entries.map(
            (MapEntry<String, String> e) => '${e.key}=${e.value}',
          ),
        ],
      );

      final MDNSServer server = MDNSServer(MDNSServerConfig(zone: service));
      await server.start();
      _server = server;
      return const Result<void, Failure>.success(null);
    } on SocketException {
      return const Result<void, Failure>.failure(
        DiscoveryFailure.multicastUnavailable,
      );
    } on Object {
      return const Result<void, Failure>.failure(
        DiscoveryFailure.transportFailed,
      );
    } finally {
      // Every exit path that never reached a running server must give the lock
      // back. The early return for "no usable address" sits inside this try,
      // so without this it would strand the hold and keep the Wi-Fi radio awake
      // for the rest of the process (§81). A successful start keeps the hold,
      // and stopAdvertising is what releases it.
      if (_server == null) await _releaseLock();
    }
  }

  @override
  Future<Result<void, Failure>> stopAdvertising() async {
    final MDNSServer? server = _server;
    if (server == null) return const Result<void, Failure>.success(null);

    try {
      await server.stop();
      _server = null;
      return const Result<void, Failure>.success(null);
    } on Object {
      return const Result<void, Failure>.failure(
        DiscoveryFailure.transportFailed,
      );
    } finally {
      // Released even when the socket failed to close: a leaked lock outlives
      // the screen and keeps the radio awake for the rest of the process (§81).
      await _releaseLock();
    }
  }
}
