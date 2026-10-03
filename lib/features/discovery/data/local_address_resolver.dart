import 'dart:io';

/// Chooses which local network addresses a device announces and binds to.
///
/// Extracted because *which* interface to use is an unresolved policy question
/// (`features/discovery/FEATURE.md` §24, §34), and burying the choice inside a
/// socket call is what makes an undecided policy look like a decided one. As an
/// injected collaborator the decision has one home, is testable without a
/// network, and can be swapped when the policy is approved.
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
/// This is the default because it is the only choice that cannot make a network
/// silently undiscoverable.
///
/// The tempting alternative — pick one interface — is what this design rejects.
/// A dual-homed machine (Wi-Fi and Ethernet) would advertise an address the
/// sender cannot reach, and the symptom is a device that appears in some
/// networks and not others, which is far harder to diagnose than an address
/// list. mDNS SRV records carry several addresses, so peers can select the one
/// that answers.
///
/// The cost is honest: every address is published, including a VPN or docker
/// interface if one is up. Whether that is acceptable, and whether Partilha
/// should instead derive the address from the socket its receiver is actually
/// listening on, is the open question in `features/discovery/FEATURE.md` §34.
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
