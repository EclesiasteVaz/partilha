import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:partilha/core/errors/failure.dart';
import 'package:partilha/features/discovery/data/local_address_resolver.dart';
import 'package:partilha/features/discovery/data/mdns_discovery_service.dart';

import 'fake_multicast_lock.dart';

/// Returns fixed addresses so the test never depends on the machine's real
/// network topology.
class StubAddressResolver implements LocalAddressResolver {
  StubAddressResolver(this.addresses);

  final List<InternetAddress> addresses;
  String? lastRequestedInterface;

  @override
  Future<List<InternetAddress>> resolve({String? interfaceName}) async {
    lastRequestedInterface = interfaceName;
    return addresses;
  }
}

void main() {
  MdnsDiscoveryService serviceWith({
    required FakeMulticastLock lock,
    LocalAddressResolver? resolver,
  }) => MdnsDiscoveryService(
    hostName: 'test-device',
    multicastLock: lock,
    addressResolver:
        resolver ??
        StubAddressResolver(<InternetAddress>[InternetAddress('192.168.1.10')]),
    // Short timeout: these tests never expect a real responder, and a long
    // window would make the suite slow for no added confidence.
    responseTimeout: const Duration(milliseconds: 50),
  );

  group('SO_REUSEPORT defaults to on', () {
    // Regression guard for a macOS blocker found by the spike. A host's own mDNS
    // responder already holds UDP 5353 on the wildcard address, so without
    // SO_REUSEPORT every bind fails with EADDRINUSE and mdns_dart reports only
    // "Failed to create any multicast sockets". Android may need the opposite,
    // which is why this is asserted as a default rather than hard-coded: see
    // docs/decisions/0002-mdns-provider.md.
    test('is enabled unless a caller deliberately turns it off', () {
      expect(serviceWith(lock: FakeMulticastLock()).reusePort, isTrue);

      final MdnsDiscoveryService off = MdnsDiscoveryService(
        hostName: 'test-device',
        multicastLock: FakeMulticastLock(),
        reusePort: false,
      );
      expect(off.reusePort, isFalse);
    });
  });

  group('multicast lock lifecycle', () {
    test('a discovery query acquires the lock before sending traffic', () async {
      final FakeMulticastLock lock = FakeMulticastLock();
      final MdnsDiscoveryService service = serviceWith(lock: lock);

      await service.discover();

      // Without the lock Android drops the query silently and the result looks
      // like an empty network, so acquisition must precede the socket call.
      expect(lock.acquires, greaterThanOrEqualTo(1));
    });

    test('the lock is released when the query finishes', () async {
      final FakeMulticastLock lock = FakeMulticastLock();
      final MdnsDiscoveryService service = serviceWith(lock: lock);

      await service.discover();

      // Held longer it would keep the Wi-Fi radio awake for nothing.
      expect(lock.isHeld, isFalse);
    });

    test(
      'a failed acquisition surfaces a typed failure, not an empty list',
      () async {
        final FakeMulticastLock lock = FakeMulticastLock(failAcquire: true);
        final MdnsDiscoveryService service = serviceWith(lock: lock);

        final result = await service.discover();

        // The failure mode this exists to prevent: a lock that cannot be taken
        // must not look like a network with no devices on it.
        expect(result.isFailure, isTrue);
        expect(result.errorOrNull, isA<DiscoveryFailure>());
      },
    );

    test('a failed acquisition does not report a held lock', () async {
      final FakeMulticastLock lock = FakeMulticastLock(failAcquire: true);
      final MdnsDiscoveryService service = serviceWith(lock: lock);

      await service.discover();

      expect(lock.isHeld, isFalse);
    });

    test('stopping when nothing was advertised still succeeds', () async {
      // Teardown runs this unconditionally; throwing would mask whatever error
      // triggered the teardown in the first place.
      final FakeMulticastLock lock = FakeMulticastLock();
      final MdnsDiscoveryService service = serviceWith(lock: lock);

      expect((await service.stopAdvertising()).isSuccess, isTrue);
    });
  });

  group('interface selection is delegated', () {
    test('the requested interface reaches the resolver', () async {
      final FakeMulticastLock lock = FakeMulticastLock();
      final StubAddressResolver resolver = StubAddressResolver(
        <InternetAddress>[InternetAddress('192.168.1.10')],
      );
      final MdnsDiscoveryService service = serviceWith(
        lock: lock,
        resolver: resolver,
      );

      await service.startAdvertising(
        deviceId: 'device-abc',
        deviceName: 'Test Device',
        port: 4443,
        capabilities: const <String, String>{},
        interfaceName: 'wlan0',
      );
      await service.stopAdvertising();

      expect(resolver.lastRequestedInterface, 'wlan0');
    });
  });

  group('advertising preconditions', () {
    test('no usable address fails instead of announcing loopback', () async {
      final FakeMulticastLock lock = FakeMulticastLock();
      final MdnsDiscoveryService service = serviceWith(
        lock: lock,
        resolver: StubAddressResolver(const <InternetAddress>[]),
      );

      final result = await service.startAdvertising(
        deviceId: 'device-abc',
        deviceName: 'Test Device',
        port: 4443,
        capabilities: const <String, String>{},
      );

      // An announcement no peer can reach is worse than no announcement.
      expect(result.isFailure, isTrue);
      expect(result.errorOrNull, isA<DiscoveryFailure>());
    });

    test('a failed advertisement does not leave the lock held', () async {
      final FakeMulticastLock lock = FakeMulticastLock();
      final MdnsDiscoveryService service = serviceWith(
        lock: lock,
        resolver: StubAddressResolver(const <InternetAddress>[]),
      );

      await service.startAdvertising(
        deviceId: 'device-abc',
        deviceName: 'Test Device',
        port: 4443,
        capabilities: const <String, String>{},
      );

      expect(lock.isHeld, isFalse);
    });
  });
}
