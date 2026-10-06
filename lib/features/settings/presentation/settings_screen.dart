import 'dart:async';

import 'package:flutter/material.dart';
import 'package:partilha/core/routing/routing.dart';
import 'package:partilha/core/theme/theme.dart';
import 'package:partilha/features/settings/domain/domain.dart';
import 'package:partilha/features/settings/presentation/settings_controller.dart';

/// Where the user sets the name this device is known by.
///
/// The name is the one piece of identity a user controls before any device is
/// nearby, and it is what a peer sees in its device list, so it is the natural
/// first screen: it needs no discovery, no pairing and no network, which means
/// it can be built and verified before the rest of the chain exists.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({required this.controller, super.key});

  final SettingsController controller;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _field;

  @override
  void initState() {
    super.initState();
    _field = TextEditingController();
    // Started after the first frame so a failure to read the stored name
    // arrives through the controller's state and can be rendered, rather than
    // throwing during build (§83).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(widget.controller.load());
    });
  }

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (BuildContext context, _) {
        final SettingsState state = widget.controller.state;
        _syncField(state.draftName);

        return Scaffold(
          appBar: AppBar(title: const Text('Settings')),
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                // Caps the column on a desktop window instead of letting one
                // text field stretch across a 27-inch display, which would be
                // unreadable and is what §49 asks to be considered from the
                // start rather than retrofitted.
                constraints: const BoxConstraints(
                  maxWidth: AppSpacing.maxContentWidth,
                ),
                child: ListView(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  children: <Widget>[
                    _DeviceNameSection(
                      field: _field,
                      controller: widget.controller,
                      state: state,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Pushes [draft] into the field only when it differs from what is shown.
  ///
  /// A text field is the source of truth while the user is typing, so writing to
  /// it on every rebuild would move the caret and drop characters. Assigning only
  /// on a real difference keeps the two in step after a load or a save without
  /// fighting the user mid-edit.
  void _syncField(String? draft) {
    if (draft == null || draft == _field.text) return;
    _field.value = TextEditingValue(
      text: draft,
      selection: TextSelection.collapsed(offset: draft.length),
    );
  }
}

class _DeviceNameSection extends StatelessWidget {
  const _DeviceNameSection({
    required this.field,
    required this.controller,
    required this.state,
  });

  final TextEditingController field;
  final SettingsController controller;
  final SettingsState state;

  @override
  Widget build(BuildContext context) {
    final bool busy = state.status == SettingsStatus.saving;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('Device name', style: context.textStyles.titleMedium),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          'This is the name nearby devices will see for this one.',
          style: context.textStyles.bodySmall,
        ),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          controller: field,
          enabled: !busy,
          maxLength: DeviceName.maxLength,
          // Announced as the field is typed rather than only on save, so the
          // limit is discovered before the user hits the limit (§50).
          textInputAction: TextInputAction.done,
          onChanged: controller.onDraftChanged,
          onSubmitted: busy ? null : (_) => controller.save(),
          decoration: InputDecoration(
            hintText: DeviceName.fallback.value,
            border: const OutlineInputBorder(),
            // The count comes from the field's own maxLength so it cannot drift
            // from the limit the domain enforces.
            helperText: 'Up to ${DeviceName.maxLength} characters',
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        _StatusLine(state: state),
        const SizedBox(height: AppSpacing.md),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton(
            onPressed: busy ? null : controller.save,
            child: busy
                ? const SizedBox.square(
                    dimension: AppSpacing.md,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.tonal(
            // Pushed rather than replacing Settings, so Back returns to the
            // device name the user may have just edited (`AGENTS.md` §49).
            onPressed: () => pushRoute(context, AppRoute.send),
            child: const Text('Send files'),
          ),
        ),
      ],
    );
  }
}

/// Reports the outcome of the last action in text.
///
/// Text rather than colour or an icon alone: a status conveyed only by colour is
/// invisible to a screen reader and to a colour-blind user, and §84 requires
/// states to stay understandable without it. The icon is decoration on top.
class _StatusLine extends StatelessWidget {
  const _StatusLine({required this.state});

  final SettingsState state;

  @override
  Widget build(BuildContext context) {
    final ({String message, IconData icon, bool isError})? status = _status(
      state,
    );

    if (status == null) return const SizedBox.shrink();

    return Semantics(
      // A polite live region: the message appears in response to the user's own
      // action, so it should be announced without interrupting anything.
      liveRegion: true,
      child: Row(
        children: <Widget>[
          AppIcon(status.icon, size: AppIconSizes.sm),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              status.message,
              style: status.isError
                  ? context.textStyles.bodySmall.copyWith(
                      color: context.colors.danger,
                    )
                  : context.textStyles.bodySmall,
            ),
          ),
        ],
      ),
    );
  }

  /// The message to show, or `null` when there is nothing to say.
  ///
  /// Nothing is shown while loading or while typing: a screen that narrates every
  /// keystroke is noise, and the field already shows what was typed.
  static ({String message, IconData icon, bool isError})? _status(
    SettingsState state,
  ) {
    if (state.status == SettingsStatus.loading) return null;

    if (state.error case final error?) {
      return (message: error.userMessage, icon: AppIcons.error, isError: true);
    }

    return switch (state.status) {
      SettingsStatus.saved => (
        message: 'Device name saved.',
        icon: AppIcons.completed,
        isError: false,
      ),
      _ => null,
    };
  }
}
