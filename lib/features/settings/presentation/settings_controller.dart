import 'package:flutter/foundation.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:partilha/core/errors/failure.dart';
import 'package:partilha/core/result/result.dart';
import 'package:partilha/features/settings/application/application.dart';
import 'package:partilha/features/settings/domain/domain.dart';

part 'settings_controller.freezed.dart';

/// Where the device name comes from before the user has typed anything.
///
/// A separate state from [SettingsStatus.ready] because "showing the stored
/// name" and "showing what the user is typing" are different things: merging them
/// would make the screen either overwrite the stored value on every keystroke or
/// throw away what was typed on every reload.
@freezed
sealed class SettingsState with _$SettingsState {
  const factory SettingsState({
    /// The persisted name, once it is known.
    DeviceName? persistedName,

    /// What the text field currently holds. Null until the persisted name arrives.
    String? draftName,

    @Default(SettingsStatus.initial) SettingsStatus status,

    /// The failure to show, if any.
    ///
    /// Held as a [Failure] rather than a formatted string so the screen can
    /// decide how to present it and tests can assert on the type, while the user
    /// still only ever sees `userMessage` (§83).
    Failure? error,
  }) = _SettingsState;

  const SettingsState._();
}

/// The stage of the device name flow.
enum SettingsStatus {
  /// Nothing has happened yet.
  initial,

  /// Reading the stored name.
  loading,

  /// The stored name is available and the field is editable.
  ready,

  /// A write is in flight.
  saving,

  /// The name was written.
  saved,
}

/// Coordinates the device name screen.
///
/// A `ChangeNotifier` with immutable state, per the project's state strategy
/// (`AGENTS.md` §10). The UI binds with `ListenableBuilder` and the controller is
/// resolved from the container, so nothing here imports a routing or DI package
/// the screen already owns.
class SettingsController extends ChangeNotifier {
  SettingsController({
    required this.getDeviceName,
    required this.saveDeviceName,
  });

  /// Public only because a named initializing formal cannot assign a private
  /// field. Neither is intended to be called from outside; the controller owns
  /// when they run.
  final GetDeviceNameUseCase getDeviceName;
  final SaveDeviceNameUseCase saveDeviceName;

  SettingsState _state = const SettingsState();

  SettingsState get state => _state;

  /// Whether the save control should be enabled.
  ///
  /// False while a write is in flight, so a second tap cannot start a second
  /// write; and false when the draft cannot produce a valid name, which keeps an
  /// obviously invalid value from being submitted only to be rejected (§83).
  bool get canSave =>
      _state.status != SettingsStatus.saving && _state.draftName != null;

  /// Loads the stored name.
  ///
  /// Not called from the constructor: it runs async, and a screen that had to
  /// await its own construction could not report a failure through its state.
  Future<void> load() async {
    _emit(_state.copyWith(status: SettingsStatus.loading, error: null));

    final Result<DeviceName, Failure> result = await getDeviceName();
    switch (result) {
      case Success(:final value):
        _emit(
          _state.copyWith(
            status: SettingsStatus.ready,
            persistedName: value,
            // The field starts from the stored value. Not overwriting an
            // in-progress edit matters more than avoiding a redundant request,
            // and there is no in-progress edit on first load.
            draftName: _state.draftName ?? value.value,
          ),
        );
      case Err(:final error):
        // A read failure leaves the field usable rather than empty: the user can
        // still type a name and try to save it, which is the one thing that might
        // recover. Showing a dead form would leave nothing to do (§83).
        _emit(
          _state.copyWith(
            status: SettingsStatus.ready,
            draftName: _state.draftName ?? DeviceName.fallback.value,
            error: error,
          ),
        );
    }
  }

  /// Records what the user has typed.
  ///
  /// Does not validate. Validation belongs to the use case, and duplicating it
  /// here would mean two places to change when the rule changes.
  void onDraftChanged(String draft) {
    _emit(
      _state.copyWith(
        draftName: draft,
        // Any new typing invalidates a previous outcome, otherwise a success
        // message would sit under text the user has already changed.
        status: _state.status == SettingsStatus.saved
            ? SettingsStatus.ready
            : _state.status,
        error: null,
      ),
    );
  }

  /// Validates and saves the current draft.
  Future<void> save() async {
    final String? draft = _state.draftName;
    if (draft == null) return;

    _emit(_state.copyWith(status: SettingsStatus.saving, error: null));

    final Result<void, Failure> result = await saveDeviceName(draft);
    switch (result) {
      case Success():
        await _adoptStoredName();
      case Err(:final error):
        _emit(_state.copyWith(status: SettingsStatus.ready, error: error));
    }
  }

  /// Re-reads the stored name and reports the write as saved.
  ///
  /// Deliberately not a call to [load]: that would end in
  /// [SettingsStatus.ready] and the user would never see confirmation that their
  /// save worked. Reading back is still necessary because the stored value is
  /// trimmed, so echoing the draft could show a name that is not what was saved.
  Future<void> _adoptStoredName() async {
    final Result<DeviceName, Failure> stored = await getDeviceName();

    switch (stored) {
      case Success(:final value):
        _emit(
          _state.copyWith(
            status: SettingsStatus.saved,
            persistedName: value,
            draftName: value.value,
          ),
        );
      case Err(:final error):
        // The write succeeded even though the confirmation read did not. Reporting
        // a failure here would tell the user their name was not saved when it
        // was, which is worse than a missing confirmation.
        _emit(_state.copyWith(status: SettingsStatus.saved, error: error));
    }
  }

  void _emit(SettingsState next) {
    if (next == _state) return;
    _state = next;
    notifyListeners();
  }
}
