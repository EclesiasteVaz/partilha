import 'package:flutter/material.dart';
import 'package:partilha/core/errors/failure.dart';
import 'package:partilha/core/theme/theme.dart';
import 'package:partilha/features/file_transfer/domain/domain.dart';
import 'package:partilha/features/file_transfer/presentation/transfer_controller.dart';

/// Confirms the destination and collects the files to send.
///
/// Step two of the send flow: discovery chose the device, this screen shows
/// which one it is and what will be sent. Sending itself is not implemented —
/// the action is present and disabled rather than hidden, so the screen does
/// not pretend the flow is finished (`features/file_transfer/FEATURE.md` §3).
class TransferScreen extends StatelessWidget {
  const TransferScreen({required this.controller, super.key});

  final TransferController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (BuildContext context, _) {
        final TransferState state = controller.state;

        return Scaffold(
          appBar: AppBar(title: const Text('Send files')),
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: AppSpacing.maxContentWidth,
                ),
                child: _Body(controller: controller, state: state),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.controller, required this.state});

  final TransferController controller;
  final TransferState state;

  @override
  Widget build(BuildContext context) {
    final TransferDestination? destination = state.destination;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.pageHorizontal(MediaQuery.sizeOf(context).width),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Destination', style: context.textStyles.titleMedium),
          const SizedBox(height: AppSpacing.xs),
          if (destination != null)
            _DestinationCard(destination: destination)
          else
            Text(
              // Reaching this screen without a destination is not possible
              // through navigation, so say what to do instead of rendering an
              // empty box (§83).
              'No device selected. Go back and choose one.',
              style: context.textStyles.bodySmall,
            ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: <Widget>[
              Expanded(
                child: Text('Files', style: context.textStyles.titleMedium),
              ),
              Text(
                _formatTotal(controller.totalBytes),
                style: context.textStyles.bodySmall,
                // Announced as part of the row rather than read as a stray
                // number, so a screen reader says what it totals (§50).
                semanticsLabel: controller.totalBytes == null
                    ? 'Total size unknown'
                    : '${controller.totalBytes} bytes selected',
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          if (state.error != null) ...<Widget>[
            _ErrorBanner(error: state.error!),
            const SizedBox(height: AppSpacing.xs),
          ],
          Expanded(
            child: state.files.isEmpty
                ? _EmptySelection(
                    isOpen: state.status == TransferStatus.selectingFiles,
                  )
                : _FileList(
                    files: state.files,
                    onRemove: controller.removeFile,
                  ),
          ),
          const SizedBox(height: AppSpacing.sm),
          FilledButton.icon(
            onPressed: controller.pickFiles,
            icon: const AppIcon(AppIcons.add, size: AppIconSizes.md),
            label: Text(
              state.files.isEmpty ? 'Choose files' : 'Add more files',
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          // Disabled rather than absent: the flow visibly ends here instead of
          // quietly doing nothing when tapped.
          FilledButton.icon(
            onPressed: null,
            icon: const AppIcon(AppIcons.send, size: AppIconSizes.md),
            label: const Text('Send'),
          ),
          const SizedBox(height: AppSpacing.xs),
          SizedBox(
            width: double.infinity,
            child: Text(
              'Transferring is not available yet.',
              style: context.textStyles.bodySmall,
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ),
    );
  }
}

class _DestinationCard extends StatelessWidget {
  const _DestinationCard({required this.destination});

  final TransferDestination destination;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const AppIcon(AppIcons.device, size: AppIconSizes.md),
        title: Text(destination.deviceName),
        // Untrusted, and kept off the primary line so it cannot be mistaken for
        // an identity (features/discovery/FEATURE.md §26).
        subtitle: Text(
          '${destination.address}:${destination.port}',
          style: context.textStyles.bodySmall,
        ),
      ),
    );
  }
}

class _FileList extends StatelessWidget {
  const _FileList({required this.files, required this.onRemove});

  final List<SelectedFile> files;
  final void Function(SelectedFile file) onRemove;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      itemCount: files.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.xs),
      itemBuilder: (BuildContext context, int index) {
        final SelectedFile file = files[index];
        return Card(
          child: ListTile(
            leading: const AppIcon(AppIcons.file, size: AppIconSizes.md),
            title: Text(file.name),
            subtitle: Text(
              // '?' rather than 0 B: a missing size is not an empty file, and
              // printing 0 would understate it (§83).
              _formatBytes(file.sizeInBytes),
              style: context.textStyles.bodySmall,
            ),
            trailing: IconButton(
              onPressed: () => onRemove(file),
              icon: const AppIcon(AppIcons.remove, size: AppIconSizes.md),
              // The trailing icon alone does not tell a screen reader which file
              // it removes (§50).
              tooltip: 'Remove ${file.name}',
            ),
          ),
        );
      },
    );
  }
}

class _EmptySelection extends StatelessWidget {
  const _EmptySelection({required this.isOpen});

  final bool isOpen;

  @override
  Widget build(BuildContext context) {
    if (isOpen) {
      return const Center(child: CircularProgressIndicator());
    }
    return Center(
      child: Text(
        'No files selected yet.',
        style: context.textStyles.bodySmall,
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.error});

  final Failure error;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.xs),
        decoration: BoxDecoration(
          color: context.colors.danger,
          borderRadius: BorderRadius.circular(AppSpacing.xxs),
        ),
        // `userMessage` only: the cause may hold a path or an address
        // (AGENTS.md §52, §83).
        child: Text(
          error.userMessage,
          style: context.textStyles.bodySmall.copyWith(
            color: context.colors.onDanger,
          ),
        ),
      ),
    );
  }
}

/// Formats a byte count for display only.
///
/// Private to this screen because nothing else formats sizes yet; promoting it
/// to a shared helper before a second caller exists would be premature
/// (`AGENTS.md` §89).
String _formatBytes(int? bytes) {
  if (bytes == null) return 'Size unknown';
  if (bytes < 1024) return '$bytes B';
  final double kilobytes = bytes / 1024;
  if (kilobytes < 1024) return '${kilobytes.toStringAsFixed(1)} KB';
  final double megabytes = kilobytes / 1024;
  if (megabytes < 1024) return '${megabytes.toStringAsFixed(1)} MB';
  return '${(megabytes / 1024).toStringAsFixed(2)} GB';
}

String _formatTotal(int? bytes) =>
    bytes == null ? 'Total unknown' : _formatBytes(bytes);
