import 'package:flutter/foundation.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:partilha/features/discovery/domain/discovered_device.dart';
import 'package:partilha/features/send/application/select_device_use_case.dart';
import 'package:partilha/features/send/domain/selected_device.dart';

part 'send_controller.freezed.dart';

enum SendStatus {
  idle,
  selectingDevice,
  deviceSelected,
  selectingFiles,
  readyToSend,
  sending,
  completed,
  error,
  cancelled,
}

@freezed
sealed class SendState with _$SendState {
  const factory SendState({
    @Default(SendStatus.idle) SendStatus status,
    SelectedDevice? selectedDevice,
    String? errorMessage,
  }) = _SendState;
}

class SendController extends ChangeNotifier {
  SendController({required this._selectDevice});

  final SelectDeviceUseCase _selectDevice;

  SendState _state = const SendState();

  SendState get state => _state;

  void selectDevice(DiscoveredDevice device) {
    final selected = _selectDevice(device);
    _emit(
      _state.copyWith(
        status: SendStatus.deviceSelected,
        selectedDevice: selected,
      ),
    );
  }

  void startFileSelection() {
    _emit(_state.copyWith(status: SendStatus.selectingFiles));
  }

  void reset() {
    _emit(const SendState());
  }

  void _emit(SendState next) {
    _state = next;
    notifyListeners();
  }
}
