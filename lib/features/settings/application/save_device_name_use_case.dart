import 'package:partilha/core/di/di.dart';
import 'package:partilha/core/errors/failure.dart';
import 'package:partilha/core/result/result.dart';
import 'package:partilha/features/settings/domain/domain.dart';

/// Saves a new device name.
///
/// Validation lives here rather than in the controller so that the rule holds for
/// every caller: a future pairing flow that asks for a name must not be able to
/// bypass the limit by having its own path to the repository. The controller
/// receives text; this is where text becomes a [DeviceName] or a failure.
///
/// The repository is resolved lazily on first use instead of in the constructor.
/// A use case holds no resource of its own, so building one eagerly would make
/// every screen that asks for a name force the database open at startup
/// (`AGENTS.md` §81).
class SaveDeviceNameUseCase {
  SaveDeviceNameUseCase();

  SettingsRepository get _settingsRepository =>
      injectionContainer.resolve<SettingsRepository>();

  Future<Result<void, Failure>> call(String input) async {
    final Result<DeviceName, Failure> validated = DeviceName.create(input);

    return switch (validated) {
      Success(:final value) => _settingsRepository.saveDeviceName(value),
      Err(:final error) => Result<void, Failure>.failure(error),
    };
  }
}
