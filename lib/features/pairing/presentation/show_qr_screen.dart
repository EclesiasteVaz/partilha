import 'dart:async';

import 'package:flutter/material.dart';
import 'package:partilha/core/theme/theme.dart';
import 'package:partilha/features/file_transfer/presentation/receiver_controller.dart';
import 'package:partilha/features/pairing/presentation/pairing_controller.dart';
import 'package:partilha/features/pairing/presentation/pairing_state.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// Screen displayed by the receiver showing the pairing QR code and live
/// reception feedback.
///
/// Follows `features/pairing/FEATURE.md` §27 (semantic label and accessible alternative)
/// and `features/file_transfer/FEATURE.md` §6 (transfer progress, destination storage).
class ShowQrScreen extends StatelessWidget {
  const ShowQrScreen({
    super.key,
    required this.controller,
    this.receiverController,
    this.onDismiss,
  });

  final PairingController controller;
  final ReceiverController? receiverController;
  final VoidCallback? onDismiss;

  Future<bool> _confirmCancel(BuildContext context) async {
    final bool? result = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Cancel receiving?'),
          content: const Text(
            'A file is currently being transferred. Leaving now will cancel the transfer.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Continue receiving'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Cancel transfer'),
            ),
          ],
        );
      },
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final Listenable listenable = receiverController != null
        ? Listenable.merge(<Listenable>[controller, receiverController!])
        : controller;

    return ListenableBuilder(
      listenable: listenable,
      builder: (BuildContext context, _) {
        final bool isReceiving = receiverController?.currentOffer != null;
        final state = controller.state;
        final receiverError = receiverController?.lastError;

        return PopScope(
          canPop: !isReceiving,
          onPopInvokedWithResult: (bool didPop, result) async {
            if (didPop) {
              onDismiss?.call();
              return;
            }
            if (isReceiving) {
              final bool shouldPop = await _confirmCancel(context);
              if (shouldPop && context.mounted) {
                onDismiss?.call();
                Navigator.of(context).pop();
              }
            }
          },
          child: Scaffold(
            appBar: AppBar(
              title: const Text('Receive Files'),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () async {
                  if (isReceiving) {
                    final bool shouldPop = await _confirmCancel(context);
                    if (shouldPop && context.mounted) {
                      onDismiss?.call();
                      Navigator.of(context).pop();
                    }
                  } else {
                    onDismiss?.call();
                    unawaited(Navigator.of(context).maybePop());
                  }
                },
              ),
            ),
            body: Builder(
              builder: (context) {
                if (receiverError != null && state is! PairingStateShowingQr) {
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
                            'Failed to prepare receiver',
                            style: context.textStyles.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            receiverError.userMessage,
                            style: context.textStyles.bodyMedium.copyWith(
                              color: context.colors.onSurfaceMuted,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),
                          FilledButton(
                            onPressed: () {
                              controller.reset();
                              unawaited(receiverController?.startReceiving());
                            },
                            child: const Text('Try Again'),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return switch (state) {
                  PairingStateInitial() || PairingStateGeneratingQr() =>
                    const Center(child: CircularProgressIndicator()),
                  PairingStateShowingQr(:final payload, :final rawQrString) =>
                    Center(
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
                              label:
                                  'Pairing QR Code for ${payload.deviceName}',
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.1,
                                      ),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: QrImageView(
                                  data: rawQrString,
                                  version: QrVersions.auto,
                                  size: 220,
                                  backgroundColor: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
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
                            if (receiverController != null) ...[
                              const SizedBox(height: 24),
                              _ReceiverStatusSection(
                                receiver: receiverController!,
                              ),
                            ],
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
          ),
        );
      },
    );
  }
}

class _ReceiverStatusSection extends StatelessWidget {
  const _ReceiverStatusSection({required this.receiver});

  final ReceiverController receiver;

  @override
  Widget build(BuildContext context) {
    final activeOffer = receiver.currentOffer;
    final receivedFiles = receiver.receivedFiles;
    final lastError = receiver.lastError;

    if (activeOffer == null && receivedFiles.isEmpty && lastError == null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: context.colors.surfaceMuted,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.radio_button_checked,
              size: 16,
              color: Colors.green,
            ),
            const SizedBox(width: 8),
            Text('Ready to receive files', style: context.textStyles.bodySmall),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (lastError != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.colors.danger.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: context.colors.danger),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.error_outline,
                  color: context.colors.danger,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    lastError.userMessage,
                    style: context.textStyles.bodySmall.copyWith(
                      color: context.colors.danger,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (activeOffer != null) ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.downloading, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Receiving ${activeOffer.name}...',
                          style: context.textStyles.titleSmall,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  LinearProgressIndicator(
                    value:
                        activeOffer.sizeInBytes != null &&
                            activeOffer.sizeInBytes! > 0
                        ? (receiver.currentReceivedBytes /
                                  activeOffer.sizeInBytes!)
                              .clamp(0.0, 1.0)
                        : null,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    activeOffer.sizeInBytes != null
                        ? '${_formatBytes(receiver.currentReceivedBytes)} / ${_formatBytes(activeOffer.sizeInBytes)}'
                        : _formatBytes(receiver.currentReceivedBytes),
                    style: context.textStyles.bodySmall.copyWith(
                      color: context.colors.onSurfaceMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (receivedFiles.isNotEmpty) ...[
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Received Files (${receivedFiles.length})',
              style: context.textStyles.titleSmall,
            ),
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Saved to Downloads folder',
              style: context.textStyles.labelMedium.copyWith(
                color: context.colors.onSurfaceMuted,
              ),
            ),
          ),
          const SizedBox(height: 8),
          ...receivedFiles.map(
            (file) => Card(
              margin: const EdgeInsets.only(bottom: 6),
              child: ListTile(
                dense: true,
                onTap: () async {
                  final messenger = ScaffoldMessenger.maybeOf(context);
                  final opened = await receiver.openReceivedFile(file);
                  if (!opened && messenger != null) {
                    messenger.showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Could not open this file on this device.',
                        ),
                      ),
                    );
                  }
                },
                leading: const Icon(
                  Icons.check_circle,
                  color: Colors.green,
                  size: 20,
                ),
                title: Text(
                  file.name,
                  overflow: TextOverflow.ellipsis,
                  style: context.textStyles.bodyMedium,
                ),
                subtitle: Text(
                  file.path.isNotEmpty
                      ? '${_formatBytes(file.sizeInBytes)} • ${file.path}'
                      : _formatBytes(file.sizeInBytes),
                  style: context.textStyles.bodySmall.copyWith(
                    color: context.colors.onSurfaceMuted,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Icon(
                  Icons.open_in_new,
                  size: 18,
                  color: context.colors.onSurfaceMuted,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

String _formatBytes(int? bytes) {
  if (bytes == null) return 'Size unknown';
  if (bytes < 1024) return '$bytes B';
  final double kilobytes = bytes / 1024;
  if (kilobytes < 1024) return '${kilobytes.toStringAsFixed(1)} KB';
  final double megabytes = kilobytes / 1024;
  if (megabytes < 1024) return '${megabytes.toStringAsFixed(1)} MB';
  return '${(megabytes / 1024).toStringAsFixed(2)} GB';
}
