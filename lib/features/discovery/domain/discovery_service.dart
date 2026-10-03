import 'package:partilha/core/errors/failure.dart';
import 'package:partilha/core/result/result.dart';
import 'package:partilha/features/discovery/domain/discovered_device.dart';

/// Locates Partilha receivers on the local network.
///
/// The contract is expressed in application terms so that presentation and
/// application code never learn that mDNS exists (`AGENTS.md` §35, §51). The
/// implementation owns the mDNS package entirely and converts package
/// exceptions into project-owned [Failure] values (`AGENTS.md` §15).
abstract interface class DiscoveryService {
  /// Searches for nearby devices.
  ///
  /// Returns a single-shot result rather than a live stream on purpose: the
  /// provider being validated collects a fixed response window, and pretending
  /// otherwise would hide the difference between "found nothing yet" and
  /// "discovery ended" (`AGENTS.md` §83). A long-lived stream is an open
  /// design question recorded in `features/discovery/FEATURE.md` §34.
  ///
  /// Records that fail validation are dropped rather than returned, because a
  /// malformed or hostile announcement must never surface as a usable device
  /// (§12, §28).
  Future<Result<List<DiscoveredDevice>, Failure>> discover();

  /// Announces this device as a receiver.
  ///
  /// [port] is the port the local receiver is actually listening on. The token
  /// is not a parameter, which is how the "token never in mDNS" rule is
  /// enforced structurally instead of by convention
  /// (`docs/decisions/0003-token-fora-do-mdns.md`).
  ///
  /// [interfaceName] restricts the announcement to one local interface, e.g.
  /// `wlan0`. Null lets the implementation apply its default policy, which is
  /// still `OPEN — APPROVAL REQUIRED` (`features/discovery/FEATURE.md` §24, §34).
  Future<Result<void, Failure>> startAdvertising({
    required String deviceId,
    required String deviceName,
    required int port,
    required Map<String, String> capabilities,
    String? interfaceName,
  });

  /// Stops announcing and releases multicast resources.
  ///
  /// Leaving a phantom advertisement behind makes other devices see a device
  /// that cannot be connected to (`AGENTS.md` §80, §81).
  Future<Result<void, Failure>> stopAdvertising();
}
