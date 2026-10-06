import 'dart:async';
import 'package:flutter/material.dart';
import 'package:partilha/core/di/di.dart';
import 'package:partilha/core/errors/failure.dart';
import 'package:partilha/core/routing/routing.dart';
import 'package:partilha/core/theme/theme.dart';
import 'package:partilha/features/discovery/domain/domain.dart';
import 'package:partilha/features/discovery/presentation/discovery_controller.dart';
import 'package:partilha/features/file_transfer/domain/domain.dart';
import 'package:partilha/features/file_transfer/presentation/presentation.dart';

/// Finds nearby Partilha receivers.
///
/// This is the first step of sending files (§5): the user searches for
/// receivers, sees which ones are available, and selects one. No file
/// selection happens here. The search is single-shot on demand (manual refresh),
/// and that limitation is the deliberate trade-off described in
/// `features/discovery/FEATURE.md` §34.2.
class DiscoveryScreen extends StatefulWidget {
  const DiscoveryScreen({required this.controller, super.key});

  final DiscoveryController controller;

  @override
  State<DiscoveryScreen> createState() => _DiscoveryScreenState();
}

class _DiscoveryScreenState extends State<DiscoveryScreen> {
  @override
  void initState() {
    super.initState();
    // Search when the screen appears. A build-time search would run on every
    // rebuild, so defer to the first frame (§80).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(widget.controller.search());
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (BuildContext context, _) {
        final DiscoveryState state = widget.controller.state;

        return Scaffold(
          appBar: AppBar(title: const Text('Find devices nearby')),
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: AppSpacing.maxContentWidth,
                ),
                child: _Body(state: state, controller: widget.controller),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.state, required this.controller});

  final DiscoveryState state;
  final DiscoveryController controller;

  @override
  Widget build(BuildContext context) {
    return switch (state.status) {
      DiscoveryStatus.initial ||
      DiscoveryStatus.discovering => const _Scanning(),
      DiscoveryStatus.empty => _Empty(onScan: controller.search),
      DiscoveryStatus.error => _Error(
        error: state.error,
        onRetry: controller.search,
      ),
      DiscoveryStatus.stopped => _Stopped(onScan: controller.search),
      DiscoveryStatus.devicesFound => _DeviceList(
        devices: state.devices,
        onRefresh: controller.search,
        onDeviceSelected: (DiscoveredDevice device) {
          // Projected here, at the boundary, rather than handing the discovery
          // entity over: transfer must not depend on untrusted advertised
          // capabilities (`features/discovery/FEATURE.md` §26).
          injectionContainer.resolve<TransferController>().setDestination(
            TransferDestination(
              deviceId: device.deviceId,
              deviceName: device.deviceName,
              address: device.address,
              port: device.port,
            ),
          );
          pushRoute(context, AppRoute.transfer);
        },
      ),
    };
  }
}

class _Scanning extends StatelessWidget {
  const _Scanning();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          const CircularProgressIndicator(),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Looking for nearby devices',
            style: context.textStyles.titleMedium,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Make sure the receiver is ready.',
            style: context.textStyles.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.onScan});

  final Future<void> Function() onScan;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          const AppIcon(AppIcons.device, size: AppIconSizes.xl),
          const SizedBox(height: AppSpacing.md),
          Text('No devices found', style: context.textStyles.titleMedium),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Try again once the receiver has started advertising.',
            style: context.textStyles.bodySmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.md),
          FilledButton.icon(
            onPressed: onScan,
            icon: const AppIcon(AppIcons.retry, size: AppIconSizes.sm),
            label: const Text('Search again'),
          ),
        ],
      ),
    );
  }
}

class _Error extends StatelessWidget {
  const _Error({required this.error, required this.onRetry});

  final Failure? error;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final String message = error?.userMessage ?? 'Discovery failed.';
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          const AppIcon(AppIcons.error, size: AppIconSizes.xl),
          const SizedBox(height: AppSpacing.md),
          Text('Could not find devices', style: context.textStyles.titleMedium),
          const SizedBox(height: AppSpacing.xs),
          Text(
            message,
            style: context.textStyles.bodySmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.md),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const AppIcon(AppIcons.retry, size: AppIconSizes.sm),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

class _Stopped extends StatelessWidget {
  const _Stopped({required this.onScan});

  final Future<void> Function() onScan;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          const AppIcon(AppIcons.device, size: AppIconSizes.xl),
          const SizedBox(height: AppSpacing.md),
          Text('Search stopped', style: context.textStyles.titleMedium),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Start another search when you are ready.',
            style: context.textStyles.bodySmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.md),
          FilledButton.icon(
            onPressed: onScan,
            icon: const AppIcon(AppIcons.retry, size: AppIconSizes.sm),
            label: const Text('Search again'),
          ),
        ],
      ),
    );
  }
}

class _DeviceList extends StatelessWidget {
  const _DeviceList({
    required this.devices,
    required this.onRefresh,
    this.onDeviceSelected,
  });

  final List<DiscoveredDevice> devices;
  final Future<void> Function() onRefresh;
  final void Function(DiscoveredDevice device)? onDeviceSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  'Devices found',
                  style: context.textStyles.titleMedium,
                ),
              ),
              IconButton(
                onPressed: onRefresh,
                icon: const AppIcon(AppIcons.retry, size: AppIconSizes.md),
                tooltip: 'Refresh',
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            itemCount: devices.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (BuildContext context, int index) {
              final DiscoveredDevice device = devices[index];
              return Card(
                child: ListTile(
                  leading: const AppIcon(
                    AppIcons.device,
                    size: AppIconSizes.md,
                  ),
                  title: Text(device.deviceName),
                  // The address is untrusted (§26) but useful for debugging in
                  // a local network. Do not put it on a primary line where a user
                  // could mistake it for an identity.
                  subtitle: Text(
                    '${device.address}:${device.port}',
                    style: context.textStyles.bodySmall,
                  ),
                  // Tapping a row selects the destination and moves on. The
                  // into the transfer feature. The row is tappable in appearance
                  // only for now to keep the list usable on desktop.
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    onDeviceSelected?.call(device);
                  },
                ),
              );
            },
          ),
        ),
        const SizedBox(height: AppSpacing.md),
      ],
    );
  }
}
