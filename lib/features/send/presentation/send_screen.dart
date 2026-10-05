import 'package:flutter/material.dart';
import 'package:partilha/core/theme/theme.dart';
import 'package:partilha/features/send/presentation/send_controller.dart';

class SendScreen extends StatelessWidget {
  const SendScreen({required this.controller, super.key});

  final SendController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (BuildContext context, _) {
        final state = controller.state;
        final device = state.selectedDevice;

        return Scaffold(
          appBar: AppBar(title: const Text('Send files')),
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: AppSpacing.maxContentWidth,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Destination',
                        style: context.textStyles.titleMedium,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      if (device != null) ...<Widget>[
                        Text(
                          device.deviceName,
                          style: context.textStyles.bodyLarge,
                        ),
                        const SizedBox(height: AppSpacing.xxs),
                        Text(
                          '${device.address}:${device.port}',
                          style: context.textStyles.bodySmall,
                        ),
                      ] else ...<Widget>[
                        Text(
                          'No device selected. Go back and choose one.',
                          style: context.textStyles.bodySmall,
                        ),
                      ],
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        'File selection',
                        style: context.textStyles.titleMedium,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'File picker not yet implemented.',
                        style: context.textStyles.bodySmall,
                      ),
                      const Spacer(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
