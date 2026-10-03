import 'dart:io';

/// Chooses which local network addresses a device announces and binds to.
///
/// The policy is decided (`features/discovery/FEATURE.md` §34.1): the receiver
/// advertises the addresses its listening socket is bound to, so this fact
/// belongs to whoever owns that socket, which is the transport. Discovery
/// receives the answer instead of guessing it.
///
/// This seam exists so the interim implementation is one testable decision
/// rather than logic buried in a socket call, and so the transport can take
/// ownership later without touching the service.
///
/// Lives in the data layer because it reads `dart:io` interfaces, which the
/// domain must not see (`AGENTS.md` §5, §42).
abstract interface class LocalAddressResolver {
  /// Addresses to announce, optionally restricted to one named interface.
  ///
  /// [interfaceName] matches [NetworkInterface.name], e.g. `en0` on macOS or
  /// `wlan0` on Android. When null the resolver applies its own default.
  Future<List<InternetAddress>> resolve({String? interfaceName});
}

/// Announces every non-loopback address.
///
/// Interim implementation of the decision in `FEATURE.md` §34.1, and correct
/// for exactly one reason: the transport will bind to `0.0.0.0`, so the receiver
/// really is reachable on all of them.
///
/// That dependency is the whole justification. If the transport ever binds to a
/// single address, this becomes wrong and must be replaced by a
/// transport-owned implementation.
///
/// The alternative rejected here was picking one interface. A dual-homed machine
/// would advertise an address the sender cannot reach, and the symptom is a
/// device visible in some networks and missing from others — much harder to
/// diagnose than an address list. mDNS SRV records carry several addresses, so
/// peers select the one that answers.
///
/// Known cost: every non-loopback address is published, including a VPN or
/// container interface. Tolerable on the LAN only while the sender tries every
/// advertised address, which is still an open question in `FEATURE.md` §34.
class AllNonLoopbackAddresses implements LocalAddressResolver {
  const AllNonLoopbackAddresses();

  @override
  Future<List<InternetAddress>> resolve({String? interfaceName}) async {
    final List<InternetAddress> found = <InternetAddress>[];
    for (final NetworkInterface interface in await NetworkInterface.list(
      includeLoopback: false,
    )) {
      if (interfaceName != null && interface.name != interfaceName) continue;
      for (final InternetAddress address in interface.addresses) {
        if (!address.isLoopback) found.add(address);
      }
    }
    return found;
  }
}
