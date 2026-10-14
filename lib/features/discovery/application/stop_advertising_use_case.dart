import 'package:partilha/core/errors/failure.dart';
import 'package:partilha/core/result/result.dart';
import 'package:partilha/features/discovery/domain/domain.dart';

/// Stops announcing the local device and releases multicast resources.
///
/// Follows `AGENTS.md` §12, §35 and `features/discovery/FEATURE.md` §15.
/// Prevents leaving phantom advertisements on the local network when receiving ends.
class StopAdvertisingUseCase {
  const StopAdvertisingUseCase(this._discovery);

  final DiscoveryService _discovery;

  /// Stops advertising this device on the local network.
  Future<Result<void, Failure>> call() => _discovery.stopAdvertising();
}
