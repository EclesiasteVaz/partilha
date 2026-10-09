import 'package:partilha/core/errors/failure.dart';
import 'package:partilha/features/file_transfer/domain/transfer_request.dart';

/// Lifecycle state of one queued transfer, exactly as `FEATURE.md` §8 defines
/// it.
///
/// [TransferStatus.isTerminal] and [TransferItem.canTransitionTo] together
/// enforce §9: the terminal states have no outgoing transitions, so a transfer
/// that completed, failed or was cancelled cannot be resurrected by a late
/// stream event or a race with cancellation.
///
/// `created` and `validating` exist because the documented lifecycle has them,
/// but the sender-side queue does not enter them yet: the storage check runs on
/// the receiver and needs the control protocol, which is still open
/// (`FEATURE.md` §3, §34). The queue enqueues items as [queued] until then.
enum TransferStatus {
  /// The item exists; nothing has been scheduled yet.
  created,

  /// Destination storage is being checked. Receiver-side in the approved flow.
  validating,

  /// Waiting for its turn in the queue.
  queued,

  /// Handed to the repository; the send has been initiated.
  starting,

  /// The send session is live and bytes may be moving.
  transferring,

  /// A retryable failure occurred and the backoff before the next attempt is
  /// running.
  retrying,

  /// Every declared byte was delivered.
  completed,

  /// Finished without satisfying the transfer, after the retry budget was
  /// exhausted or the failure was not retryable.
  failed,

  /// Stopped on request. No outgoing transitions: cancellation is the user's
  /// final word (`AGENTS.md` §28).
  cancelled;

  /// Whether the state is terminal (`FEATURE.md` §9).
  bool get isTerminal =>
      this == TransferStatus.completed ||
      this == TransferStatus.failed ||
      this == TransferStatus.cancelled;
}

/// One file on its way to one destination, carrying its lifecycle state and
/// its real byte progress.
///
/// Immutable: the queue never mutates an item, it replaces it with the result
/// of a transition (`AGENTS.md` §10). That keeps "what state is this item in?"
/// a question about a value rather than about when you last looked.
class TransferItem {
  const TransferItem({
    required this.request,
    required this.status,
    this.bytesTransferred = 0,
    this.speedBytesPerSecond,
    this.failure,
  });

  /// What to send, and where.
  final TransferRequest request;

  final TransferStatus status;

  /// Bytes actually delivered, never estimated (`AGENTS.md` §20).
  final int bytesTransferred;

  /// Real transfer speed in bytes per second, over the queue's trailing window
  /// of byte samples (`FEATURES.md` §22, `docs/PROTOCOL.md` §18).
  ///
  /// `null` whenever no window can be measured yet — before a second sample
  /// exists, after a retry restarts the count, or once the item leaves
  /// [TransferStatus.transferring]. A stalled transfer must show a stale-free
  /// `null` rather than the last speed it happened to reach (`AGENTS.md` §20,
  /// §83).
  final int? speedBytesPerSecond;

  /// The typed cause of a [TransferStatus.failed] item, and `null` for every
  /// other state — an item that is not failed must not carry a failure, or the
  /// UI would have to decide whether to believe it.
  final Failure? failure;

  /// Local queue identifier, assigned when the item is enqueued. Not the wire
  /// transfer identifier: that format is still open (`FEATURE.md` §34).
  String get transferId => request.id;

  String get fileName => request.name;

  /// The progress denominator, or `null` when the platform never reported a
  /// size. Progress is then indeterminate rather than a made-up percentage
  /// (`AGENTS.md` §20).
  int? get totalBytes => request.sizeInBytes;

  /// Real bytes over real total, or `null` when there is no denominator.
  double? get fraction {
    final int? total = totalBytes;
    if (total == null || total <= 0) return null;
    return bytesTransferred / total;
  }

  /// Whether §9 allows moving from the current state to [next].
  bool canTransitionTo(TransferStatus next) => switch (status) {
    TransferStatus.created => next == TransferStatus.validating,
    TransferStatus.validating =>
      next == TransferStatus.queued || next == TransferStatus.failed,
    TransferStatus.queued =>
      next == TransferStatus.starting || next == TransferStatus.cancelled,
    TransferStatus.starting =>
      next == TransferStatus.transferring ||
          next == TransferStatus.failed ||
          next == TransferStatus.cancelled,
    TransferStatus.transferring =>
      next == TransferStatus.completed ||
          next == TransferStatus.retrying ||
          next == TransferStatus.failed ||
          next == TransferStatus.cancelled,
    TransferStatus.retrying =>
      next == TransferStatus.transferring ||
          next == TransferStatus.failed ||
          next == TransferStatus.cancelled,
    // Terminal states admit nothing (§9).
    TransferStatus.completed => false,
    TransferStatus.failed => false,
    TransferStatus.cancelled => false,
  };

  /// Returns this item in [next], or `null` when §9 forbids the transition or
  /// the arguments do not match the target state.
  ///
  /// `null` rather than a thrown error: a transfer can legally reach an
  /// illegal-looking transition through a race — the user cancels while a send
  /// is completing — and the correct response there is to keep the state that
  /// won, not to crash (`AGENTS.md` §83). A transition to
  /// [TransferStatus.failed] without a [failure], or to any other state with
  /// one, is rejected for the same reason: the caller made a mistake, and
  /// silently inventing or dropping a cause would hide it.
  TransferItem? transitionTo(TransferStatus next, {Failure? failure}) {
    if (!canTransitionTo(next)) return null;
    if (next == TransferStatus.failed && failure == null) return null;
    if (next != TransferStatus.failed && failure != null) return null;
    return TransferItem(
      request: request,
      status: next,
      bytesTransferred: bytesTransferred,
      speedBytesPerSecond: speedBytesPerSecond,
      failure: failure,
    );
  }

  /// Returns this item with [bytes] recorded, regardless of state.
  ///
  /// Progress is data, not a lifecycle transition: it reports how far the
  /// bytes got, not what the transfer is doing (`FEATURE.md` §20).
  TransferItem withProgress(int bytes) => TransferItem(
    request: request,
    status: status,
    bytesTransferred: bytes,
    speedBytesPerSecond: speedBytesPerSecond,
    failure: failure,
  );

  /// Returns this item with a new measured [speed], regardless of state.
  ///
  /// Speed is set and cleared by the queue, which owns the sampling clock —
  /// the item only carries the number (`AGENTS.md` §20).
  TransferItem withSpeed(int? speed) => TransferItem(
    request: request,
    status: status,
    bytesTransferred: bytesTransferred,
    speedBytesPerSecond: speed,
    failure: failure,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TransferItem &&
          other.request == request &&
          other.status == status &&
          other.bytesTransferred == bytesTransferred &&
          other.speedBytesPerSecond == speedBytesPerSecond &&
          other.failure == failure;

  @override
  int get hashCode => Object.hash(
    request,
    status,
    bytesTransferred,
    speedBytesPerSecond,
    failure,
  );

  @override
  String toString() =>
      'TransferItem($transferId, $fileName, ${status.name}, '
      '$bytesTransferred/$totalBytes, ${speedBytesPerSecond ?? '-'} B/s)';
}
