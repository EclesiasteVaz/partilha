import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:partilha/core/errors/failure.dart';
import 'package:partilha/core/protocol/qr_payload.dart';
import 'package:partilha/features/pairing/application/get_device_identity_use_case.dart';
import 'package:partilha/features/pairing/application/validate_qr_code_use_case.dart';
import 'package:partilha/features/pairing/presentation/pairing_state.dart';
import 'package:partilha/features/settings/domain/settings_repository.dart';

/// Presentation controller orchestrating QR generation, scanning, and validation.
///
/// Follows `AGENTS.md` §10 (ChangeNotifier + Immutable Freezed State).
class PairingController extends ChangeNotifier {
  PairingController({
    required this.getDeviceIdentityUseCase,
    required this.validateQrCodeUseCase,
    required this.settingsRepository,
  });

  final GetDeviceIdentityUseCase getDeviceIdentityUseCase;
  final ValidateQrCodeUseCase validateQrCodeUseCase;
  final SettingsRepository settingsRepository;

  PairingState _state = const PairingState.initial();

  PairingState get state => _state;

  /// Starts the flow where this device shows a QR code for a peer to scan.
  Future<void> generateQr({required String host, required int port}) async {
    _state = const PairingState.generatingQr();
    notifyListeners();

    final identityRes = await getDeviceIdentityUseCase();
    if (identityRes.isFailure) {
      _state = PairingState.failed(failure: identityRes.errorOrNull!);
      notifyListeners();
      return;
    }

    final nameRes = await settingsRepository.readDeviceName();
    final deviceName = nameRes.valueOrNull?.value ?? 'Partilha Device';
    final identity = identityRes.valueOrNull!;

    final payload = QrPayload(
      v: 1,
      deviceId: identity.deviceId,
      deviceName: deviceName,
      host: host,
      port: port,
      token: identity.token,
    );

    final raw = validateQrCodeUseCase.encode(payload);
    _state = PairingState.showingQr(payload: payload, rawQrString: raw);
    notifyListeners();
  }

  /// Sets state to active scanning.
  void startScanning() {
    _state = const PairingState.scanning();
    notifyListeners();
  }

  /// Processes raw QR content captured from camera.
  Future<void> onQrScanned(String rawQrContent) async {
    _state = const PairingState.validating();
    notifyListeners();

    final result = validateQrCodeUseCase(rawQrContent);
    if (result.isSuccess) {
      _state = PairingState.paired(context: result.valueOrNull!);
    } else {
      _state = PairingState.failed(
        failure: result.errorOrNull ?? PairingFailure.invalidPayload,
      );
    }
    notifyListeners();
  }

  /// Resets pairing back to initial state.
  void reset() {
    _state = const PairingState.initial();
    notifyListeners();
  }
}
