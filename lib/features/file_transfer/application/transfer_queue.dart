import 'dart:async';

import 'package:partilha/core/errors/failure.dart';
import 'package:partilha/core/logging/logging.dart';
import 'package:partilha/features/file_transfer/application/send_file_use_case.dart';
import 'package:partilha/features/file_transfer/domain/domain.dart';

/// The application-level transfer queue (`features/file_transfer/FEATURE.md`
/// §16, §18).
///
/// Owns order, retries, cancellation and progress aggregation, and nothing
/// else: no socket, no file handle, no clock of its own beyond an injectable
/// delay. The bytes belong to `TransferRepository`; the queue decides what
/// runs when (`AGENTS.md` §18, `docs/PROTOCOL.md` §38).
///
/// One file at a time, in selection order. A failed file is marked and the
/// queue moves on — one failure must never take the rest of the selection with
/// it (`FEATURES.md` §23).
class TransferQueue {
  TransferQueue({
    required this._send,
    required this._logger,
    // Injected so a test can assert the approved backoff without spending
    // three real seconds per retry case (`AGENTS.md` §60.1).
    Future<void> Function(Duration duration)? delay,
    // Injected so speed tests measure a window they control rather than the
    // wall clock (`AGENTS.md` §60.1).
    DateTime Function()? clock,
  }) : _delay = delay ?? Future<void>.delayed,
       _clock = clock ?? DateTime.now;

  /// Attempts per file, including the first (`AGENTS.md` §27).
  static const int maxAttempts = 3;

  /// Backoff after the first and second failure (`FEATURES.md` §24).
  static const Duration firstBackoff = Duration(seconds: 1);
  static const Duration secondBackoff = Duration(seconds: 2);

  /// How far back a speed averages (`docs/PROTOCOL.md` §18 calls the windowing
  /// an implementation detail). Three seconds smooths a single late frame
  /// without lagging visibly behind the wire.
  static const Duration speedWindow = Duration(seconds: 3);

  final SendFileUseCase _send;
  final AppLogger _logger;
  final Future<void> Function(Duration duration) _delay;
  final DateTime Function() _clock;

  final Map<String, TransferItem> _items = <String, TransferItem>{};

  /// (when, cumulative bytes) observations per attempt, keyed by transfer id.
  ///
  /// Kept here rather than in the [TransferItem]: samples are observations
  /// over time, not part of what an item *is* — only the measured result
  /// belongs in the state the UI reads.
  final Map<String, List<_SpeedSample>> _speedSamples =
      <String, List<_SpeedSample>>{};

  final StreamController<List<TransferItem>> _updates =
      StreamController<List<TransferItem>>.broadcast();

  List<TransferItem> _snapshot = const <TransferItem>[];
  int _nextId = 0;
  bool _draining = false;
  _ActiveSend? _active;

  /// Every item, in queue order, as of the last change.
  ///
  /// Read this before subscribing to [updates]: the stream is broadcast and
  /// replays nothing.
  List<TransferItem> get items => _snapshot;

  /// Emits a full snapshot after every change, progress included.
  ///
  /// A snapshot rather than a delta, because a renderer needs the whole queue
  /// to know which row is next, and because an item that disappears (it
  /// cannot today, but history would) is expressible without a second event
  /// type.
  Stream<List<TransferItem>> get updates => _updates.stream;

  /// Adds every file to the queue and starts draining if it is not already.
  ///
  /// Ids are assigned here, local to this queue instance: the wire identifier
  /// format is still an open decision (`FEATURE.md` §34) and must not be
  /// pre-empted by a format invented for bookkeeping.
  void enqueue({
    required TransferDestination destination,
    required List<SelectedFile> files,
  }) {
    if (files.isEmpty) return;

    for (final SelectedFile file in files) {
      final String id = 'transfer-${_nextId++}';
      // Born `queued` rather than `created`: the only transition out of
      // `created` is `validating`, and the sender cannot validate until the
      // receiver-side storage check is reachable over the protocol
      // (`FEATURE.md` §9, §34). Creating the item in the state it actually is
      // avoids a transition that performs nothing.
      _items[id] = TransferItem(
        request: TransferRequest(id: id, destination: destination, file: file),
        status: TransferStatus.queued,
      );
    }

    _publish();
    unawaited(_drain());
  }

  /// Stops [transferId] wherever it is: queued, sending, or waiting out a
  /// retry backoff.
  ///
  /// Idempotent and forgiving about ids that are unknown or already terminal,
  /// because the user's cancel routinely races a completion and a failure there
  /// would punish them for being fast (`AGENTS.md` §28, §83).
  void cancel(String transferId) {
    final TransferItem? item = _items[transferId];
    if (item == null) {
      _logger.debug(
        'cancelled an unknown transfer id',
        context: <String, Object?>{'transferId': transferId},
      );
      return;
    }
    if (item.status.isTerminal) return;

    if (!_advance(transferId, TransferStatus.cancelled)) return;

    final _ActiveSend? active = _active;
    if (active != null && active.id == transferId) {
      _complete(active.completer, const _SendOutcome.cancelled());
      _active = null;
      unawaited(active.subscription.cancel());
    }
  }

