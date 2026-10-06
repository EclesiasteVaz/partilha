import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:partilha/core/di/di.dart';
import 'package:partilha/core/errors/failure.dart';
import 'package:partilha/core/logging/logging.dart';
import 'package:partilha/core/result/result.dart';
import 'package:partilha/core/routing/routing.dart';
import 'package:partilha/core/theme/theme.dart';
import 'package:partilha/features/discovery/domain/domain.dart';
import 'package:partilha/features/file_transfer/application/application.dart';
import 'package:partilha/features/file_transfer/domain/domain.dart';
import 'package:partilha/features/file_transfer/presentation/presentation.dart';

/// A [DiscoveryService] that answers with a scripted list.
///
/// Standing in for mDNS at this level: the point is the interaction between the
/// screen, the router and the transfer controller, not the provider
/// (`AGENTS.md` §60.3).
class ScriptedDiscoveryService implements DiscoveryService {
  ScriptedDiscoveryService(this.devices);

  List<DiscoveredDevice> devices;
  int callCount = 0;

  @override
  Future<Result<List<DiscoveredDevice>, Failure>> discover() async {
    callCount++;
    return Result<List<DiscoveredDevice>, Failure>.success(devices);
  }

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

void main() {
  // Late-bound so the closures passed to the container can return the instance
  // each setUp creates, without capturing a stale one.
  late ScriptedDiscoveryService service;
  late TransferController transferController;

  DiscoveryService serviceResolver() => service;
  TransferController transferControllerResolver() => transferController;

  const DiscoveredDevice alice = DiscoveredDevice(
    deviceId: 'id-1',
    deviceName: 'Alice',
    address: '192.168.1.10',
    port: 4443,
    capabilities: <String, String>{},
  );

  late CurrentRoute currentRoute;

  setUp(() async {
    await injectionContainer.reset();
    // The real graph, so the router resolves every screen it may build. Only the
    // two pieces this test controls are replaced: an mDNS provider that does not
    // touch the network, and a picker that never opens a dialog.
    configureDependencies(logger: StructuredLogger(sink: RecordingLogSink()));
    service = ScriptedDiscoveryService(<DiscoveredDevice>[alice]);
    transferController = TransferController(
      selectFiles: SelectFilesUseCase(_CancelledPicker()),
    );
    injectionContainer
      ..overrideLazySingleton<DiscoveryService>(serviceResolver)
      ..overrideLazySingleton<TransferController>(transferControllerResolver);
    addTearDown(injectionContainer.reset);
    currentRoute = CurrentRoute()..push(AppRoute.send);
  });

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Router(
          routeInformationParser: const AppRouteInformationParser(),
          routerDelegate: AppRouterDelegate(currentRoute),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('lists the devices it found', (tester) async {
    await pump(tester);

    expect(find.text('Alice'), findsOneWidget);
    expect(find.text('192.168.1.10:4443'), findsOneWidget);
  });

  testWidgets('tapping a device hands over the destination', (tester) async {
    // This is the regression test for the crash: the screen resolves
    // TransferController from the graph, and an unregistered controller threw
    // here while every other test kept passing.
    await pump(tester);

    await tester.tap(find.text('Alice'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    final destination = transferController.state.destination;
    expect(destination, isNotNull);
    expect(destination!.deviceId, 'id-1');
    expect(destination.deviceName, 'Alice');
    expect(destination.address, '192.168.1.10');
    expect(destination.port, 4443);
  });

  testWidgets('tapping a device opens the transfer screen', (tester) async {
    await pump(tester);

    await tester.tap(find.text('Alice'));
    await tester.pumpAndSettle();

    expect(find.byType(TransferScreen), findsOneWidget);
    // The chosen device is visible on the next screen, so the user can see what
    // they picked before choosing files.
    expect(find.text('Alice'), findsOneWidget);
  });

  testWidgets('the destination excludes untrusted advertised capabilities', (
    tester,
  ) async {
    // `capabilities` is plaintext LAN input and must not cross into transfer.
    service.devices = <DiscoveredDevice>[
      const DiscoveredDevice(
        deviceId: 'id-1',
        deviceName: 'Alice',
        address: '192.168.1.10',
        port: 4443,
        capabilities: <String, String>{'pairing': 'true'},
      ),
    ];

    await pump(tester);
    await tester.tap(find.text('Alice'));
    await tester.pumpAndSettle();

    expect(transferController.state.destination, isNotNull);
    expect(
      transferController.state.destination.toString(),
      isNot(contains('pairing')),
    );
  });

  testWidgets('picking no devices explains what to do', (tester) async {
    service.devices = <DiscoveredDevice>[];

    await pump(tester);

    expect(find.textContaining('No devices'), findsWidgets);
  });
}

class _CancelledPicker implements FileSelectionService {
  @override
  Future<Result<List<SelectedFile>, Failure>> pickFiles() async =>
      const Result<List<SelectedFile>, Failure>.success(<SelectedFile>[]);
}
