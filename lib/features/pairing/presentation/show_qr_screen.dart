import 'package:flutter/material.dart';
import 'package:partilha/core/theme/theme.dart';
import 'package:partilha/features/pairing/presentation/pairing_controller.dart';
import 'package:partilha/features/pairing/presentation/pairing_state.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// Screen displayed by the receiver showing the pairing QR code.
///
/// Follows `features/pairing/FEATURE.md` §27 (semantic label and accessible alternative).
class ShowQrScreen extends StatelessWidget {
  const ShowQrScreen({super.key, required this.controller});

  final PairingController controller;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pair Device')),
      body: ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          final state = controller.state;

          return switch (state) {
            PairingStateInitial() || PairingStateGeneratingQr() => const Center(
              child: CircularProgressIndicator(),
            ),
            PairingStateShowingQr(:final payload, :final rawQrString) => Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Scan to Connect',
                      style: context.textStyles.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Show this QR code to the sending device.',
                      style: context.textStyles.bodyMedium.copyWith(
                        color: context.colors.onSurfaceMuted,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    Semantics(
                      label: 'Pairing QR Code for ${payload.deviceName}',
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: QrImageView(
                          data: rawQrString,
                          version: QrVersions.auto,
                          size: 240,
                          backgroundColor: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      payload.deviceName,
                      style: context.textStyles.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${payload.host}:${payload.port}',
                      style: context.textStyles.labelMedium.copyWith(
                        color: context.colors.onSurfaceMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            PairingStateFailed(:final failure) => Center(
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
                      'Failed to generate pairing QR',
                      style: context.textStyles.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      failure.userMessage,
                      style: context.textStyles.bodyMedium.copyWith(
                        color: context.colors.onSurfaceMuted,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: controller.reset,
                      child: const Text('Try Again'),
                    ),
                  ],
                ),
              ),
            ),
            _ => const SizedBox.shrink(),
          };
        },
      ),
    );
  }
}
