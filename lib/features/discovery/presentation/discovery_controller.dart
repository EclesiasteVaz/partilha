import 'package:flutter/foundation.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:partilha/core/errors/failure.dart';
import 'package:partilha/core/result/result.dart';
import 'package:partilha/features/discovery/application/application.dart';
import 'package:partilha/features/discovery/domain/domain.dart';

part 'discovery_controller.freezed.dart';

/// What the discovery screen is doing.
///
/// The values are those of `features/discovery/FEATURE.md` §8 and no others: a
/// state that carries no distinct behaviour is noise the UI has to switch on
/// (§89). `devicesFound` and `empty` are separate rather than one state with a
/// flag because the two render differently and mean opposite things to the user.
enum DiscoveryStatus {
  /// Nothing has been searched for yet.
  initial,

  /// A search is in flight.
  discovering,

  /// At least one device answered.
  devicesFound,

  /// The search completed and nothing answered.
  empty,

  /// The search failed.
  error,

  /// The search was cancelled before it finished.
  stopped,
}

/// Immutable discovery state.
///
/// Freezed rather than a mutable field set because the screen binds to this and
/// compares whole states; a mutable object would make "did anything change?" a
/// question about identity rather than value (§10).
@freezed
sealed class DiscoveryState with _$DiscoveryState {
  const factory DiscoveryState({
    @Default(DiscoveryStatus.initial) DiscoveryStatus status,

    /// Devices to show, already filtered and deduplicated.
    @Default(<DiscoveredDevice>[]) List<DiscoveredDevice> devices,
    Failure? error,
  }) = _DiscoveryState;
}

/// Drives one search at a time and publishes what it found.
///
/// Owns no timer and no subscription, deliberately: the search is single-shot,
/// so there is nothing long-lived to leak (`AGENTS.md` §81). What it does own
/// is the cancellation of an in-flight result, because a search that finishes
/// after the user left must not repaint a screen that is gone.
class DiscoveryController extends ChangeNotifier {
  DiscoveryController({
    required this._discoverNearbyDevices,
    this._localDeviceName,
  });

  final DiscoverNearbyDevicesUseCase _discoverNearbyDevices;

  /// Resolves this device's own name so its own advertisement can be hidden.
  ///
  /// A function rather than a value because the name lives in Settings and is
  /// read from storage, and this layer must not depend on another feature to
  /// learn the user's device name. Null disables the filter.
  final Future<String> Function()? _localDeviceName;

  DiscoveryState _state = const DiscoveryState();

  /// Incremented per search so a result from a superseded search is discarded.
  int _generation = 0;

  DiscoveryState get state => _state;

  bool get isScanning => _state.status == DiscoveryStatus.discovering;

  /// Searches the local network once.
  ///
  /// [retrying] is not part of the published state on purpose: whether this is a
  /// first attempt or a retry changes nothing for the user, and inventing a
  /// distinction here would be state without behaviour (§89).
  Future<void> search() async {
    final int generation = ++_generation;

    _emit(_state.copyWith(status: DiscoveryStatus.discovering, error: null));

    final Result<List<DiscoveredDevice>, Failure> result =
        await _discoverNearbyDevices();

    // A newer search started, or this one was cancelled, while it was running.
    // Applying the result now would overwrite a decision the user already made.
    if (generation != _generation) return;

    switch (result) {
      case Success(:final value):
        final List<DiscoveredDevice> visible = await _withoutOwnDevice(value);
        if (generation != _generation) return;

        _emit(
          _state.copyWith(
            status: visible.isEmpty
                ? DiscoveryStatus.empty
                : DiscoveryStatus.devicesFound,
            devices: visible,
            error: null,
          ),
        );
      case Err(:final error):
        _emit(_state.copyWith(status: DiscoveryStatus.error, error: error));
    }
  }

  /// Abandons an in-flight search and says so.
  ///
  /// Cancellation is explicit rather than silent because a user who stopped a
  /// search and sees nothing happen cannot tell it apart from a device that is
  /// not there (§83, §84). The abandoned result is discarded by [_generation].
  void stop() {
    _generation++;
    _emit(_state.copyWith(status: DiscoveryStatus.stopped, error: null));
  }

  /// Removes this device's own advertisement from [found].
  ///
  /// Filtered by name, which is weaker than filtering by device id and is called
  /// out in `features/discovery/FEATURE.md` §28: a device is free to claim
  /// someone else's name, and two real devices may share one. It is here because
  /// showing the user their own phone in a list of *other* devices is visibly
  /// wrong, and no local device id exists yet to do it properly.
  Future<List<DiscoveredDevice>> _withoutOwnDevice(
    List<DiscoveredDevice> found,
  ) async {
    final Future<String> Function()? resolveLocal = _localDeviceName;
    if (resolveLocal == null) return _deduplicated(found);

    final String mine = await resolveLocal();
    return _deduplicated(
      found.where((DiscoveredDevice d) => d.deviceName != mine).toList(),
    );
  }

  /// Collapses repeated answers for the same device into one row.
  ///
  /// A provider can report the same device more than once — a unicast reply and
  /// a multicast one, or a retry — and two rows for one device reads as two
  /// devices to send to (§28). Keyed by device id because that is the only
  /// identifier the record carries.
  static List<DiscoveredDevice> _deduplicated(List<DiscoveredDevice> found) {
    final Map<String, DiscoveredDevice> byId = <String, DiscoveredDevice>{};
    for (final DiscoveredDevice device in found) {
      byId.putIfAbsent(device.deviceId, () => device);
    }
    return List<DiscoveredDevice>.unmodifiable(byId.values);
  }

  void _emit(DiscoveryState next) {
    _state = next;
    notifyListeners();
  }

  @override
  void dispose() {
    // Bumping the generation makes any in-flight result a no-op, so a search that
    // outlives the controller cannot notify a disposed listener (§81).
    _generation++;
    super.dispose();
  }
}
