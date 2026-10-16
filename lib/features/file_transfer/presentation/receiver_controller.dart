import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:partilha/core/errors/failure.dart';
import 'package:partilha/core/network/network.dart';
import 'package:partilha/core/platform/platform.dart';
import 'package:partilha/features/discovery/application/application.dart';
import 'package:partilha/features/file_transfer/domain/domain.dart';
import 'package:partilha/features/pairing/presentation/pairing_controller.dart';
import 'package:partilha/features/pairing/presentation/pairing_state.dart';

/// Presentation controller coordinating the receiving role.
///
/// Follows `AGENTS.md` §10 (ChangeNotifier) and Clean Architecture:
/// Starts [TransferServer], resolves local IPv4 via [DeviceAddressResolver],
/// instructs [PairingController] to generate the QR payload, announces the
/// device over mDNS via [StartAdvertisingUseCase], and monitors incoming
/// transfer events.
class ReceiverController extends ChangeNotifier {
  ReceiverController({
    required this.transferServer,
    required this.deviceAddressResolver,
    required this.pairingController,
    this.startAdvertisingUseCase,
    this.stopAdvertisingUseCase,
    this.receivedFileService,
  });

  final TransferServer transferServer;
  final DeviceAddressResolver deviceAddressResolver;
  final PairingController pairingController;
  final StartAdvertisingUseCase? startAdvertisingUseCase;
  final StopAdvertisingUseCase? stopAdvertisingUseCase;
  final ReceivedFileService? receivedFileService;

  StreamSubscription<TransferServerEvent>? _serverEventsSubscription;
  bool _isStarting = false;

  bool get isStarting => _isStarting;

  TransferOffer? _currentOffer;
  TransferOffer? get currentOffer => _currentOffer;

  int _currentReceivedBytes = 0;
  int get currentReceivedBytes => _currentReceivedBytes;

  List<SelectedFile> _receivedFiles = const <SelectedFile>[];
  List<SelectedFile> get receivedFiles => _receivedFiles;

  Failure? _lastError;
  Failure? get lastError => _lastError;

  /// Starts the receiving server, generates the QR code payload, and announces
  /// the service via mDNS.
  Future<void> startReceiving() async {
    _isStarting = true;
    _currentOffer = null;
    _currentReceivedBytes = 0;
    _lastError = null;
    notifyListeners();

    // 1. Start transfer server on ephemeral port (port 0)
    final startRes = await transferServer.start(port: 0);
    if (startRes.isFailure) {
      _isStarting = false;
      _lastError = startRes.errorOrNull;
      pairingController.reset();
      notifyListeners();
      return;
    }

    final port = transferServer.port;
    if (port == null) {
      _isStarting = false;
      await transferServer.stop();
      pairingController.reset();
      notifyListeners();
      return;
    }

    // 2. Resolve local IPv4 address
    final ipRes = await deviceAddressResolver.getLocalIpv4Address();
    if (ipRes.isFailure) {
      _isStarting = false;
      _lastError = ipRes.errorOrNull;
      await transferServer.stop();
      pairingController.reset();
      notifyListeners();
      return;
    }

    final host = ipRes.valueOrNull!;

    // 3. Generate QR with PairingController
    await pairingController.generateQr(host: host, port: port);
    if (pairingController.state case PairingStateFailed(:final failure)) {
      _isStarting = false;
      _lastError = failure;
      await transferServer.stop();
      notifyListeners();
      return;
    }

    // 4. Start mDNS advertisement if use case is available
    final pairingState = pairingController.state;
    if (startAdvertisingUseCase != null &&
        pairingState is PairingStateShowingQr) {
      final payload = pairingState.payload;
      try {
        await startAdvertisingUseCase!.call(
          deviceId: payload.deviceId,
          deviceName: payload.deviceName,
          port: port,
          capabilities: const <String, String>{'file-transfer': '1'},
        );
      } on Object catch (_) {
        // mDNS advertising failure is non-fatal: QR carries direct IP/port.
      }
    }

    // 5. Listen to server events
    _serverEventsSubscription?.cancel();
    _serverEventsSubscription = transferServer.events.listen((event) {
      switch (event) {
        case TransferServerOfferReceived(:final offer):
          _currentOffer = offer;
          _currentReceivedBytes = 0;
          notifyListeners();
        case TransferServerBytesReceived(:final transferId, :final bytes):
          if (_currentOffer?.id == transferId) {
            _currentReceivedBytes += bytes.length;
            notifyListeners();
          }
        case TransferServerDone(:final transferId, :final file):
          _receivedFiles = <SelectedFile>[..._receivedFiles, file];
          if (_currentOffer?.id == transferId) {
            _currentOffer = null;
            _currentReceivedBytes = 0;
          }
          notifyListeners();
        case TransferServerError(:final failure):
          _lastError = failure;
          _currentOffer = null;
          _currentReceivedBytes = 0;
          notifyListeners();
        case TransferServerListening():
          break;
      }
    });

    _isStarting = false;
    notifyListeners();
  }

  /// Stops the server, cancels mDNS advertisement, and cleans up active sessions.
  Future<void> stopReceiving() async {
    await _serverEventsSubscription?.cancel();
    _serverEventsSubscription = null;
    if (stopAdvertisingUseCase != null) {
      await stopAdvertisingUseCase!.call();
    }
    await transferServer.stop();
    pairingController.reset();
    _currentOffer = null;
    _currentReceivedBytes = 0;
    notifyListeners();
  }

  /// Opens a received [file] using the platform's default viewer or explorer.
  Future<bool> openReceivedFile(SelectedFile file) async {
    final service = receivedFileService;
    if (service == null) {
      return false;
    }
    return service.openReceivedFile(file.path);
  }

  @override
  void dispose() {
    unawaited(_serverEventsSubscription?.cancel());
    if (stopAdvertisingUseCase != null) {
      unawaited(stopAdvertisingUseCase!.call());
    }
    unawaited(transferServer.stop());
    super.dispose();
  }
}
