import 'package:partilha/features/discovery/domain/discovered_device.dart';
import 'package:partilha/features/send/domain/selected_device.dart';

/// Records which device the user wants to send files to.
///
/// No storage yet — the selection lives for the duration of the send flow.
/// If persistence of "last device used" is needed later, it belongs in its own
/// use case/repository, not here.
class SelectDeviceUseCase {
  const SelectDeviceUseCase();

  SelectedDevice call(DiscoveredDevice device) {
    return SelectedDevice.fromDiscovered(device);
  }
}
