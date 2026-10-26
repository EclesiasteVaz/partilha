import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:partilha/core/errors/failure.dart';
import 'package:partilha/core/network/local_address_resolver.dart';
import 'package:partilha/core/platform/platform.dart';
import 'package:partilha/core/protocol/qr_payload.dart';
import 'package:partilha/core/result/result.dart';
import 'package:partilha/core/theme/theme.dart';
import 'package:partilha/features/file_transfer/domain/domain.dart';
import 'package:partilha/features/file_transfer/presentation/receiver_controller.dart';
import 'package:partilha/features/pairing/presentation/pairing_controller.dart';
import 'package:partilha/features/pairing/presentation/pairing_state.dart';
import 'package:partilha/features/pairing/presentation/show_qr_screen.dart';
import 'package:qr_flutter/qr_flutter.dart';

class MockPairingController extends ChangeNotifier
    implements PairingController {
  PairingState _state = const PairingState.initial();

  @override
  PairingState get state => _state;

  void setState(PairingState newState) {
    _state = newState;
    notifyListeners();
  }

  @override
  Future<void> generateQr({required String host, required int port}) async {
    _state = PairingState.showingQr(
      payload: QrPayload(
        v: 1,
        deviceId: 'dev-1',
        deviceName: 'My Device',
        host: host,
        port: port,
        token: 'tok-123',
      ),
      rawQrString: '{"test": 1}',
    );
    notifyListeners();
  }

  @override
  void reset() {
    _state = const PairingState.initial();
    notifyListeners();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeAddressResolver implements DeviceAddressResolver {
  @override
  Future<Result<String, Failure>> getLocalIpv4Address() async =>
      const Result.success('192.168.1.10');
}

class FakeTransferServer implements TransferServer {
  final StreamController<TransferServerEvent> _events =
      StreamController<TransferServerEvent>.broadcast(sync: true);

  @override
  int? get port => 8080;

  @override
  Stream<TransferServerEvent> get events => _events.stream;

  @override
  Future<Result<void, Failure>> start({required int port}) async =>
      const Result.success(null);

  @override
  Future<Result<void, Failure>> stop() async => const Result.success(null);

  Future<void> dispose() => _events.close();
}

class FakeReceivedFileService implements ReceivedFileService {
  String? lastOpenedPath;
  bool shouldSucceed = true;

  @override
  Future<String> finalizeReceivedFile({
    required String sourcePath,
    required String fileName,
  }) async => sourcePath;

  @override
  Future<bool> openReceivedFile(String path) async {
    lastOpenedPath = path;
    return shouldSucceed;
  }
}

void main() {
  late MockPairingController pairingController;
  late ReceiverController receiverController;
  late FakeTransferServer transferServer;
  late FakeReceivedFileService receivedFileService;

  setUp(() {
    pairingController = MockPairingController();
    transferServer = FakeTransferServer();
    receivedFileService = FakeReceivedFileService();
    receiverController = ReceiverController(
      transferServer: transferServer,
      deviceAddressResolver: FakeAddressResolver(),
      pairingController: pairingController,
      receivedFileService: receivedFileService,
    );
  });

  tearDown(() async {
    await receiverController.stopReceiving();
    await transferServer.dispose();
  });

  Future<void> pumpScreen(
    WidgetTester tester, {
    VoidCallback? onDismiss,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: ShowQrScreen(
          controller: pairingController,
          receiverController: receiverController,
          onDismiss: onDismiss,
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('shows loading when initial or generating QR', (tester) async {
    pairingController.setState(const PairingState.generatingQr());
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: ShowQrScreen(
          controller: pairingController,
          receiverController: receiverController,
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('shows QR code and device info when ready', (tester) async {
    const payload = QrPayload(
      v: 1,
      deviceId: 'dev-1',
      deviceName: 'My Device',
      host: '192.168.1.10',
      port: 8080,
      token: 'tok-123',
    );
    pairingController.setState(
      const PairingState.showingQr(
        payload: payload,
        rawQrString: '{"test": 1}',
      ),
    );

    await pumpScreen(tester);
    await tester.pumpAndSettle();

    expect(find.byType(QrImageView), findsOneWidget);
    expect(find.text('My Device'), findsOneWidget);
    expect(find.text('192.168.1.10:8080'), findsOneWidget);
    expect(find.text('Ready to receive files'), findsOneWidget);
  });

  testWidgets('calls onDismiss when back button is tapped', (tester) async {
    bool dismissed = false;
    const payload = QrPayload(
      v: 1,
      deviceId: 'dev-1',
      deviceName: 'My Device',
      host: '192.168.1.10',
      port: 8080,
      token: 'tok-123',
    );
    pairingController.setState(
      const PairingState.showingQr(
        payload: payload,
        rawQrString: '{"test": 1}',
      ),
    );

    await pumpScreen(tester, onDismiss: () => dismissed = true);
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();

    expect(dismissed, isTrue);
  });

  testWidgets(
    'shows confirmation dialog when back button is tapped during active transfer and cancels exit',
    (tester) async {
      bool dismissed = false;
      const payload = QrPayload(
        v: 1,
        deviceId: 'dev-1',
        deviceName: 'My Device',
        host: '192.168.1.10',
        port: 8080,
        token: 'tok-123',
      );
      pairingController.setState(
        const PairingState.showingQr(
          payload: payload,
          rawQrString: '{"test": 1}',
        ),
      );

      await receiverController.startReceiving();
      await pumpScreen(tester, onDismiss: () => dismissed = true);
      await tester.pumpAndSettle();

      const offer = TransferOffer(
        id: 'xfer-1',
        name: 'file.txt',
        sizeInBytes: 1024,
        meta: {},
      );
      transferServer._events.add(TransferServerOfferReceived(offer: offer));
      await tester.pump();

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      expect(find.text('Cancel receiving?'), findsOneWidget);
      expect(dismissed, isFalse);

      await tester.tap(find.text('Continue receiving'));
      await tester.pumpAndSettle();

      expect(find.text('Cancel receiving?'), findsNothing);
      expect(dismissed, isFalse);
      expect(find.byType(ShowQrScreen), findsOneWidget);
    },
  );

  testWidgets(
    'confirms cancel dialog during active transfer and calls onDismiss',
    (tester) async {
      bool dismissed = false;
      const payload = QrPayload(
        v: 1,
        deviceId: 'dev-1',
        deviceName: 'My Device',
        host: '192.168.1.10',
        port: 8080,
        token: 'tok-123',
      );
      pairingController.setState(
        const PairingState.showingQr(
          payload: payload,
          rawQrString: '{"test": 1}',
        ),
      );

      await receiverController.startReceiving();
      await pumpScreen(tester, onDismiss: () => dismissed = true);
      await tester.pumpAndSettle();

      const offer = TransferOffer(
        id: 'xfer-1',
        name: 'file.txt',
        sizeInBytes: 1024,
        meta: {},
      );
      transferServer._events.add(TransferServerOfferReceived(offer: offer));
      await tester.pump();

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      expect(find.text('Cancel receiving?'), findsOneWidget);

      await tester.tap(find.text('Cancel transfer'));
      await tester.pumpAndSettle();

      expect(dismissed, isTrue);
    },
  );

  testWidgets('shows error state and try again button on failure', (
    tester,
  ) async {
    pairingController.setState(
      const PairingState.failed(failure: PairingFailure.invalidPayload),
    );

    await pumpScreen(tester);
    await tester.pumpAndSettle();

    expect(find.text('Failed to generate pairing QR'), findsOneWidget);
    expect(find.text('Try Again'), findsOneWidget);

    await tester.tap(find.text('Try Again'));
    await tester.pump();

    expect(pairingController.state, const PairingState.initial());
  });

  testWidgets('shows active receiving progress and received files list', (
    tester,
  ) async {
    const payload = QrPayload(
      v: 1,
      deviceId: 'dev-1',
      deviceName: 'My Device',
      host: '192.168.1.10',
      port: 8080,
      token: 'tok-123',
    );
    pairingController.setState(
      const PairingState.showingQr(
        payload: payload,
        rawQrString: '{"test": 1}',
      ),
    );

    await receiverController.startReceiving();
    await pumpScreen(tester);

    // Emit offer
    const offer = TransferOffer(
      id: 'xfer-1',
      name: 'document.pdf',
      sizeInBytes: 2048,
      meta: {},
    );
    transferServer._events.add(TransferServerOfferReceived(offer: offer));
    await tester.pump();

    expect(find.text('Receiving document.pdf...'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);

    // Emit done
    const file = SelectedFile(
      name: 'document.pdf',
      path: '/Downloads/document.pdf',
      sizeInBytes: 2048,
    );
    transferServer._events.add(
      TransferServerDone(transferId: 'xfer-1', file: file),
    );
    await tester.pump();

    expect(find.text('Received Files (1)'), findsOneWidget);
    expect(find.text('Saved to Downloads folder'), findsOneWidget);
    expect(find.text('document.pdf'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle), findsOneWidget);

    await tester.ensureVisible(find.text('document.pdf'));
    await tester.tap(find.text('document.pdf'));
    await tester.pump();
    expect(receivedFileService.lastOpenedPath, '/Downloads/document.pdf');
  });
}
