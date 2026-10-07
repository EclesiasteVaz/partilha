import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:partilha/core/errors/failure.dart';
import 'package:partilha/core/logging/logging.dart';
import 'package:partilha/core/result/result.dart';
import 'package:partilha/features/file_transfer/application/application.dart';
import 'package:partilha/features/file_transfer/domain/domain.dart';

/// A repository whose per-file behaviour each test scripts, plus the order in
/// which `send` was actually called — the queue's contract is about order and
/// attempts, so the fake records both.
///
/// Nothing here mocks a transfer that "works" by returning success without
/// bytes: an integration test must not fake away the behaviour it exists to
/// check (`AGENTS.md` §60.2).
class ScriptedTransferRepository implements TransferRepository {
  final List<TransferRequest> sends = <TransferRequest>[];

  final Map<String, Stream<FileTransferProgress> Function(TransferRequest)>
  scripts = <String, Stream<FileTransferProgress> Function(TransferRequest)>{};

  int attemptsFor(String fileName) =>
      sends.where((TransferRequest request) => request.name == fileName).length;

  @override
  Stream<FileTransferProgress> send(TransferRequest request) {
    sends.add(request);
    final Stream<FileTransferProgress> Function(TransferRequest)? script =
        scripts[request.name];
    if (script == null) return _succeeds(request);
    return script(request);
  }

  static Stream<FileTransferProgress> _succeeds(TransferRequest request) {
    final int total = request.sizeInBytes ?? 0;
    return Stream<FileTransferProgress>.fromIterable(<FileTransferProgress>[
      FileTransferProgress(
        transferId: request.id,
        bytesTransferred: total,
        totalBytes: total,
      ),
    ]);
  }
}

