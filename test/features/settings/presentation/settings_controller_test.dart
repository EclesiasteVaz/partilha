import 'package:flutter_test/flutter_test.dart';
import 'package:partilha/core/di/di.dart';
import 'package:partilha/core/errors/failure.dart';
import 'package:partilha/core/result/result.dart';
import 'package:partilha/features/settings/application/application.dart';
import 'package:partilha/features/settings/domain/domain.dart';
import 'package:partilha/features/settings/presentation/presentation.dart';

import '../fake_settings_repository.dart';

void main() {
  late FakeSettingsRepository repository;
  late SettingsController controller;

  SettingsController build() => SettingsController(
    getDeviceName: GetDeviceNameUseCase(repository),
    saveDeviceName: SaveDeviceNameUseCase(),
  );

  setUp(() {
    repository = FakeSettingsRepository();
    injectionContainer.registerLazySingleton<SettingsRepository>(
      () => repository,
    );
    addTearDown(injectionContainer.reset);
    controller = build();
  });

  test('starts idle, before anything has been asked of it', () {
    expect(controller.state.status, SettingsStatus.initial);
    expect(controller.state.draftName, isNull);
    expect(controller.canSave, isFalse);
  });

  group('load', () {
    test('publishes the stored name and becomes ready', () async {
      final DeviceName stored =
          (DeviceName.create('Desk') as Success<DeviceName, Failure>).value;
      repository = FakeSettingsRepository(initial: stored);
      controller = build();

      await controller.load();

      expect(controller.state.status, SettingsStatus.ready);
      expect(controller.state.persistedName, stored);
      expect(controller.state.draftName, 'Desk');
    });

    test('notifies so a bound UI repaints', () async {
      int notifications = 0;
      controller.addListener(() => notifications++);

      await controller.load();

      // loading, then ready. Zero would leave a spinner forever.
      expect(notifications, greaterThanOrEqualTo(2));
    });

    test(
      'a read failure leaves the form usable and shows the failure',
      () async {
        // The user can still type and try to save, which is the one action that
        // might recover. Showing a dead form would leave nothing to do.
        repository.failure = const StorageFailure();
        controller = build();

        await controller.load();

        expect(controller.state.status, SettingsStatus.ready);
        expect(controller.state.error, isA<StorageFailure>());
        expect(controller.state.draftName, DeviceName.fallback.value);
      },
    );

    test('a failure exposes userMessage, not an exception', () async {
      repository.failure = StorageFailure(cause: Exception('db exploded'));
      controller = build();

      await controller.load();

      final String message = controller.state.error!.userMessage;
      expect(message, isNot(contains('db exploded')));
    });
  });

  group('onDraftChanged', () {
    test('records the text and enables saving', () async {
      await controller.load();

      controller.onDraftChanged('Kitchen phone');

      expect(controller.state.draftName, 'Kitchen phone');
      expect(controller.canSave, isTrue);
    });

    test(
      'clears a previous failure, since the user changed the input',
      () async {
        repository.failure = const StorageFailure();
        controller = build();
        await controller.load();
        expect(controller.state.error, isNotNull);

        controller.onDraftChanged('New name');

        expect(controller.state.error, isNull);
      },
    );

    test(
      'a previous success stops being reported once typing resumes',
      () async {
        await controller.load();
        controller.onDraftChanged('First');
        await controller.save();
        expect(controller.state.status, SettingsStatus.saved);

        controller.onDraftChanged('Second');

        expect(controller.state.status, SettingsStatus.ready);
      },
    );
  });

  group('save', () {
    test('stores the trimmed name and reports it', () async {
      await controller.load();
      controller.onDraftChanged('  Kitchen phone  ');

      await controller.save();

      expect(repository.written?.value, 'Kitchen phone');
      expect(controller.state.status, SettingsStatus.saved);
      expect(controller.state.error, isNull);
    });

    test('re-reads after saving so the field shows what is stored', () async {
      // The saved value is trimmed, so echoing the draft could show a name that
      // is not the one persisted.
      await controller.load();
      controller.onDraftChanged('  Kitchen phone  ');

      await controller.save();

      expect(controller.state.draftName, 'Kitchen phone');
    });

    test('an invalid name never reaches storage', () async {
      await controller.load();
      controller.onDraftChanged('   ');

      await controller.save();

      expect(repository.written, isNull);
      expect(controller.state.error, isA<ValidationFailure>());
      expect(controller.state.status, SettingsStatus.ready);
    });

    test('a write failure is shown and leaves the form editable', () async {
      await controller.load();
      controller.onDraftChanged('Phone');
      repository.failure = const StorageFailure();

      await controller.save();

      expect(controller.state.error, isA<StorageFailure>());
      expect(controller.state.status, SettingsStatus.ready);
      expect(controller.canSave, isTrue);
    });

    test('does nothing when there is no draft yet', () async {
      await controller.save();

      expect(repository.written, isNull);
    });

    test(
      'cannot be started twice, because a second tap would write twice',
      () async {
        await controller.load();
        controller.onDraftChanged('Phone');

        final Future<void> first = controller.save();
        expect(
          controller.canSave,
          isFalse,
          reason: 'must be locked while saving',
        );
        await first;
      },
    );
  });
}
