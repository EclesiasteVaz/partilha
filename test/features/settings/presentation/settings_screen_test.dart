import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:partilha/core/di/di.dart';
import 'package:partilha/core/errors/failure.dart';
import 'package:partilha/core/result/result.dart';
import 'package:partilha/core/theme/theme.dart';
import 'package:partilha/features/settings/application/application.dart';
import 'package:partilha/features/settings/domain/domain.dart';
import 'package:partilha/features/settings/presentation/presentation.dart';

import '../fake_settings_repository.dart';

void main() {
  late FakeSettingsRepository repository;
  late SettingsController controller;

  setUp(() {
    repository = FakeSettingsRepository();
    injectionContainer.registerLazySingleton<SettingsRepository>(
      () => repository,
    );
    addTearDown(injectionContainer.reset);
    controller = SettingsController(
      getDeviceName: GetDeviceNameUseCase(repository),
      saveDeviceName: SaveDeviceNameUseCase(),
    );
  });

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: SettingsScreen(controller: controller),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows the stored name in the field', (tester) async {
    repository = FakeSettingsRepository(
      initial:
          (DeviceName.create('Desk') as Success<DeviceName, Failure>).value,
    );
    controller = SettingsController(
      getDeviceName: GetDeviceNameUseCase(repository),
      saveDeviceName: SaveDeviceNameUseCase(),
    );

    await pump(tester);

    expect(find.text('Desk'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Desk'), findsOneWidget);
  });

  testWidgets('offers the fallback when nothing is stored', (tester) async {
    // The fallback is prefilled rather than left blank, so an unconfigured device
    // is identifiable instead of anonymous. Asserted on the field's own value
    // because it happens to equal the hint text.
    await pump(tester);

    final TextField field = tester.widget<TextField>(find.byType(TextField));

    expect(field.controller!.text, DeviceName.fallback.value);
  });

  testWidgets('typing reaches the controller', (tester) async {
    await pump(tester);

    await tester.enterText(find.byType(TextField), 'Kitchen phone');
    await tester.pump();

    expect(controller.state.draftName, 'Kitchen phone');
  });

  testWidgets('saving confirms in text, not colour alone', (tester) async {
    await pump(tester);
    await tester.enterText(find.byType(TextField), 'Kitchen phone');
    await tester.pump();

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Device name saved.'), findsOneWidget);
    expect(repository.written?.value, 'Kitchen phone');
  });

  testWidgets('a storage failure is shown as text the user can read', (
    tester,
  ) async {
    await pump(tester);
    repository.failure = const StorageFailure();
    await tester.enterText(find.byType(TextField), 'Phone');
    await tester.pump();

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Could not access local storage.'), findsOneWidget);
  });

  testWidgets('an empty name is refused without reaching storage', (
    tester,
  ) async {
    await pump(tester);

    await tester.enterText(find.byType(TextField), '   ');
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(repository.written, isNull);
    expect(find.text('This is required.'), findsOneWidget);
  });

  testWidgets('the status is announced, so it reaches a screen reader', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: SettingsScreen(controller: controller),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Phone');
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final Finder status = find.ancestor(
      of: find.text('Device name saved.'),
      matching: find.byType(Semantics),
    );
    expect(status, findsWidgets);
    expect(
      tester.widget<Semantics>(status.first).properties.liveRegion,
      isTrue,
      reason: 'a status conveyed only visually is invisible to a screen reader',
    );
  });

  testWidgets('the save control is a real touch target', (tester) async {
    await pump(tester);

    final Size size = tester.getSize(find.widgetWithText(FilledButton, 'Save'));

    expect(size.height, greaterThanOrEqualTo(AppSizes.minTouchTarget));
  });

  testWidgets('caps its width on a wide window instead of stretching', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(2560, 1440);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await pump(tester);

    final Size size = tester.getSize(find.byType(TextField));
    expect(size.width, lessThanOrEqualTo(AppSpacing.maxContentWidth));
  });
}
