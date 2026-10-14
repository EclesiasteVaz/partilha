import 'package:partilha/core/errors/failure.dart';
import 'package:partilha/core/result/result.dart';
import 'package:partilha/features/discovery/domain/domain.dart';

/// Announces the local device on the network as a receiver.
///
/// Follows `AGENTS.md` §12, §35 and `features/discovery/FEATURE.md` §5-§6.
/// Delegates directly to [DiscoveryService.startAdvertising] without exposing
/// underlying mDNS socket mechanics. The token is explicitly omitted in
/// adherence to `docs/decisions/0003-token-fora-do-mdns.md`.
class StartAdvertisingUseCase {
  const StartAdvertisingUseCase(this._discovery);

  final DiscoveryService _discovery;

  /// Starts advertising this device on the local network.
  Future<Result<void, Failure>> call({
    required String deviceId,
    required String deviceName,
    required int port,
    required Map<String, String> capabilities,
    String? interfaceName,
  }) =>
      _discovery.startAdvertising(
        deviceId: deviceId,
        deviceName: deviceName,
        port: port,
        capabilities: capabilities,
        interfaceName: interfaceName,
      );
}
