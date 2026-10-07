import 'package:partilha/core/errors/failure.dart';
import 'package:partilha/core/result/result.dart';
import 'package:partilha/features/file_transfer/application/transfer_queue.dart';
import 'package:partilha/features/file_transfer/domain/domain.dart';

/// Puts a selection on the transfer queue (`features/file_transfer/FEATURE.md`
/// §16).
///
/// The orchestration lives in [TransferQueue]; this use case is the application
/// action the controller calls, so the presentation layer never reaches for the
/// queue itself (`AGENTS.md` §12).
class QueueTransfersUseCase {
  const QueueTransfersUseCase(this._queue);

  final TransferQueue _queue;

  /// Queues every file in [files] for [destination], in selection order.
  ///
  /// An empty selection is a [ValidationFailure] rather than a silent success:
  /// queueing nothing is a caller mistake, and reporting success would let a
  /// Send press with an empty queue look like it did something
  /// (`AGENTS.md` §83).
  Future<Result<void, Failure>> call({
    required TransferDestination destination,
    required List<SelectedFile> files,
  }) async {
    if (files.isEmpty) return const Result.failure(ValidationFailure.empty);

    _queue.enqueue(destination: destination, files: files);
    return const Result.success(null);
  }
}
