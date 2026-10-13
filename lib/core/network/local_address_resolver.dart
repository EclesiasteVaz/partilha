import 'dart:io';

import 'package:partilha/core/errors/failure.dart';
import 'package:partilha/core/result/result.dart';

/// Contract for resolving the device's primary local IPv4 address on the LAN.
///
/// Follows `AGENTS.md` §16 and §41 (platform & network abstraction).
abstract interface class DeviceAddressResolver {
  /// Returns the device's best IPv4 address for local peer-to-peer connection,
  /// or a [NetworkFailure] if no suitable local network interface is found.
  Future<Result<String, Failure>> getLocalIpv4Address();
}

/// Concrete implementation resolving local network interfaces using `dart:io`.
///
/// Prioritizes private local IPv4 ranges (`192.168.x.x`, `10.x.x.x`, `172.16-31.x.x`)
/// and excludes loopback and virtual/link-local addresses.
final class NetworkInterfaceDeviceAddressResolver
    implements DeviceAddressResolver {
  const NetworkInterfaceDeviceAddressResolver();

  @override
  Future<Result<String, Failure>> getLocalIpv4Address() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      );

      if (interfaces.isEmpty) {
        return const Result.failure(NetworkFailure.unreachable);
      }

      // Priority 1: Private LAN ranges (192.168.x.x, 10.x.x.x, 172.16-31.x.x)
      for (final interface in interfaces) {
        for (final addr in interface.addresses) {
          final ip = addr.address;
          if (_isPrivateLanIpv4(ip)) {
            return Result.success(ip);
          }
        }
      }

      // Priority 2: Any non-loopback IPv4 address
      for (final interface in interfaces) {
        for (final addr in interface.addresses) {
          if (!addr.isLoopback && !addr.isLinkLocal) {
            return Result.success(addr.address);
          }
        }
      }

      return const Result.failure(NetworkFailure.unreachable);
    } on Object catch (e) {
      return Result.failure(
        NetworkFailure(
          cause: e,
          context: const <String, Object?>{
            'operation': 'getLocalIpv4Address',
          },
        ),
      );
    }
  }

  bool _isPrivateLanIpv4(String ip) {
    if (ip.startsWith('192.168.') || ip.startsWith('10.')) {
      return true;
    }
    if (ip.startsWith('172.')) {
      final parts = ip.split('.');
      if (parts.length >= 2) {
        final secondOctet = int.tryParse(parts[1]);
        if (secondOctet != null && secondOctet >= 16 && secondOctet <= 31) {
          return true;
        }
      }
    }
    return false;
  }
}
