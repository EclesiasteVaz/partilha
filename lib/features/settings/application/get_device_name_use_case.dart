import 'package:partilha/core/errors/failure.dart';
import 'package:partilha/core/result/result.dart';
import 'package:partilha/features/settings/domain/domain.dart';

/// Reads the device name the user has chosen.
///
/// Exists as a named operation rather than being called on the repository from
/// the controller, so the screen depends on an action it can ask for instead of
/// on storage (`AGENTS.md` §12).
class GetDeviceNameUseCase {
  const GetDeviceNameUseCase(this._settingsRepository);

  final SettingsRepository _settingsRepository;

  Future<Result<DeviceName, Failure>> call() =>
      _settingsRepository.readDeviceName();
}