void main() {
  const TransferDestination destination = TransferDestination(
    deviceId: 'device-1',
    deviceName: 'Ada',
    address: '192.168.1.20',
    port: 4443,
  );

  SelectedFile file({required String name, int? sizeInBytes = 10}) =>
      SelectedFile(name: name, path: '/tmp/$name', sizeInBytes: sizeInBytes);

  FileTransferProgress progress({required int bytes, required int total}) =>
      FileTransferProgress(
        transferId: 'local-only',
        bytesTransferred: bytes,
        totalBytes: total,
      );

  /// Yields to the event loop until [condition] holds, then fails if it never
  /// does. Loop-based rather than a fixed delay, so a slow machine passes and
  /// a genuine bug still fails.
  Future<void> until(
    bool Function() condition, {
    String reason = 'condition never became true',
  }) async {
    for (int attempt = 0; attempt < 500; attempt++) {
      if (condition()) return;
      await Future<void>.delayed(Duration.zero);
    }
    fail(reason);
  }

  /// Lets already-scheduled microtasks and stream events run, for assertions
  /// about something that must *not* happen.
  Future<void> settle([int turns = 20]) async {
    for (int turn = 0; turn < turns; turn++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  late ScriptedTransferRepository repo;
  late RecordingLogSink sink;
  late List<Duration> delays;

  /// Reassignable so a test can hold the next backoff open (the cancel-during-
  /// backoff case) without the queue knowing tests exist.
  late Future<void> Function(Duration duration) delay;

  late TransferQueue queue;

  setUp(() {
    repo = ScriptedTransferRepository();
    sink = RecordingLogSink();
    delays = <Duration>[];
    delay = (Duration duration) {
      delays.add(duration);
      return Future<void>.value();
    };
    queue = TransferQueue(
      send: SendFileUseCase(repo),
      logger: StructuredLogger(sink: sink),
      delay: (Duration duration) => delay(duration),
    );
  });

  tearDown(() async {
    await queue.dispose();
  });

  group('TransferQueue', () {
    test('runs one file at a time, in selection order', () async {
      final StreamController<FileTransferProgress> hangingA =
          StreamController<FileTransferProgress>();
      repo.scripts['a.txt'] = (TransferRequest request) => hangingA.stream;

      queue.enqueue(
        destination: destination,
        files: <SelectedFile>[
          file(name: 'a.txt'),
          file(name: 'b.txt'),
          file(name: 'c.txt'),
        ],
      );

      // The first file is handed off synchronously; the rest wait their turn
      // (`FEATURES.md` §23).
      expect(
        queue.items.map((TransferItem item) => item.status),
        <TransferStatus>[
          TransferStatus.transferring,
          TransferStatus.queued,
          TransferStatus.queued,
        ],
      );
      expect(repo.sends, hasLength(1));

      hangingA.add(progress(bytes: 10, total: 10));
      await hangingA.close();
      await until(
        () => repo.sends.length >= 2,
        reason: 'the queue did not start the second file',
      );
      expect(repo.sends[1].name, 'b.txt');

      await until(
        () => queue.items.every((TransferItem item) => item.status.isTerminal),
        reason: 'the queue stalled before the last file',
      );
      expect(queue.items.map((TransferItem item) => item.fileName), <String>[
        'a.txt',
        'b.txt',
        'c.txt',
      ]);
      expect(
        queue.items.map((TransferItem item) => item.status),
        <TransferStatus>[
          TransferStatus.completed,
          TransferStatus.completed,
          TransferStatus.completed,
        ],
      );
    });

    test('records real byte progress as the repository reports it', () async {
      final StreamController<FileTransferProgress> hangingA =
          StreamController<FileTransferProgress>();
      repo.scripts['a.txt'] = (TransferRequest request) => hangingA.stream;

      queue.enqueue(
        destination: destination,
        files: <SelectedFile>[file(name: 'a.txt')],
      );
      hangingA.add(progress(bytes: 4, total: 10));

      await until(
        () => queue.items.single.bytesTransferred == 4,
        reason: 'progress was not recorded',
      );
      expect(queue.items.single.status, TransferStatus.transferring);
      expect(queue.items.single.fraction, closeTo(0.4, 1e-9));

      hangingA.add(progress(bytes: 10, total: 10));
      await hangingA.close();
      await until(() => queue.items.single.status == TransferStatus.completed);
    });

    test('treats a stream that closes early as a dropped connection: three '
        'attempts, 1s then 2s, then failed', () async {
      // Bytes short of the declared size must never be presented as a
      // finished file (`FEATURE.md` §7, `AGENTS.md` §20).
      repo.scripts['short.txt'] = (TransferRequest request) =>
          Stream<FileTransferProgress>.fromIterable(<FileTransferProgress>[
            progress(bytes: 4, total: 10),
          ]);

      queue.enqueue(
        destination: destination,
        files: <SelectedFile>[file(name: 'short.txt')],
      );

      await until(
        () => queue.items.single.status == TransferStatus.failed,
        reason: 'the retry budget was never exhausted',
      );

      expect(repo.attemptsFor('short.txt'), TransferQueue.maxAttempts);
      expect(delays, <Duration>[
        TransferQueue.firstBackoff,
        TransferQueue.secondBackoff,
      ]);
      expect(queue.items.single.failure, TransferFailure.connectionLost);
    });

    test(
      'gives up at once on a non-retryable failure and moves to the next file',
      () async {
        // Retrying a rejection wastes the user's time and hides the cause
        // (`AGENTS.md` §82), and one failed file must not take the rest of the
        // selection with it (`FEATURES.md` §23).
        repo.scripts['rejected.txt'] = (TransferRequest request) =>
            Stream<FileTransferProgress>.error(TransferFailure.remoteRejected);

        queue.enqueue(
          destination: destination,
          files: <SelectedFile>[
            file(name: 'rejected.txt'),
            file(name: 'ok.txt'),
          ],
        );

        await until(
          () =>
              queue.items[0].status == TransferStatus.failed &&
              queue.items[1].status == TransferStatus.completed,
          reason: 'the queue did not continue past the rejected file',
        );

        expect(repo.attemptsFor('rejected.txt'), 1);
        expect(delays, isEmpty);
        expect(queue.items[0].failure, TransferFailure.remoteRejected);
        expect(queue.items[1].failure, isNull);
      },
    );

    test('cancelling an active send releases the subscription', () async {
      bool released = false;
      final StreamController<FileTransferProgress> hangingA =
          StreamController<FileTransferProgress>(
            onCancel: () => released = true,
          );
      repo.scripts['a.txt'] = (TransferRequest request) => hangingA.stream;

      queue.enqueue(
        destination: destination,
        files: <SelectedFile>[file(name: 'a.txt')],
      );
      await until(
        () => queue.items.single.status == TransferStatus.transferring,
      );

      queue.cancel(queue.items.single.transferId);

      expect(queue.items.single.status, TransferStatus.cancelled);
      await until(() => released, reason: 'the subscription was left open');

      await hangingA.close();
      await settle();
      expect(repo.attemptsFor('a.txt'), 1);
      expect(queue.items.single.status, TransferStatus.cancelled);
    });

    test('cancelling during backoff skips the remaining attempts', () async {
      final Completer<void> backoffGate = Completer<void>();
      delay = (Duration duration) {
        delays.add(duration);
        return backoffGate.future;
      };

      repo.scripts['flaky.txt'] = (TransferRequest request) =>
          Stream<FileTransferProgress>.error(TransferFailure.connectionLost);

      queue.enqueue(
        destination: destination,
        files: <SelectedFile>[file(name: 'flaky.txt')],
      );

      await until(
        () => queue.items.single.status == TransferStatus.retrying,
        reason: 'the first failure did not enter backoff',
      );
      expect(delays, <Duration>[TransferQueue.firstBackoff]);

      queue.cancel(queue.items.single.transferId);
      expect(queue.items.single.status, TransferStatus.cancelled);

      backoffGate.complete();
      await settle();

      expect(repo.attemptsFor('flaky.txt'), 1);
      expect(delays, <Duration>[TransferQueue.firstBackoff]);
      expect(queue.items.single.status, TransferStatus.cancelled);
    });

    test('cancelling a queued file means it is never sent', () async {
      final StreamController<FileTransferProgress> hangingA =
          StreamController<FileTransferProgress>();
      repo.scripts['a.txt'] = (TransferRequest request) => hangingA.stream;

      queue.enqueue(
        destination: destination,
        files: <SelectedFile>[
          file(name: 'a.txt'),
          file(name: 'b.txt'),
        ],
      );
      await until(() => repo.sends.length == 1);

      queue.cancel(queue.items[1].transferId);
      expect(queue.items[1].status, TransferStatus.cancelled);

      hangingA.add(progress(bytes: 10, total: 10));
      await hangingA.close();
      await until(() => queue.items[0].status == TransferStatus.completed);

      expect(
        repo.sends.map((TransferRequest request) => request.name),
        <String>['a.txt'],
      );
      expect(queue.items[1].status, TransferStatus.cancelled);
    });

    test('cancelling an unknown or terminal id does nothing', () async {
      queue.cancel('transfer-404');
      expect(
        sink.records.any(
          (record) => record.message.contains('unknown transfer'),
        ),
        isTrue,
      );

      queue.enqueue(
        destination: destination,
        files: <SelectedFile>[file(name: 'a.txt')],
      );
      await until(() => queue.items.single.status == TransferStatus.completed);

      queue.cancel(queue.items.single.transferId);
      expect(queue.items.single.status, TransferStatus.completed);
    });

    test('emits a full snapshot on every change, progress included', () async {
      final StreamController<FileTransferProgress> hangingA =
          StreamController<FileTransferProgress>();
      repo.scripts['a.txt'] = (TransferRequest request) => hangingA.stream;

      final List<List<TransferItem>> snapshots = <List<TransferItem>>[];
      final StreamSubscription<List<TransferItem>> subscription = queue.updates
          .listen(snapshots.add);

      queue.enqueue(
        destination: destination,
        files: <SelectedFile>[
          file(name: 'a.txt'),
          file(name: 'b.txt'),
        ],
      );
      hangingA.add(progress(bytes: 5, total: 10));
      await until(() => queue.items.first.bytesTransferred == 5);

      expect(snapshots, isNotEmpty);
      expect(
        snapshots.first.map((TransferItem item) => item.status),
        <TransferStatus>[TransferStatus.queued, TransferStatus.queued],
      );

      final List<TransferItem> withProgress = snapshots.firstWhere(
        (List<TransferItem> snapshot) => snapshot.first.bytesTransferred == 5,
        orElse: () => const <TransferItem>[],
      );
      expect(withProgress, isNotEmpty);
      expect(withProgress.first.status, TransferStatus.transferring);

      hangingA.add(progress(bytes: 10, total: 10));
      await hangingA.close();
      await until(
        () => queue.items.every((TransferItem item) => item.status.isTerminal),
      );
      await subscription.cancel();
    });
  });

  group('QueueTransfersUseCase', () {
    test('queues every file of a non-empty selection', () async {
      final QueueTransfersUseCase useCase = QueueTransfersUseCase(queue);

      final Result<void, Failure> result = await useCase(
        destination: destination,
        files: <SelectedFile>[
          file(name: 'a.txt'),
          file(name: 'b.txt'),
        ],
      );

      expect(result.isSuccess, isTrue);
      expect(queue.items.map((TransferItem item) => item.fileName), <String>[
        'a.txt',
        'b.txt',
      ]);
    });

    test('reports an empty selection as a validation failure', () async {
      // Silently succeeding would make a Send press with nothing selected look
      // like it worked (`AGENTS.md` §83).
      final QueueTransfersUseCase useCase = QueueTransfersUseCase(queue);

      final Result<void, Failure> result = await useCase(
        destination: destination,
        files: const <SelectedFile>[],
      );

      expect(result.isFailure, isTrue);
      expect(result.errorOrNull, ValidationFailure.empty);
      expect(queue.items, isEmpty);
    });
  });

  group('CancelTransferUseCase', () {
    test('cancels through the queue, which owns the send', () async {
      bool released = false;
      final StreamController<FileTransferProgress> hangingA =
          StreamController<FileTransferProgress>(
            onCancel: () => released = true,
          );
      repo.scripts['a.txt'] = (TransferRequest request) => hangingA.stream;

      queue.enqueue(
        destination: destination,
        files: <SelectedFile>[file(name: 'a.txt')],
      );
      await until(
        () => queue.items.single.status == TransferStatus.transferring,
      );

      final CancelTransferUseCase useCase = CancelTransferUseCase(queue);
      useCase(queue.items.single.transferId);

      expect(queue.items.single.status, TransferStatus.cancelled);
      await until(() => released, reason: 'the subscription was not released');
      await hangingA.close();
    });

    test('an unknown id is a no-op, not an exception', () {
      final CancelTransferUseCase useCase = CancelTransferUseCase(queue);

      expect(() => useCase('transfer-404'), returnsNormally);
    });
  });
}
