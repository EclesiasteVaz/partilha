import 'package:partilha/features/file_transfer/application/transfer_queue.dart';

/// Stops one queued or running transfer (`features/file_transfer/FEATURE.md`
/// §15).
///
/// Cancellation reaches the queue rather than a repository: it is the queue
/// that owns the active send and the item's state, and a second path to the
/// same bytes would be two owners (`AGENTS.md` §12, §81).
class CancelTransferUseCase {
  const CancelTransferUseCase(this._queue);

  final TransferQueue _queue;

  /// Cancels [transferId].
  ///
  /// Synchronous and total: an unknown id, an already terminal transfer and a
  /// transfer that completes as this runs are all no-ops, because the user's
  /// cancel racing a completion is normal use, not an error to surface
  /// (`AGENTS.md` §28, §83).
  void call(String transferId) => _queue.cancel(transferId);
}
