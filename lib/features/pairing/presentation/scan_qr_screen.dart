import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:partilha/core/theme/theme.dart';
import 'package:partilha/features/pairing/presentation/pairing_controller.dart';
import 'package:partilha/features/pairing/presentation/pairing_state.dart';

/// Screen displayed by the sender scanning the peer's pairing QR code.
///
/// Follows `features/pairing/FEATURE.md` §15 (releases camera on dispose/leave).
class ScanQrScreen extends StatefulWidget {
  const ScanQrScreen({super.key, required this.controller, this.onPaired});

  final PairingController controller;
  final VoidCallback? onPaired;

  @override
  State<ScanQrScreen> createState() => _ScanQrScreenState();
}

class _ScanQrScreenState extends State<ScanQrScreen> {
  late final MobileScannerController _scannerController;
  bool _hasScanned = false;

  @override
  void initState() {
    super.initState();
    _scannerController = MobileScannerController();
    widget.controller.startScanning();
    widget.controller.addListener(_onControllerChanged);
  }

  void _onControllerChanged() {
    if (widget.controller.state is PairingStatePaired) {
      widget.onPaired?.call();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    unawaited(_scannerController.dispose());
    super.dispose();
  }

  void _handleBarcode(BarcodeCapture capture) {
    if (_hasScanned) return;
    final barcodes = capture.barcodes;
    for (final barcode in barcodes) {
      final rawValue = barcode.rawValue;
      if (rawValue != null && rawValue.isNotEmpty) {
        _hasScanned = true;
        unawaited(widget.controller.onQrScanned(rawValue));
        break;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan QR Code')),
      body: ListenableBuilder(
        listenable: widget.controller,
        builder: (context, _) {
          final state = widget.controller.state;

          if (state is PairingStateValidating) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Validating connection...'),
                ],
              ),
            );
          }

          if (state is PairingStateFailed) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 48,
                      color: context.colors.danger,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Pairing Failed',
                      style: context.textStyles.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      state.failure.userMessage,
                      style: context.textStyles.bodyMedium.copyWith(
                        color: context.colors.onSurfaceMuted,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: () {
                        _hasScanned = false;
                        widget.controller.startScanning();
                      },
                      child: const Text('Scan Again'),
                    ),
                  ],
                ),
              ),
            );
          }

          return Stack(
            children: [
              MobileScanner(
                controller: _scannerController,
                onDetect: _handleBarcode,
              ),
              Center(
                child: Container(
                  width: 250,
                  height: 250,
                  decoration: BoxDecoration(
                    border: Border.all(color: context.colors.primary, width: 3),
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
              Positioned(
                bottom: 40,
                left: 20,
                right: 20,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 20,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Text(
                    'Point the camera at the receiving device’s QR code',
                    style: TextStyle(color: Colors.white, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
