import 'package:flutter_test/flutter_test.dart';
import 'package:partilha/core/errors/failure.dart';
import 'package:partilha/core/result/result.dart';
import 'package:partilha/features/pairing/application/get_device_identity_use_case.dart';
import 'package:partilha/features/pairing/application/validate_qr_code_use_case.dart';
import 'package:partilha/features/pairing/data/json_qr_code_service.dart';
import 'package:partilha/features/pairing/domain/domain.dart';
import 'package:partilha/features/pairing/presentation/pairing_controller.dart';
import 'package:partilha/features/pairing/presentation/pairing_state.dart';
import 'package:partilha/features/settings/domain/domain.dart';

class FakePairingRepository implements PairingRepository {
  DeviceIdentity identity = const DeviceIdentity(
    deviceId: 'fake-id',
    token: 'fake-token',
  );

  @override
  Future<Result<DeviceIdentity, Failure>> getOrCreateIdentity() async {
    return Result.success(identity);
  }
}

class FakeSettingsRepository implements SettingsRepository {
  DeviceName name = DeviceName.create('Test Mac').valueOrNull!;

  @override
  Future<Result<DeviceName, Failure>> readDeviceName() async {
    return Result.success(name);
  }

  @override
  Future<Result<void, Failure>> saveDeviceName(DeviceName newName) async {
    name = newName;
    return const Result.success(null);
  }
}

void main() {
  late FakePairingRepository pairingRepository;
  late FakeSettingsRepository settingsRepository;
  late JsonQrCodeService qrCodeService;
  late PairingController controller;

  setUp(() {
    pairingRepository = FakePairingRepository();
    settingsRepository = FakeSettingsRepository();
    qrCodeService = const JsonQrCodeService();
    controller = PairingController(
      getDeviceIdentityUseCase: GetDeviceIdentityUseCase(pairingRepository),
      validateQrCodeUseCase: ValidateQrCodeUseCase(qrCodeService),
      settingsRepository: settingsRepository,
    );
  });

  group('PairingController', () {
    test('initial state is PairingStateInitial', () {
      expect(controller.state, const PairingState.initial());
    });

    test('generateQr transitions to showingQr with valid payload', () async {
      await controller.generateQr(host: '192.168.1.50', port: 9000);

      expect(controller.state, isA<PairingStateShowingQr>());
      final showing = controller.state as PairingStateShowingQr;
      expect(showing.payload.deviceId, 'fake-id');
      expect(showing.payload.token, 'fake-token');
      expect(showing.payload.deviceName, 'Test Mac');
      expect(showing.payload.host, '192.168.1.50');
      expect(showing.payload.port, 9000);
      expect(showing.rawQrString.contains('fake-token'), isTrue);
    });

    test(
      'onQrScanned transitions to paired when QR payload is valid',
      () async {
        await controller.generateQr(host: '192.168.1.50', port: 9000);
        final rawQr = (controller.state as PairingStateShowingQr).rawQrString;

        await controller.onQrScanned(rawQr);

        expect(controller.state, isA<PairingStatePaired>());
        final paired = controller.state as PairingStatePaired;
        expect(paired.context.peerDeviceId, 'fake-id');
        expect(paired.context.peerDeviceName, 'Test Mac');
        expect(paired.context.token, 'fake-token');
      },
    );

    test(
      'onQrScanned transitions to failed when QR payload is invalid',
      () async {
        await controller.onQrScanned('invalid-payload');

        expect(controller.state, isA<PairingStateFailed>());
        final failed = controller.state as PairingStateFailed;
        expect(failed.failure, isA<PairingFailure>());
      },
    );

    test('reset returns state to initial', () async {
      await controller.onQrScanned('invalid');
      expect(controller.state, isA<PairingStateFailed>());

      controller.reset();
      expect(controller.state, const PairingState.initial());
    });
  });
}
