import 'package:partilha/core/errors/failure.dart';
import 'package:partilha/core/result/result.dart';
import 'package:partilha/features/discovery/domain/domain.dart';

/// Searches the local network once and returns the devices that answered.
///
/// Exists so that the controller depends on an application action rather than on
/// the mDNS provider behind [DiscoveryService] (`AGENTS.md` §12, §35). It adds
/// no orchestration of its own: there is nothing to coordinate until the
/// advertising side exists, and inventing coordination here would be a policy
/// nobody approved (`features/discovery/FEATURE.md` §34).
///
/// Single-shot by contract, not by choice. `features/discovery/FEATURE.md` §6
/// wants devices detected as they appear and disappear, which a stream would
/// model directly, but §34 still lists that as an open question. Polling to fake
/// continuity would invent a scan interval, so the controller searches when the
/// screen appears and when the user asks, and the limitation is recorded in the
/// feature document.
class DiscoverNearbyDevicesUseCase {
  const DiscoverNearbyDevicesUseCase(this._discovery);

  final DiscoveryService _discovery;

  /// Runs one search.
  ///
  /// Devices are returned as the provider reported them. Dropping invalid
  /// records is the data layer's job, not this one's, because only it knows what
  /// the provider actually produced (`features/discovery/FEATURE.md` §12).
  Future<Result<List<DiscoveredDevice>, Failure>> call() =>
      _discovery.discover();
}