  /// Removes items in terminal states (completed, failed, cancelled) from the queue.
  void clearCompleted() {
    _items.removeWhere((String id, TransferItem item) {
      if (item.status.isTerminal) {
        _speedSamples.remove(id);
        return true;
      }
      return false;
    });
    _publish();
  }

  /// Cancels in-flight sends and clears all items from the queue.
  void reset() {
    final _ActiveSend? active = _active;
    if (active != null) {
      _complete(active.completer, const _SendOutcome.cancelled());
      _active = null;
      unawaited(active.subscription.cancel());
    }
    _items.clear();
    _speedSamples.clear();
    _publish();
  }

  /// Releases the update stream and any in-flight send.
  ///
  /// The queue is owned by the composition root, so this runs when the owner
  /// lets go — in practice, between tests (`AGENTS.md` §81).
  Future<void> dispose() async {
    final _ActiveSend? active = _active;
    if (active != null) {
      _complete(active.completer, const _SendOutcome.cancelled());
      _active = null;
      await active.subscription.cancel();
    }
    await _updates.close();
  }

  /// Processes the queue until nothing is left to start.
  ///
  /// Re-entrant by construction: a second call while one is running returns
  /// immediately, and the running loop picks up whatever was appended, because
  /// it re-reads the queue after every item instead of holding a fixed list.
  Future<void> _drain() async {
    if (_draining) return;
    _draining = true;
    try {
      while (true) {
        final TransferItem? next = _nextQueued();
        if (next == null) break;
        await _process(next);
      }
    } finally {
      _draining = false;
    }
  }

  TransferItem? _nextQueued() {
    for (final TransferItem item in _items.values) {
      if (item.status == TransferStatus.queued) return item;
    }
    return null;
  }

  Future<void> _process(TransferItem item) async {
    final String id = item.transferId;

    if (!_advance(id, TransferStatus.starting)) return;
    // Handed off, so it is transferring. The repository contract has no
    // separate "connected" signal yet — bytes are the first thing it reports —
    // and inventing a waiting-for-peer state would be behaviour nobody
    // approved (`FEATURE.md` §34).
    if (!_advance(id, TransferStatus.transferring)) return;

    int attempts = 1;
    while (true) {
      final _SendOutcome outcome = await _sendOnce(id);
      _endSend(id);
      if (outcome.status == _OutcomeStatus.cancelled) return;

      final Failure? failure = _failureFor(id, outcome);
      if (failure == null) {
        _advance(id, TransferStatus.completed);
        return;
      }

      if (failure.isRetryable && attempts < maxAttempts) {
        if (!_advance(id, TransferStatus.retrying)) return;
        await _delay(_backoff(attempts));
        // The user may have cancelled while the backoff was running; their
        // cancellation wins (`FEATURE.md` §28 edge case).
        if (_items[id]?.status != TransferStatus.retrying) return;
        if (!_advance(id, TransferStatus.transferring)) return;
        attempts += 1;
        continue;
      }

      _advance(id, TransferStatus.failed, failure: failure);
      return;
    }
  }

  /// The failure the outcome represents, or `null` when the send succeeded.
  ///
  /// A stream that closes before the declared size is a dropped connection,
  /// not a finished file: presenting it as complete would expose a truncated
  /// file as whole (`FEATURE.md` §7, §12). When no size was ever declared
  /// there is nothing to check against, so the close is taken at face value —
  /// real integrity checking belongs to the protocol (`FEATURE.md` §34).
  Failure? _failureFor(String id, _SendOutcome outcome) {
    if (outcome.status == _OutcomeStatus.failed) return outcome.failure;

    final TransferItem current = _items[id]!;
    final int? total = current.totalBytes;
    if (total == null || current.bytesTransferred >= total) return null;
    return TransferFailure.connectionLost;
  }

  static Duration _backoff(int attempts) =>
      attempts == 1 ? firstBackoff : secondBackoff;

  Future<_SendOutcome> _sendOnce(String id) {
    final TransferRequest request = _items[id]!.request;
    final Completer<_SendOutcome> completer = Completer<_SendOutcome>();

    final StreamSubscription<FileTransferProgress> subscription = _send(request)
        .listen(
          (FileTransferProgress progress) => _onProgress(id, progress),
          onError: (Object error) => _complete(
            completer,
            _SendOutcome.failed(
              error is Failure ? error : UnknownFailure(cause: error),
            ),
          ),
          onDone: () => _complete(completer, const _SendOutcome.done()),
          cancelOnError: true,
        );

    if (completer.isCompleted) {
      unawaited(subscription.cancel());
      return completer.future;
    }
    _active = _ActiveSend(
      id: id,
      subscription: subscription,
      completer: completer,
    );
    return completer.future;
  }

