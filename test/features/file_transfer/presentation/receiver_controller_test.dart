import 'package:flutter_test/flutter_test.dart';
import 'package:partilha/core/errors/failure.dart';
import 'package:partilha/core/network/local_address_resolver.dart';
import 'package:partilha/core/result/result.dart';
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

  @override
  int? get port => _port;

  @override
  Stream<TransferServerEvent> get events => const Stream.empty();

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

void main() {
  late FakeTransferServer transferServer;
  late FakeDeviceAddressResolver addressResolver;
  late PairingController pairingController;
  late ReceiverController receiverController;

  setUp(() {
    transferServer = FakeTransferServer();
    addressResolver = FakeDeviceAddressResolver();
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
    );
  });

  tearDown(() async {
    await receiverController.stopReceiving();
  });

  group('ReceiverController', () {
    test(
      'startReceiving binds server and triggers pairing QR payload generation',
      () async {
        expect(transferServer.isRunning, isFalse);
        expect(pairingController.state, const PairingState.initial());

        await receiverController.startReceiving();

        expect(transferServer.isRunning, isTrue);
        expect(transferServer.port, 8888);
        expect(pairingController.state, isA<PairingStateShowingQr>());

        final showingState = pairingController.state as PairingStateShowingQr;
        expect(showingState.payload.host, '192.168.1.42');
        expect(showingState.payload.port, 8888);
        expect(showingState.payload.deviceName, 'Receiver Mac');
        expect(showingState.payload.token, 'secret-tok');
      },
    );

    test(
      'stopReceiving stops transfer server and resets pairing state',
      () async {
        await receiverController.startReceiving();
        expect(transferServer.isRunning, isTrue);

        await receiverController.stopReceiving();
        expect(transferServer.isRunning, isFalse);
        expect(pairingController.state, const PairingState.initial());
      },
    );
  });
}
