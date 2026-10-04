import 'package:flutter_test/flutter_test.dart';
import 'package:partilha/core/di/di.dart';
import 'package:partilha/core/errors/failure.dart';
import 'package:partilha/core/result/result.dart';
import 'package:partilha/features/settings/application/application.dart';
import 'package:partilha/features/settings/domain/domain.dart';

import '../fake_settings_repository.dart';

void main() {
  late FakeSettingsRepository repository;
  late GetDeviceNameUseCase getDeviceName;
  late SaveDeviceNameUseCase saveDeviceName;

  setUp(() async {
    repository = FakeSettingsRepository();
    getDeviceName = GetDeviceNameUseCase(repository);
    saveDeviceName = SaveDeviceNameUseCase();
    // The save use case resolves its repository from the container, which is what
    // lets the validation rule sit in one place regardless of caller.
    injectionContainer.registerLazySingleton<SettingsRepository>(
      () => repository,
    );
    addTearDown(injectionContainer.reset);
  });

  group('GetDeviceNameUseCase', () {
    test('returns what is stored', () async {
      final DeviceName stored =
          (DeviceName.create('Desk') as Success<DeviceName, Failure>).value;
      repository = FakeSettingsRepository(initial: stored);
      getDeviceName = GetDeviceNameUseCase(repository);

      final result = await getDeviceName();

      expect((result as Success<DeviceName, Failure>).value, stored);
    });

    test('surfaces a storage failure instead of a fallback', () async {
      repository.failure = const StorageFailure();
      getDeviceName = GetDeviceNameUseCase(repository);

      final result = await getDeviceName();

      expect(result, isA<Err<DeviceName, Failure>>());
    });
  });

  group('SaveDeviceNameUseCase', () {
    test('saves a valid name', () async {
      final result = await saveDeviceName('  Kitchen phone  ');

      expect(result, isA<Success<void, Failure>>());
      // Trimmed, because what was stored is what will be advertised.
      expect(repository.written?.value, 'Kitchen phone');
    });

    test('does not touch storage when the name is invalid', () async {
      final result = await saveDeviceName('   ');

      expect(result, isA<Err<void, Failure>>());
      expect(repository.written, isNull);
    });

    test('does not touch storage when the name is too long', () async {
      final result = await saveDeviceName('a' * (DeviceName.maxLength + 1));

      expect(result, isA<Err<void, Failure>>());
      expect(repository.written, isNull);
    });

    test('surfaces a storage failure', () async {
      repository.failure = const StorageFailure();

      final result = await saveDeviceName('Phone');

      expect(result, isA<Err<void, Failure>>());
    });
  });
}
