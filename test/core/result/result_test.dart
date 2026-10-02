import 'package:flutter_test/flutter_test.dart';
import 'package:partilha/core/errors/failure.dart';
import 'package:partilha/core/result/result.dart';

void main() {
  group('Result.success', () {
    test('holds the value and reports success', () {
      const result = Result<int, Failure>.success(7);

      expect(result.isSuccess, isTrue);
      expect(result.isFailure, isFalse);
      expect(result.valueOrNull, 7);
      expect(result.errorOrNull, isNull);
    });
  });

  group('Result.failure', () {
    test('holds the failure and reports failure', () {
      const result = Result<int, Failure>.failure(
        StorageFailure.insufficientSpace,
      );

      expect(result.isFailure, isTrue);
      expect(result.isSuccess, isFalse);
      expect(result.valueOrNull, isNull);
      expect(result.errorOrNull, StorageFailure.insufficientSpace);
    });

    test('preserves the concrete failure subtype', () {
      const result = Result<int, NetworkFailure>.failure(
        NetworkFailure.connectionLost,
      );

      expect(result.errorOrNull, isA<NetworkFailure>());
    });
  });

  group('fold', () {
    test('calls onSuccess for a value', () {
      const result = Result<int, Failure>.success(3);

      expect(
        result.fold(onSuccess: (int v) => 'v$v', onFailure: _unusedFailure),
        'v3',
      );
    });

    test('calls onFailure for a failure', () {
      const result = Result<int, Failure>.failure(PermissionFailure.denied);

      expect(
        result.fold(
          onSuccess: _unusedSuccess,
          onFailure: (Failure f) => f.kind,
        ),
        'PermissionFailure',
      );
    });
  });

  group('map', () {
    test('transforms the value and keeps the type parameter', () {
      const result = Result<int, Failure>.success(4);

      final mapped = result.map((int v) => v * 2);

      expect(mapped.valueOrNull, 8);
    });

    test('does not run the transform on the failure path', () {
      const result = Result<int, Failure>.failure(
        StorageFailure.insufficientSpace,
      );
      var calls = 0;

      final mapped = result.map((int v) {
        calls++;
        return v * 2;
      });

      expect(calls, 0);
      expect(mapped.errorOrNull, StorageFailure.insufficientSpace);
    });

    test('widening the value type keeps the error usable', () {
      const result = Result<int, Failure>.success(1);

      final mapped = result.map<String>((int v) => 'value $v');

      expect(mapped.valueOrNull, 'value 1');
    });
  });

  group('mapError', () {
    test('transforms the failure and keeps the value usable', () {
      const result = Result<String, Failure>.failure(TransferFailure.cancelled);

      final mapped = result.mapError<NetworkFailure>(
        (Failure _) => NetworkFailure.connectionLost,
      );

      expect(mapped.errorOrNull, NetworkFailure.connectionLost);
    });

    test('does not run the transform on the success path', () {
      const result = Result<String, Failure>.success('ok');
      var calls = 0;

      final mapped = result.mapError<NetworkFailure>((Failure _) {
        calls++;
        return NetworkFailure.connectionLost;
      });

      expect(calls, 0);
      expect(mapped.valueOrNull, 'ok');
    });
  });

  group('value semantics', () {
    test('two successes with equal values are equal', () {
      const a = Result<int, Failure>.success(5);
      const b = Result<int, Failure>.success(5);

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('a success and a failure are never equal', () {
      const success = Result<int, Failure>.success(5);
      const failure = Result<int, Failure>.failure(NetworkFailure.unreachable);

      expect(success, isNot(equals(failure)));
    });
  });

  group('guardAsync', () {
    test('wraps a returned value as success', () async {
      final result = await guardAsync<int>(() async => 42);

      expect(result, isA<Success<int, Failure>>());
      expect(result.valueOrNull, 42);
    });

    test(
      'converts a thrown object into a non-retryable UnknownFailure',
      () async {
        final result = await guardAsync<int>(
          () async => throw const FormatException('bad frame'),
          context: const <String, Object?>{'stage': 'decode'},
        );

        expect(result.errorOrNull, isA<UnknownFailure>());
        expect(result.errorOrNull!.isRetryable, isFalse);
        expect(result.errorOrNull!.cause, isA<FormatException>());
        expect(result.errorOrNull!.context['stage'], 'decode');
        expect(result.errorOrNull!.userMessage, 'Something went wrong.');
      },
    );

    test('captures the stack trace for diagnostics', () async {
      final result = await guardAsync<void>(
        () async => throw StateError('boom'),
      );

      expect(result.errorOrNull!.context['stackTrace'], isA<String>());
    });
  });

  group('guard', () {
    test('wraps a returned value as success', () {
      final result = guard<int>(() => 9);

      expect(result.valueOrNull, 9);
    });

    test('converts a thrown object into a failure', () {
      final result = guard<int>(() => throw StateError('boom'));

      expect(result.errorOrNull, isA<UnknownFailure>());
    });
  });
}

String _unusedSuccess(int value) => 'success $value';

String _unusedFailure(Failure failure) => 'failure $failure';
