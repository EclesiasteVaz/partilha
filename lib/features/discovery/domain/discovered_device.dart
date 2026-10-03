/// A Partilha receiver seen on the local network.
///
/// Discovery metadata is **untrusted input**. Any host on the LAN can announce
/// arbitrary records, so nothing in here may be treated as proof of identity
/// (`features/discovery/FEATURE.md` §12, §26).
///
/// The pairing token is deliberately absent: mDNS records are plaintext and
/// readable by any host on the network. Trust is established by pairing, not by
/// discovery (`docs/decisions/0003-token-fora-do-mdns.md`).
///
/// Deliberately a plain immutable class rather than a Freezed model: this type
/// exists only to carry validated data through the spike, and value equality
/// for five fields is not worth pulling in a code-generation step
/// (`AGENTS.md` §55). If the entity grows unions or `copyWith` usage, revisit.
class DiscoveredDevice {
  const DiscoveredDevice({
    required this.deviceId,

    /// Display-only. Attacker-controlled: escape it at render time and never
    /// use it to build a filesystem path (§12).
    required this.deviceName,

    required this.address,
    required this.port,

    /// Remaining advertised capabilities. Also untrusted.
    required this.capabilities,
  });

  /// Identity claimed by the announcement. **Not** proof of identity.
  final String deviceId;
  final String deviceName;
  final String address;
  final int port;
  final Map<String, String> capabilities;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DiscoveredDevice &&
          other.deviceId == deviceId &&
          other.deviceName == deviceName &&
          other.address == address &&
          other.port == port &&
          _mapEquals(other.capabilities, capabilities);

  /// Local `mapEquals`, because `flutter/foundation` is not available to a
  /// pure-Dart domain type and adding the import would drag the Flutter SDK
  /// into a layer that must stay UI-free (`AGENTS.md` §5).
  static bool _mapEquals(Map<String, String> a, Map<String, String> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (final MapEntry<String, String> e in a.entries) {
      if (!b.containsKey(e.key) || b[e.key] != e.value) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
    deviceId,
    deviceName,
    address,
    port,
    Object.hashAllUnordered(
      capabilities.entries.map(
        (MapEntry<String, String> e) => Object.hash(e.key, e.value),
      ),
    ),
  );

  @override
  String toString() =>
      'DiscoveredDevice(deviceId: $deviceId, deviceName: $deviceName, '
      'address: $address, port: $port)';
}
