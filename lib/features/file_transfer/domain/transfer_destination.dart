/// Where a transfer is going.
///
/// Owned by this feature rather than reused from `features/discovery`, for two
/// reasons.
///
/// First, the discovery payload carries `capabilities` — advertised,
/// **untrusted** metadata read off the local network. Transfer must not depend
/// on it (`features/discovery/FEATURE.md` §12, §26), so the destination is an
/// explicit projection of only the fields transfer is allowed to act on.
///
/// Second, the mapping is what keeps the dependency one-directional:
/// discovery knows about transfer, and transfer knows nothing about discovery.
///
/// The address is still untrusted input. It is used to open a connection, never
/// as an identity, and never to build a filesystem path.
class TransferDestination {
  const TransferDestination({
    required this.deviceId,
    required this.deviceName,
    required this.address,
    required this.port,
  });

  /// Identity claimed by the announcement. **Not** proof of identity: pairing
  /// establishes trust, not discovery (`features/discovery/FEATURE.md` §12).
  final String deviceId;

  /// Display-only. Attacker-controlled, so escape it at render time.
  final String deviceName;

  final String address;
  final int port;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TransferDestination &&
          other.deviceId == deviceId &&
          other.deviceName == deviceName &&
          other.address == address &&
          other.port == port;

  @override
  int get hashCode => Object.hash(deviceId, deviceName, address, port);

  @override
  String toString() =>
      'TransferDestination(deviceId: $deviceId, deviceName: $deviceName, '
      'address: $address, port: $port)';
}
