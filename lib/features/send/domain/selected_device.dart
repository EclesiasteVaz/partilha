import 'package:partilha/features/discovery/domain/discovered_device.dart';

/// A device the user has chosen to send files to.
///
/// Deliberately a small value object to keep the file selection and transfer
/// flows separate from the discovery payload. We don't copy the entire
/// `DiscoveredDevice` across feature boundaries unnecessarily; instead, we keep
/// the values the Send flow actually needs.
class SelectedDevice {
  const SelectedDevice({
    required this.deviceId,
    required this.deviceName,
    required this.address,
    required this.port,
  });

  final String deviceId;
  final String deviceName;
  final String address;
  final int port;

  factory SelectedDevice.fromDiscovered(DiscoveredDevice device) {
    return SelectedDevice(
      deviceId: device.deviceId,
      deviceName: device.deviceName,
      address: device.address,
      port: device.port,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SelectedDevice &&
          other.deviceId == deviceId &&
          other.deviceName == deviceName &&
          other.address == address &&
          other.port == port;

  @override
  int get hashCode => Object.hash(deviceId, deviceName, address, port);

  @override
  String toString() =>
      'SelectedDevice(deviceId: $deviceId, deviceName: $deviceName, '
      'address: $address, port: $port)';
}
