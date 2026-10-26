import 'package:partilha/features/file_transfer/application/transfer_queue.dart';

/// Removes items in terminal states (completed, failed, cancelled) from the transfer queue.
class ClearCompletedTransfersUseCase {
  const ClearCompletedTransfersUseCase(this._queue);

  final TransferQueue _queue;

  void call() => _queue.clearCompleted();
}
