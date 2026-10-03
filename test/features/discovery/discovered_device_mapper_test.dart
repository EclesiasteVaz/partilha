import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mdns_dart/mdns_dart.dart';
import 'package:partilha/features/discovery/data/discovered_device_mapper.dart';

/// Unit tests for the mDNS record trust boundary.
///
/// These run without a network. The remaining spike checklist in
/// `docs/decisions/0002-mdns-provider.md` — a real announce, a real discovery,
/// two physical devices — cannot be covered here and is still open.
void main() {
  const DiscoveredDeviceMapper mapper = DiscoveredDeviceMapper();

  /// Builds a record as a hostile or sloppy peer might.
  ServiceEntry entry({
    String name = 'Living Room iPhone',
    String host = 'living-room.local.',
    String address = '192.168.1.42',
    int port = 4443,
    List<String> infoFields = const <String>['name=Living Room iPhone'],
    bool complete = true,
  }) {
    final ServiceEntry result = ServiceEntry(
      name: name,
      host: host,
      port: port,
      infoFields: infoFields,
    );
    if (address.isNotEmpty) {
      result.addIPv4Address(InternetAddress(address));
    }
    if (complete) result.markHasTXT();
    return result;
  }

  group('accepts a well-formed record', () {
    test('maps identity, address, port and capabilities', () {
      final device = mapper.fromEntry(
        entry(
          infoFields: <String>[
            'name=Living Room iPhone',
            'id=device-abc',
            'transfer=yes',
          ],
        ),
      );

      expect(device, isNotNull);
      expect(device!.deviceId, 'device-abc');
      expect(device.deviceName, 'Living Room iPhone');
      expect(device.address, '192.168.1.42');
      expect(device.port, 4443);
      // Identity keys are not re-exposed as capabilities.
      expect(device.capabilities, <String, String>{'transfer': 'yes'});
    });

    test('falls back to the service instance name when none is advertised', () {
      final device = mapper.fromEntry(entry(infoFields: <String>['id=x']));
      expect(device!.deviceName, 'Living Room iPhone');
    });

    test('accepts a record with no advertised id', () {
      final device = mapper.fromEntry(
        entry(infoFields: <String>['name=No id']),
      );
      expect(device, isNotNull);
      expect(device!.deviceId, isEmpty);
    });

    test('accepts IPv6-only hosts', () {
      final ServiceEntry v6 =
          ServiceEntry(
              name: 'v6 only',
              port: 4443,
              infoFields: <String>['name=v6 only'],
            )
            ..addIPv6Address(InternetAddress('fe80::1'))
            ..markHasTXT();
      expect(mapper.fromEntry(v6)?.address, 'fe80::1');
    });

    // `ServiceEntry.isComplete` requires a TXT record, so a peer that announces
    // the service type with no TXT payload never reaches the mapper. Partilha
    // always advertises TXT, so this is treated as "not a Partilha receiver"
    // rather than as a device with no metadata.
    test('drops a record with no TXT payload', () {
      final ServiceEntry noTxt = ServiceEntry(name: 'silent', port: 4443)
        ..addIPv4Address(InternetAddress('192.168.1.9'));
      expect(noTxt.isComplete, isFalse);
      expect(mapper.fromEntry(noTxt), isNull);
    });
  });

  group('rejects a record it must not trust', () {
    test('drops an incomplete record', () {
      expect(mapper.fromEntry(entry(complete: false)), isNull);
    });

    test('drops a record with no address', () {
      expect(mapper.fromEntry(entry(address: '')), isNull);
    });

    test('drops a non-positive port', () {
      expect(mapper.fromEntry(entry(port: 0)), isNull);
    });

    test('drops a port outside the valid range', () {
      expect(mapper.fromEntry(entry(port: 70000)), isNull);
    });

    test('drops an empty advertised name', () {
      expect(
        mapper.fromEntry(entry(name: '', infoFields: <String>['name='])),
        isNull,
      );
    });

    test('drops a name beyond the provisional length limit', () {
      final String hostile = 'a' * (DiscoveredDeviceMapper.maxNameLength + 1);
      expect(
        mapper.fromEntry(entry(infoFields: <String>['name=$hostile'])),
        isNull,
      );
    });

    test('drops an id beyond the provisional length limit', () {
      final String hostile = 'b' * (DiscoveredDeviceMapper.maxIdLength + 1);
      expect(
        mapper.fromEntry(entry(infoFields: <String>['name=ok', 'id=$hostile'])),
        isNull,
      );
    });
  });

  group('capabilities are inert', () {
    test('are unmodifiable so a consumer cannot rewrite shared state', () {
      final device = mapper.fromEntry(
        entry(infoFields: <String>['name=ok', 'k=v']),
      );
      expect(
        () => device!.capabilities['k'] = 'tampered',
        throwsUnsupportedError,
      );
    });
  });
}