  void _onProgress(String id, FileTransferProgress progress) {
    final TransferItem? item = _items[id];
    if (item == null || item.status.isTerminal) return;
    _items[id] = item
        .withProgress(progress.bytesTransferred)
        .withSpeed(_speedFor(id, progress.bytesTransferred));
    _publish();
  }

  /// The speed over the trailing [speedWindow] ending now, or `null` when the
  /// samples say nothing measurable yet.
  ///
  /// Derived only from what the repository reported and when
  /// (`FEATURES.md` §22, `docs/PROTOCOL.md` §18): one sample means no elapsed
  /// time, so `null` instead of a guess, and bytes restarting at zero — a new
  /// attempt — clear the samples rather than produce a negative rate.
  int? _speedFor(String id, int bytesTransferred) {
    final DateTime now = _clock();
    final List<_SpeedSample> samples = _speedSamples.putIfAbsent(
      id,
      () => <_SpeedSample>[],
    );

    if (samples.isNotEmpty && bytesTransferred < samples.last.bytes) {
      samples.clear();
    }
    samples.add(_SpeedSample(at: now, bytes: bytesTransferred));

    // Keep the newest window, but never fewer than two samples: dropping to
    // one would leave nothing to divide by until the next event.
    final DateTime cutoff = now.subtract(speedWindow);
    while (samples.length > 2 && samples.first.at.isBefore(cutoff)) {
      samples.removeAt(0);
    }

    final int elapsedMicros = now.difference(samples.first.at).inMicroseconds;
    if (elapsedMicros <= 0) return null;
    return ((bytesTransferred - samples.first.bytes) * 1000000 / elapsedMicros)
        .round();
  }

  void _endSend(String id) {
    final _ActiveSend? active = _active;
    if (active == null || active.id != id) return;
    _active = null;
    unawaited(active.subscription.cancel());
  }

  static void _complete(Completer<_SendOutcome> completer, _SendOutcome next) {
    if (!completer.isCompleted) completer.complete(next);
  }

  /// Moves the item to [next], or reports that it could not.
  ///
  /// A refusal is expected when the item already reached a terminal state —
  /// cancellation beat a late stream event — and logged as such. Anything else
  /// is a bug in this class, because the queue is the only code allowed to
  /// transition items, and a bug should be visible rather than silently
  /// swallowed (`AGENTS.md` §52, §83).
  bool _advance(String id, TransferStatus next, {Failure? failure}) {
    final TransferItem? item = _items[id];
    if (item == null) return false;

    final TransferItem? advanced = item.transitionTo(next, failure: failure);
    if (advanced == null) {
      final Map<String, Object?> context = <String, Object?>{
        'transferId': id,
        'from': item.status.name,
        'to': next.name,
      };
      if (item.status.isTerminal) {
        _logger.debug('ignored a late transfer transition', context: context);
      } else {
        _logger.warning(
          'ignored an illegal transfer transition',
          context: context,
        );
      }
      return false;
    }

    _items[id] = advanced;
    if (next != TransferStatus.transferring) {
      // Speed describes an attempt in flight. A finished, failed, cancelled or
      // backing-off item has no rate to show, and a stale number would be a
      // fabricated one (`FEATURES.md` §22).
      _speedSamples.remove(id);
      if (advanced.speedBytesPerSecond != null) {
        _items[id] = advanced.withSpeed(null);
      }
    }
    _publish();
    return true;
  }

  void _publish() {
    _snapshot = List<TransferItem>.unmodifiable(_items.values);
    // A listener may have been disposed mid-flight; adding to a closed
    // broadcast controller throws, and a shutdown race is not worth a crash.
    if (!_updates.isClosed) _updates.add(_snapshot);
  }
}

/// One live send: the subscription the queue must release, and the completer
/// that turns its events into an outcome the queue can await.
class _ActiveSend {
  const _ActiveSend({
    required this.id,
    required this.subscription,
    required this.completer,
  });

  final String id;
  final StreamSubscription<FileTransferProgress> subscription;
  final Completer<_SendOutcome> completer;
}

enum _OutcomeStatus { done, failed, cancelled }

class _SendOutcome {
  const _SendOutcome.done() : status = _OutcomeStatus.done, failure = null;

  const _SendOutcome.failed(Failure this.failure)
    : status = _OutcomeStatus.failed;

  const _SendOutcome.cancelled()
    : status = _OutcomeStatus.cancelled,
      failure = null;

  final _OutcomeStatus status;

  /// The typed cause, present only for [_OutcomeStatus.failed].
  final Failure? failure;
}

/// One observation of (when, how many bytes) for one attempt.
class _SpeedSample {
  const _SpeedSample({required this.at, required this.bytes});

  final DateTime at;
  final int bytes;
}
