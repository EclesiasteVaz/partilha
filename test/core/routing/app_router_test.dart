import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:partilha/core/di/di.dart';
import 'package:partilha/core/errors/failure.dart';
import 'package:partilha/core/logging/logging.dart';
import 'package:partilha/core/protocol/qr_payload.dart';
import 'package:partilha/core/result/result.dart';
import 'package:partilha/core/routing/routing.dart';
import 'package:partilha/core/theme/theme.dart';
import 'package:partilha/features/discovery/domain/domain.dart';
import 'package:partilha/features/file_transfer/domain/domain.dart';
import 'package:partilha/features/file_transfer/presentation/presentation.dart';
import 'package:partilha/features/pairing/presentation/pairing_controller.dart';

class _FakeDiscoveryService implements DiscoveryService {
  @override
  Future<Result<List<DiscoveredDevice>, Failure>> discover() async =>
      const Result<List<DiscoveredDevice>, Failure>.success(
        <DiscoveredDevice>[],
      );

  @override
  Future<Result<void, Failure>> startAdvertising({
    required String deviceId,
    required String deviceName,
    required int port,
    required Map<String, String> capabilities,
    String? interfaceName,
  }) async => const Result<void, Failure>.success(null);

  @override
  Future<Result<void, Failure>> stopAdvertising() async =>
      const Result<void, Failure>.success(null);
}

Widget _buildApp(AppRouterDelegate delegate) {
  return MaterialApp(
    theme: AppTheme.dark,
    home: Router<AppRoute>(
      routeInformationParser: const AppRouteInformationParser(),
      routerDelegate: delegate,
    ),
  );
}

void main() {
  setUp(() {
    configureDependencies(logger: StructuredLogger(sink: RecordingLogSink()));
    injectionContainer.overrideLazySingleton<DiscoveryService>(
      _FakeDiscoveryService.new,
    );
  });

  tearDown(() async {
    await injectionContainer.reset();
  });

  testWidgets('onDidRemovePage updates CurrentRoute when page is popped', (
    tester,
  ) async {
    final CurrentRoute currentRoute = CurrentRoute();
    final AppRouterDelegate delegate = AppRouterDelegate(currentRoute);

    await tester.pumpWidget(_buildApp(delegate));
    await tester.pump();

    // Push Send
    currentRoute.push(AppRoute.send);
    await tester.pumpAndSettle();
    expect(currentRoute.stack, <AppRoute>[AppRoute.settings, AppRoute.send]);

    // Tap back button in AppBar
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    // onDidRemovePage should have popped CurrentRoute
    expect(currentRoute.stack, <AppRoute>[AppRoute.settings]);
    expect(currentRoute.value, AppRoute.settings);
  });

  testWidgets('popRoute delegates to Navigator and pops CurrentRoute', (
    tester,
  ) async {
    final CurrentRoute currentRoute = CurrentRoute();
    final AppRouterDelegate delegate = AppRouterDelegate(currentRoute);

    await tester.pumpWidget(_buildApp(delegate));
    await tester.pump();

    currentRoute.push(AppRoute.send);
    await tester.pumpAndSettle();
    expect(currentRoute.stack.length, 2);

    final bool handled = await delegate.popRoute();
    await tester.pumpAndSettle();

    expect(handled, isTrue);
    expect(currentRoute.stack, <AppRoute>[AppRoute.settings]);
  });

  testWidgets(
    'onPaired pops instead of duplicating when transfer is already on stack',
    (tester) async {
      final CurrentRoute currentRoute = CurrentRoute();
      final AppRouterDelegate delegate = AppRouterDelegate(currentRoute);

      await tester.pumpWidget(_buildApp(delegate));
      await tester.pump();

      // Simulate coming from discovery -> transfer -> scanQr
      currentRoute.push(AppRoute.send);
      currentRoute.push(AppRoute.transfer);
      currentRoute.push(AppRoute.scanQr);
      await tester.pumpAndSettle();

      expect(currentRoute.stack, <AppRoute>[
        AppRoute.settings,
        AppRoute.send,
        AppRoute.transfer,
        AppRoute.scanQr,
      ]);

      final PairingController pairingController = injectionContainer
          .resolve<PairingController>();
      const payload = QrPayload(
        v: 1,
        deviceId: 'peer-1',
        deviceName: 'Peer Device',
        host: '192.168.1.50',
        port: 8080,
        token: 'token-abc',
      );
      final raw = pairingController.validateQrCodeUseCase.encode(payload);
      await pairingController.onQrScanned(raw);
      await tester.pumpAndSettle();

      // Stack should NOT contain duplicate transfer screens
      expect(currentRoute.stack, <AppRoute>[
        AppRoute.settings,
        AppRoute.send,
        AppRoute.transfer,
      ]);

      final TransferDestination? dest = injectionContainer
          .resolve<TransferController>()
          .state
          .destination;
      expect(dest?.deviceId, 'peer-1');
      expect(dest?.token, 'token-abc');
    },
  );

  testWidgets(
    'onPaired replaces scanQr with transfer when transfer was not on stack',
    (tester) async {
      final CurrentRoute currentRoute = CurrentRoute();
      final AppRouterDelegate delegate = AppRouterDelegate(currentRoute);

      await tester.pumpWidget(_buildApp(delegate));
      await tester.pump();

      // Simulate coming directly from send -> scanQr
      currentRoute.push(AppRoute.send);
      currentRoute.push(AppRoute.scanQr);
      await tester.pumpAndSettle();

      expect(currentRoute.stack, <AppRoute>[
        AppRoute.settings,
        AppRoute.send,
        AppRoute.scanQr,
      ]);

      final PairingController pairingController = injectionContainer
          .resolve<PairingController>();
      const payload = QrPayload(
        v: 1,
        deviceId: 'peer-2',
        deviceName: 'Peer 2',
        host: '192.168.1.60',
        port: 8080,
        token: 'token-xyz',
      );
      final raw = pairingController.validateQrCodeUseCase.encode(payload);
      await pairingController.onQrScanned(raw);
      await tester.pumpAndSettle();

      expect(currentRoute.stack, <AppRoute>[
        AppRoute.settings,
        AppRoute.send,
        AppRoute.transfer,
      ]);
    },
  );
}
