import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:partilha/core/di/di.dart';
import 'package:partilha/core/logging/logging.dart';
import 'package:partilha/core/routing/routing.dart';
import 'package:partilha/features/settings/application/application.dart';
import 'package:partilha/features/settings/data/data.dart';
import 'package:partilha/features/settings/domain/domain.dart';
import 'package:partilha/features/settings/presentation/presentation.dart';
import 'package:partilha/main.dart';

/// App-level tests: the composition root and the router wiring.
///
/// The Settings feature's own behaviour is covered in
/// `test/features/settings/`. These tests use the real dependency graph, so a
/// registration that is missing from `configureDependencies()` fails here rather
/// than as a blank screen a user has to diagnose.
void main() {
  setUp(() {
    configureDependencies(logger: StructuredLogger(sink: RecordingLogSink()));
  });

  tearDown(() async {
    await injectionContainer.reset();
  });

  test('configureDependencies registers the whole Settings graph', () {
    expect(injectionContainer.isRegistered<SettingsLocalDataSource>(), isTrue);
    expect(injectionContainer.isRegistered<SettingsRepository>(), isTrue);
    expect(injectionContainer.isRegistered<GetDeviceNameUseCase>(), isTrue);
    expect(injectionContainer.isRegistered<SaveDeviceNameUseCase>(), isTrue);
    expect(injectionContainer.isRegistered<SettingsController>(), isTrue);
    expect(injectionContainer.isRegistered<SettingsScreen>(), isTrue);
  });

  test('the repositories resolve to the SQLite implementations', () {
    // Resolving as a named type rather than by string, so renaming the
    // implementation fails the test instead of silently falling back.
    expect(
      injectionContainer.resolve<SettingsLocalDataSource>(),
      isA<SqliteSettingsLocalDataSource>(),
    );
    expect(
      injectionContainer.resolve<SettingsRepository>(),
      isA<SqliteSettingsRepository>(),
    );
  });

  testWidgets('lands on a real screen, not a placeholder', (tester) async {
    await tester.pumpWidget(PartilhaApp(currentRoute: CurrentRoute()));
    await tester.pumpAndSettle();

    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(
      find.text('Under construction. No feature is implemented yet.'),
      findsNothing,
    );
    expect(find.text('Flutter Demo Home Page'), findsNothing);
    expect(find.byType(FloatingActionButton), findsNothing);
  });

  testWidgets('is not labelled as a debug build', (tester) async {
    await tester.pumpWidget(PartilhaApp(currentRoute: CurrentRoute()));
    await tester.pumpAndSettle();

    final MaterialApp app = tester.widget<MaterialApp>(
      find.byType(MaterialApp),
    );
    expect(app.debugShowCheckedModeBanner, isFalse);
    expect(app.title, 'Partilha');
  });

  testWidgets('renders the project theme rather than the platform default', (
    tester,
  ) async {
    await tester.pumpWidget(PartilhaApp(currentRoute: CurrentRoute()));
    await tester.pumpAndSettle();

    expect(
      Theme.of(tester.element(find.byType(MaterialApp))).useMaterial3,
      isTrue,
    );
  });

  testWidgets('the shell renders without throwing, whatever storage does', (
    tester,
  ) async {
    // The storage-backed load is deliberately not pumped to completion here: the
    // sqflite plugin has no implementation under flutter_test, so that call never
    // returns and asserting on it would test the test environment. What matters at
    // this level is that the shell and the real object graph survive an unresolved
    // dependency instead of throwing during build. The loaded, empty and failed
    // states are covered deterministically in settings_screen_test.dart.
    await tester.pumpWidget(PartilhaApp(currentRoute: CurrentRoute()));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
  });
}
