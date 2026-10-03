import 'package:mdns_dart/mdns_dart.dart';
import 'package:partilha/features/discovery/domain/discovered_device.dart';

/// Translates untrusted mDNS records into [DiscoveredDevice] values.
///
/// Split out of `MdnsDiscoveryService` so the validation rules can be unit
/// tested without a network: `features/discovery/FEATURE.md` §29 requires tests
/// for record mapping and rejection of malformed records, and that is
/// impossible to assert while the mapping is buried in a socket call.
///
/// This is the trust boundary. Every field below is attacker-controlled, because
/// any host on the LAN can announce arbitrary records (§12, §26).
class DiscoveredDeviceMapper {
  const DiscoveredDeviceMapper();

  static const String txtDeviceName = 'name';
  static const String txtDeviceId = 'id';

  /// Upper bound on a single untrusted metadata field.
  ///
  /// Numeric limits are `OPEN — APPROVAL REQUIRED` in
  /// `features/discovery/FEATURE.md` §12. These values are provisional: they
  /// exist so a hostile announcement cannot be rendered at unbounded length,
  /// not because they were measured to be correct.
  static const int maxNameLength = 64;
  static const int maxIdLength = 64;

  /// Returns `null` when the record does not describe a usable receiver.
  ///
  /// A record is dropped rather than repaired. Guessing which half of a
  /// contradictory record was wrong is how a hostile announcement reaches the
  /// UI as a plausible device.
  DiscoveredDevice? fromEntry(ServiceEntry entry) {
    if (!entry.isComplete) return null;

    final String? address = entry.primaryAddress?.address;
    if (address == null || address.isEmpty) return null;
    if (entry.port <= 0 || entry.port > 65535) return null;

    final Map<String, String> txt = MDNSService.parseTXTRecords(
      entry.infoFields,
    );

    // Fall back to the service instance name when the advertised name is
    // absent, because a peer that omits a display name is still connectable.
    final String deviceName = txt[txtDeviceName] ?? entry.name;
    final String deviceId = txt[txtDeviceId] ?? '';
    if (deviceName.isEmpty || deviceName.length > maxNameLength) return null;
    if (deviceId.length > maxIdLength) return null;

    return DiscoveredDevice(
      deviceId: deviceId,
      deviceName: deviceName,
      address: address,
      port: entry.port,
      capabilities: Map<String, String>.unmodifiable(<String, String>{
        for (final MapEntry<String, String> e in txt.entries)
          if (e.key != txtDeviceName && e.key != txtDeviceId) e.key: e.value,
      }),
    );
  }
}
