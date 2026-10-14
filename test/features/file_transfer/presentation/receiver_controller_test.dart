import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:partilha/core/errors/failure.dart';
import 'package:partilha/core/network/local_address_resolver.dart';
import 'package:partilha/core/result/result.dart';
import 'package:partilha/features/discovery/application/start_advertising_use_case.dart';
import 'package:partilha/features/discovery/application/stop_advertising_use_case.dart';
import 'package:partilha/features/discovery/domain/domain.dart';
import 'package:partilha/features/file_transfer/domain/domain.dart';
import 'package:partilha/features/file_transfer/presentation/receiver_controller.dart';
import 'package:partilha/features/pairing/application/application.dart';
import 'package:partilha/features/pairing/data/json_qr_code_service.dart';
import 'package:partilha/features/pairing/domain/domain.dart';
import 'package:partilha/features/pairing/presentation/pairing_controller.dart';
import 'package:partilha/features/pairing/presentation/pairing_state.dart';
import 'package:partilha/features/settings/domain/domain.dart';

class FakeDeviceAddressResolver implements DeviceAddressResolver {
  FakeDeviceAddressResolver({this.ip = '192.168.1.42'});

  final String ip;

  @override
  Future<Result<String, Failure>> getLocalIpv4Address() async {
    return Result.success(ip);
  }
}

class FakeTransferServer implements TransferServer {
  int? _port;
  bool isRunning = false;
  final StreamController<TransferServerEvent> _eventsController =
      StreamController<TransferServerEvent>.broadcast();

  @override
  int? get port => _port;

  @override
  Stream<TransferServerEvent> get events => _eventsController.stream;

  void emitEvent(TransferServerEvent event) {
    _eventsController.add(event);
  }

  @override
  Future<Result<void, Failure>> start({required int port}) async {
    _port = 8888;
    isRunning = true;
    return const Result.success(null);
  }

  @override
  Future<Result<void, Failure>> stop() async {
    _port = null;
    isRunning = false;
    return const Result.success(null);
  }
}

class FakePairingRepository implements PairingRepository {
  @override
  Future<Result<DeviceIdentity, Failure>> getOrCreateIdentity() async {
    return const Result.success(
      DeviceIdentity(deviceId: 'rec-dev', token: 'secret-tok'),
    );
  }
}

class FakeSettingsRepository implements SettingsRepository {
  @override
  Future<Result<DeviceName, Failure>> readDeviceName() async {
    return Result.success(DeviceName.create('Receiver Mac').valueOrNull!);
  }

  @override
  Future<Result<void, Failure>> saveDeviceName(DeviceName name) async {
    return const Result.success(null);
  }
}

class FakeDiscoveryService implements DiscoveryService {
  bool isAdvertising = false;
  String? advertisedDeviceId;
  String? advertisedDeviceName;
  int? advertisedPort;

  @override
  Future<Result<List<DiscoveredDevice>, Failure>> discover() async =>
      const Result.success(<DiscoveredDevice>[]);

  @override
  Future<Result<void, Failure>> startAdvertising({
    required String deviceId,
    required String deviceName,
    required int port,
    required Map<String, String> capabilities,
    String? interfaceName,
  }) async {
    isAdvertising = true;
    advertisedDeviceId = deviceId;
    advertisedDeviceName = deviceName;
    advertisedPort = port;
    return const Result.success(null);
  }

  @override
  Future<Result<void, Failure>> stopAdvertising() async {
    isAdvertising = false;
    return const Result.success(null);
  }
}

