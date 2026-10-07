import 'package:flutter_test/flutter_test.dart';
import 'package:partilha/core/errors/failure.dart';
import 'package:partilha/features/file_transfer/domain/domain.dart';

void main() {
  const TransferDestination destination = TransferDestination(
    deviceId: 'device-1',
    deviceName: 'Ada',
    address: '192.168.1.20',
    port: 4443,
  );

  TransferItem item(
    TransferStatus status, {
    int bytesTransferred = 0,
    int? sizeInBytes = 10,
    Failure? failure,
  }) => TransferItem(
    request: TransferRequest(
      id: 'transfer-0',
      destination: destination,
      file: SelectedFile(
        name: 'photo.jpg',
        path: '/tmp/photo.jpg',
        sizeInBytes: sizeInBytes,
      ),
    ),
    status: status,
    bytesTransferred: bytesTransferred,
    failure: failure,
  );

  /// `FEATURE.md` §9, verbatim. The table lives here rather than as prose so a
  /// future edit to the state machine cannot quietly diverge from the spec: the
  /// test is the spec's executable twin.
  const Map<TransferStatus, Set<TransferStatus>> allowed =
      <TransferStatus, Set<TransferStatus>>{
        TransferStatus.created: <TransferStatus>{TransferStatus.validating},
        TransferStatus.validating: <TransferStatus>{
          TransferStatus.queued,
          TransferStatus.failed,
        },
        TransferStatus.queued: <TransferStatus>{
          TransferStatus.starting,
          TransferStatus.cancelled,
        },
        TransferStatus.starting: <TransferStatus>{
          TransferStatus.transferring,
          TransferStatus.failed,
          TransferStatus.cancelled,
        },
        TransferStatus.transferring: <TransferStatus>{
          TransferStatus.completed,
          TransferStatus.retrying,
          TransferStatus.failed,
          TransferStatus.cancelled,
        },
        TransferStatus.retrying: <TransferStatus>{
          TransferStatus.transferring,
          TransferStatus.failed,
          TransferStatus.cancelled,
        },
        TransferStatus.completed: <TransferStatus>{},
        TransferStatus.failed: <TransferStatus>{},
        TransferStatus.cancelled: <TransferStatus>{},
      };

  group('TransferStatus', () {
    test('exactly completed, failed and cancelled are terminal', () {
      for (final TransferStatus status in TransferStatus.values) {
        expect(
          status.isTerminal,
          status == TransferStatus.completed ||
              status == TransferStatus.failed ||
              status == TransferStatus.cancelled,
          reason: '${status.name} must match FEATURE.md §9',
        );
      }
    });
  });

  group('TransferItem.canTransitionTo follows FEATURE.md §9', () {
    for (final TransferStatus from in TransferStatus.values) {
      test('out of ${from.name}', () {
        for (final TransferStatus to in TransferStatus.values) {
          expect(
            item(from).canTransitionTo(to),
            allowed[from]!.contains(to),
            reason: '${from.name} → ${to.name}',
          );
        }
      });
    }

    test(
      'terminal states admit nothing, so a late event cannot resurrect one',
      () {
        for (final TransferStatus terminal in <TransferStatus>[
          TransferStatus.completed,
          TransferStatus.failed,
          TransferStatus.cancelled,
        ]) {
          for (final TransferStatus to in TransferStatus.values) {
            expect(
              item(terminal).canTransitionTo(to),
              isFalse,
              reason: '${terminal.name} → ${to.name} must be refused',
            );
          }
        }
      },
    );
  });

  group('TransferItem.transitionTo', () {
    test('applies an allowed transition and keeps bytes and request', () {
      final TransferItem moved = item(
        TransferStatus.transferring,
        bytesTransferred: 7,
      ).transitionTo(TransferStatus.retrying)!;

      expect(moved.status, TransferStatus.retrying);
      expect(moved.bytesTransferred, 7);
      expect(moved.request.id, 'transfer-0');
      expect(moved.failure, isNull);
    });

    test('returns null for a transition §9 forbids', () {
      expect(
        item(TransferStatus.created).transitionTo(TransferStatus.queued),
        isNull,
      );
      expect(
        item(
          TransferStatus.completed,
        ).transitionTo(TransferStatus.transferring),
        isNull,
      );
      expect(
        item(TransferStatus.cancelled).transitionTo(TransferStatus.queued),
        isNull,
      );
    });

    test('refuses to enter failed without a failure', () {
      // Silently inventing a cause would give the UI something to display that
      // nobody observed (AGENTS.md §83).
      expect(
        item(TransferStatus.transferring).transitionTo(TransferStatus.failed),
        isNull,
      );
    });

    test('refuses a failure on any transition that does not end in failed', () {
      // Dropping the cause would be just as wrong: the item would look
      // recovered while the caller still believes it failed.
      expect(
        item(TransferStatus.transferring).transitionTo(
          TransferStatus.completed,
          failure: TransferFailure.connectionLost,
        ),
        isNull,
      );
      expect(
        item(TransferStatus.transferring).transitionTo(
          TransferStatus.retrying,
          failure: TransferFailure.connectionLost,
        ),
        isNull,
      );
    });

    test('carries the failure on a transition to failed', () {
      final TransferItem failed =
          item(TransferStatus.transferring, bytesTransferred: 4).transitionTo(
            TransferStatus.failed,
            failure: TransferFailure.connectionLost,
          )!;

      expect(failed.status, TransferStatus.failed);
      expect(failed.failure, TransferFailure.connectionLost);
      expect(failed.bytesTransferred, 4);
      expect(failed.failure!.isRetryable, isTrue);
    });

    test('does not mutate the receiver', () {
      final TransferItem original = item(TransferStatus.transferring);
      original.transitionTo(TransferStatus.completed);

      expect(original.status, TransferStatus.transferring);
    });
  });

  group('progress', () {
    test('is real bytes over the declared size', () {
      final TransferItem half = item(
        TransferStatus.transferring,
        bytesTransferred: 5,
        sizeInBytes: 10,
      );

      expect(half.fraction, closeTo(0.5, 1e-9));
    });

    test('has no denominator when the platform never reported a size', () {
      // Indeterminate rather than a made-up percentage (AGENTS.md §20).
      final TransferItem unknown = item(
        TransferStatus.transferring,
        bytesTransferred: 5,
        sizeInBytes: null,
      );

      expect(unknown.totalBytes, isNull);
      expect(unknown.fraction, isNull);
    });

    test(
      'has no denominator for a zero-byte file instead of dividing by zero',
      () {
        final TransferItem empty = item(
          TransferStatus.transferring,
          bytesTransferred: 0,
          sizeInBytes: 0,
        );

        expect(empty.fraction, isNull);
      },
    );

    test('withProgress replaces the count but never the lifecycle state', () {
      final TransferItem progressed = item(
        TransferStatus.retrying,
        failure: TransferFailure.connectionLost,
      ).withProgress(3);

      expect(progressed.status, TransferStatus.retrying);
      expect(progressed.failure, TransferFailure.connectionLost);
      expect(progressed.bytesTransferred, 3);
    });
  });

  group('equality', () {
    test('covers status, bytes, request and failure', () {
      expect(item(TransferStatus.queued), item(TransferStatus.queued));
      expect(
        item(TransferStatus.queued) == item(TransferStatus.transferring),
        isFalse,
      );
      expect(
        item(TransferStatus.transferring, bytesTransferred: 1) ==
            item(TransferStatus.transferring, bytesTransferred: 2),
        isFalse,
      );
    });
  });
}
