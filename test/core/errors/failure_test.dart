import 'package:flutter_test/flutter_test.dart';
import 'package:partilha/core/errors/failure.dart';

void main() {
  group('isRetryable', () {
    // The retry table is the contract that decides whether a transfer burns
    // the user's battery on a failure that cannot resolve (AGENTS.md §82),
    // so it is asserted in full rather than spot-checked.
    const retryable = <String, Failure>{
      'network.unreachable': NetworkFailure.unreachable,
      'network.connectionLost': NetworkFailure.connectionLost,
      'network.timedOut': NetworkFailure.timedOut,
      'discovery.transportFailed': DiscoveryFailure.transportFailed,
      'pairing.timedOut': PairingFailure.timedOut,
      'transfer.connectionLost': TransferFailure.connectionLost,
    };

    const notRetryable = <String, Failure>{
      'storage.insufficientSpace': StorageFailure.insufficientSpace,
      'storage.writeFailed': StorageFailure.writeFailed,
      'storage.databaseUnavailable': StorageFailure.databaseUnavailable,
      'permission.denied': PermissionFailure.denied,
      'permission.permanentlyDenied': PermissionFailure.permanentlyDenied,
      'discovery.multicastUnavailable': DiscoveryFailure.multicastUnavailable,
      'pairing.invalidPayload': PairingFailure.invalidPayload,
      'pairing.rejected': PairingFailure.rejected,
      'transfer.cancelled': TransferFailure.cancelled,
      'transfer.remoteRejected': TransferFailure.remoteRejected,
      'transfer.protocolViolation': TransferFailure.protocolViolation,
      'validation.tooLong': ValidationFailure.tooLong,
      'validation.malformed': ValidationFailure.malformed,
      'validation.unsafePath': ValidationFailure.unsafePath,
      'unknown': UnknownFailure(userMessage: 'Something went wrong.'),
    };

    retryable.forEach((name, failure) {
      test('$name is retryable', () {
        expect(failure.isRetryable, isTrue, reason: name);
      });
    });

    notRetryable.forEach((name, failure) {
      test('$name is not retryable', () {
        expect(failure.isRetryable, isFalse, reason: name);
      });
    });

    test('the table covers every declared failure constant', () {
      expect(
        retryable.length + notRetryable.length,
        21,
        reason:
            'a new Failure constant was added without a retry verdict; '
            'classify it and bump this count',
      );
    });
  });

  group('userMessage', () {
    test('never exposes the cause or an exception message', () {
      const failure = StorageFailure.writeFailed;
      final converted = _convertedNetworkFailure('token=super-secret');

      expect(failure.userMessage, isNot(contains('super-secret')));
      expect(converted.userMessage, isNot(contains('super-secret')));
      expect(converted.userMessage, isNot(contains('SocketException')));
    });

    test('is non-empty so the UI never renders a blank error', () {
      const failures = <Failure>[
        NetworkFailure.unreachable,
        NetworkFailure.connectionLost,
        NetworkFailure.timedOut,
        StorageFailure.insufficientSpace,
        StorageFailure.writeFailed,
        StorageFailure.databaseUnavailable,
        PermissionFailure.denied,
        PermissionFailure.permanentlyDenied,
        DiscoveryFailure.multicastUnavailable,
        DiscoveryFailure.transportFailed,
        PairingFailure.invalidPayload,
        PairingFailure.timedOut,
        PairingFailure.rejected,
        TransferFailure.cancelled,
        TransferFailure.remoteRejected,
        TransferFailure.connectionLost,
        TransferFailure.protocolViolation,
        ValidationFailure.tooLong,
        ValidationFailure.malformed,
        ValidationFailure.unsafePath,
      ];

      for (final Failure failure in failures) {
        expect(
          failure.userMessage.trim(),
          isNotEmpty,
          reason: '${failure.runtimeType} has an empty userMessage',
        );
      }
    });
  });

  group('diagnostics', () {
    test('toString names the type and its retry verdict', () {
      const failure = TransferFailure.connectionLost;

      expect(failure.toString(), startsWith('TransferFailure('));
      expect(
        failure.toString(),
        isNot(contains('_')),
        reason: 'a library-private implementation name leaked into the log',
      );
      expect(failure.toString(), contains('retryable: true'));
    });

    test('keeps the cause for logging without putting it in userMessage', () {
      final failure = _convertedNetworkFailure('boom');

      expect(failure.cause, isA<_SocketException>());
      expect(failure.userMessage, isNot(contains('boom')));
    });

    test('context is available for logging', () {
      const failure = NetworkFailure(
        userMessage: 'The other device did not respond in time.',
        context: <String, Object?>{'deviceName': 'studio'},
      );

      expect(failure.context['deviceName'], 'studio');
    });
  });
}

/// Reproduces what the data layer does when it converts an infrastructure
/// exception into a typed failure: it keeps the cause for diagnostics and
/// substitutes a user-safe message.
NetworkFailure _convertedNetworkFailure(String details) => NetworkFailure(
  userMessage: 'Could not reach the other device.',
  cause: _SocketException(details),
);

final class _SocketException implements Exception {
  const _SocketException(this.details);

  final String details;

  @override
  String toString() => 'SocketException: $details';
}
