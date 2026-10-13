import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:partilha/core/network/network.dart';
import 'package:partilha/features/file_transfer/domain/domain.dart';
import 'package:partilha/features/pairing/presentation/pairing_controller.dart';

/// Presentation controller coordinating the receiving role.
///
/// Follows `AGENTS.md` §10 (ChangeNotifier) and Clean Architecture:
/// Starts [TransferServer], resolves local IPv4 via [DeviceAddressResolver],
/// and instructs [PairingController] to generate the QR payload.
class ReceiverController extends ChangeNotifier {
  ReceiverController({
    required this.transferServer,
    required this.deviceAddressResolver,
    required this.pairingController,
  });

  final TransferServer transferServer;
  final DeviceAddressResolver deviceAddressResolver;
  final PairingController pairingController;

  StreamSubscription<TransferServerEvent>? _serverEventsSubscription;
  bool _isStarting = false;

  bool get isStarting => _isStarting;

  /// Starts the receiving server and generates the QR code payload.
  Future<void> startReceiving() async {
    _isStarting = true;
    notifyListeners();

    // 1. Start transfer server on ephemeral port (port 0)
    final startRes = await transferServer.start(port: 0);
    if (startRes.isFailure) {
      _isStarting = false;
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
      await transferServer.stop();
      pairingController.reset();
      notifyListeners();
      return;
    }

    final host = ipRes.valueOrNull!;

    // 3. Generate QR with PairingController
    await pairingController.generateQr(host: host, port: port);

    // 4. Listen to server events
    _serverEventsSubscription?.cancel();
    _serverEventsSubscription = transferServer.events.listen((event) {
      if (event is TransferServerDone) {
        // Transfer received successfully
        notifyListeners();
      }
    });

    _isStarting = false;
    notifyListeners();
  }

  /// Stops the server and cancels the active session.
  Future<void> stopReceiving() async {
    await _serverEventsSubscription?.cancel();
    _serverEventsSubscription = null;
    await transferServer.stop();
    pairingController.reset();
    notifyListeners();
  }

  @override
  void dispose() {
    unawaited(_serverEventsSubscription?.cancel());
    unawaited(transferServer.stop());
    super.dispose();
  }
}
