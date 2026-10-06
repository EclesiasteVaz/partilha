import 'package:flutter/foundation.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:partilha/core/errors/failure.dart';
import 'package:partilha/core/result/result.dart';
import 'package:partilha/features/file_transfer/application/application.dart';
import 'package:partilha/features/file_transfer/domain/domain.dart';

part 'transfer_controller.freezed.dart';

/// What the transfer setup screen is doing.
///
/// Only the states that exist today: the destination, the selection, and the
/// two ways picking can end. `sending`, `completed` and `cancelled` are absent
/// because no transfer runs yet, and declaring them would be state without
/// behaviour (`AGENTS.md` §89). `features/file_transfer/FEATURE.md` §8 lists the
/// full set the finished feature needs.
enum TransferStatus {
  /// Nothing chosen yet.
  initial,

  /// The picker is open.
  selectingFiles,

  /// A destination and at least one file are set.
  ready,

  /// The picker could not be opened.
  error,
}

/// Immutable transfer state.
///
/// Freezed because the screen binds to this and compares whole states; a mutable
/// field set would make "did anything change?" a question about identity rather
/// than value (`AGENTS.md` §10).
@freezed
sealed class TransferState with _$TransferState {
  const factory TransferState({
    @Default(TransferStatus.initial) TransferStatus status,
    TransferDestination? destination,
    @Default(<SelectedFile>[]) List<SelectedFile> files,
    Failure? error,
  }) = _TransferState;
}

/// Holds the destination and the files the user chose.
///
/// Owns no file handle and no socket: it is the presentation state for one
/// attempt, and the queue that will eventually consume it does not exist yet
/// (`features/file_transfer/FEATURE.md` §3). Presenting a picker is the only
/// asynchronous work, and a picker cannot be cancelled programmatically, so
/// there is no in-flight request to invalidate on dispose — the opposite of the
/// discovery controller, which has a stream result that can arrive late
/// (`AGENTS.md` §81).
class TransferController extends ChangeNotifier {
  TransferController({required this._selectFiles});

  final SelectFilesUseCase _selectFiles;

  TransferState _state = const TransferState();

  TransferState get state => _state;

  /// Total bytes selected, or `null` when any selected file has no known size.
  ///
  /// `null` rather than a partial sum on purpose: adding up the files that happen
  /// to know their size produces a total that looks authoritative and is wrong,
  /// and progress built on it would overstate the denominator
  /// (`AGENTS.md` §20).
  ///
  /// Computed on demand rather than cached in the state: a cached total is a
  /// second source of truth that goes stale the moment a file is removed
  /// (`AGENTS.md` §79).
  int? get totalBytes {
    int sum = 0;
    for (final SelectedFile file in _state.files) {
      final int? size = file.sizeInBytes;
      if (size == null) return null;
      sum += size;
    }
    return sum;
  }

  /// Records where the user is sending to.
  ///
  /// A plain assignment rather than a use case: building a value object is not a
  /// repository or service call, and a use case that only forwards a constructor
  /// would be indirection with no orchestration behind it (`AGENTS.md` §12).
  void setDestination(TransferDestination destination) {
    _emit(_state.copyWith(destination: destination));
  }

  /// Opens the picker and adopts whatever the user chose.
  ///
  /// A cancelled picker leaves the state untouched. Treating cancellation as an
  /// empty selection would silently discard files the user had already picked,
  /// which contradicts their intent (`AGENTS.md` §28).
  Future<void> pickFiles() async {
    _emit(_state.copyWith(status: TransferStatus.selectingFiles, error: null));

    final Result<List<SelectedFile>, Failure> result = await _selectFiles();

    switch (result) {
      case Success(:final value):
        if (value.isEmpty) {
          _emit(_state.copyWith(status: _statusFor(_state.files)));
          return;
        }
        _emit(
          _state.copyWith(
            status: TransferStatus.ready,
            files: value,
            error: null,
          ),
        );
      case Err(:final error):
        _emit(_state.copyWith(status: TransferStatus.error, error: error));
    }
  }

  /// Removes one file from the selection.
  void removeFile(SelectedFile file) {
    final List<SelectedFile> remaining = List<SelectedFile>.of(_state.files)
      ..remove(file);
    _emit(
      _state.copyWith(
        // Derived from `remaining`, not from `_state.files`: the emitted state
        // is still the old one here, so reading it would keep reporting `ready`
        // after the last file was removed.
        status: _statusFor(remaining),
        files: List<SelectedFile>.unmodifiable(remaining),
        error: null,
      ),
    );
  }

  /// Ready only when there is something to send, so the send action can never be
  /// enabled with an empty queue.
  static TransferStatus _statusFor(List<SelectedFile> files) =>
      files.isEmpty ? TransferStatus.initial : TransferStatus.ready;

  void _emit(TransferState next) {
    _state = next;
    notifyListeners();
  }
}