void main() {
  late FakeTransferServer transferServer;
  late FakeDeviceAddressResolver addressResolver;
  late FakeDiscoveryService discoveryService;
  late PairingController pairingController;
  late ReceiverController receiverController;

  setUp(() {
    transferServer = FakeTransferServer();
    addressResolver = FakeDeviceAddressResolver();
    discoveryService = FakeDiscoveryService();
    pairingController = PairingController(
      getDeviceIdentityUseCase: GetDeviceIdentityUseCase(
        FakePairingRepository(),
      ),
      validateQrCodeUseCase: const ValidateQrCodeUseCase(JsonQrCodeService()),
      settingsRepository: FakeSettingsRepository(),
    );
    receiverController = ReceiverController(
      transferServer: transferServer,
      deviceAddressResolver: addressResolver,
      pairingController: pairingController,
      startAdvertisingUseCase: StartAdvertisingUseCase(discoveryService),
      stopAdvertisingUseCase: StopAdvertisingUseCase(discoveryService),
    );
  });

  tearDown(() async {
    await receiverController.stopReceiving();
  });

  group('ReceiverController', () {
    test(
      'startReceiving binds server, starts mDNS advertising, and triggers pairing QR generation',
      () async {
        expect(transferServer.isRunning, isFalse);
        expect(discoveryService.isAdvertising, isFalse);
        expect(pairingController.state, const PairingState.initial());

        await receiverController.startReceiving();

        expect(transferServer.isRunning, isTrue);
        expect(transferServer.port, 8888);
        expect(discoveryService.isAdvertising, isTrue);
        expect(discoveryService.advertisedDeviceId, 'rec-dev');
        expect(discoveryService.advertisedDeviceName, 'Receiver Mac');
        expect(discoveryService.advertisedPort, 8888);

        expect(pairingController.state, isA<PairingStateShowingQr>());
        final showingState = pairingController.state as PairingStateShowingQr;
        expect(showingState.payload.host, '192.168.1.42');
        expect(showingState.payload.port, 8888);
        expect(showingState.payload.deviceName, 'Receiver Mac');
        expect(showingState.payload.token, 'secret-tok');
      },
    );

    test('tracks transfer offer, bytes progress, and completion', () async {
      await receiverController.startReceiving();

      expect(receiverController.currentOffer, isNull);
      expect(receiverController.currentReceivedBytes, 0);
      expect(receiverController.receivedFiles, isEmpty);

      // 1. Peer sends offer
      const offer = TransferOffer(
        id: 'xfer-1',
        name: 'photo.jpg',
        sizeInBytes: 1000,
        meta: {},
      );
      transferServer.emitEvent(TransferServerOfferReceived(offer: offer));
      await Future<void>.delayed(Duration.zero);

      expect(receiverController.currentOffer, equals(offer));
      expect(receiverController.currentReceivedBytes, 0);

      // 2. Peer streams chunks
      transferServer.emitEvent(
        TransferServerBytesReceived(
          transferId: 'xfer-1',
          bytes: Uint8List(400),
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(receiverController.currentReceivedBytes, 400);

      transferServer.emitEvent(
        TransferServerBytesReceived(
          transferId: 'xfer-1',
          bytes: Uint8List(600),
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(receiverController.currentReceivedBytes, 1000);

      // 3. Transfer finishes
      const receivedFile = SelectedFile(
        name: 'photo.jpg',
        path: '/Downloads/photo.jpg',
        sizeInBytes: 1000,
      );
      transferServer.emitEvent(
        TransferServerDone(transferId: 'xfer-1', file: receivedFile),
      );
      await Future<void>.delayed(Duration.zero);

      expect(receiverController.currentOffer, isNull);
      expect(receiverController.currentReceivedBytes, 0);
      expect(receiverController.receivedFiles, hasLength(1));
      expect(receiverController.receivedFiles.first.name, 'photo.jpg');
    });

    test(
      'stopReceiving stops server, stops mDNS advertising, and resets state',
      () async {
        await receiverController.startReceiving();
        expect(transferServer.isRunning, isTrue);
        expect(discoveryService.isAdvertising, isTrue);

        await receiverController.stopReceiving();
        expect(transferServer.isRunning, isFalse);
        expect(discoveryService.isAdvertising, isFalse);
        expect(pairingController.state, const PairingState.initial());
        expect(receiverController.currentOffer, isNull);
      },
    );
  });
}
