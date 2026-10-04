import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:partilha/core/errors/failure.dart';
import 'package:partilha/core/result/result.dart';
import 'package:partilha/features/settings/domain/domain.dart';

void main() {
  group('create accepts what a user would expect to type', () {
    test('a plain name', () {
      final result = DeviceName.create('Kitchen phone');

      expect(result, isA<Success<DeviceName, Failure>>());
      expect(
        (result as Success<DeviceName, Failure>).value.value,
        'Kitchen phone',
      );
    });

    test('names with accents and non-Latin scripts', () {
      for (final input in <String>[
        'Café',
        '、Küche',
        'Οικία',
        'семейный',
        '📱',
      ]) {
        expect(
          DeviceName.create(input),
          isA<Success<DeviceName, Failure>>(),
          reason: '"$input" must be accepted',
        );
      }
    });

    test('a name of exactly the maximum length', () {
      final String input = 'a' * DeviceName.maxLength;

      expect(DeviceName.create(input), isA<Success<DeviceName, Failure>>());
    });
  });

  group('create trims before judging', () {
    test('surrounding whitespace is removed rather than stored', () {
      final result = DeviceName.create('  Kitchen phone \n');

      expect(
        (result as Success<DeviceName, Failure>).value.value,
        'Kitchen phone',
      );
    });

    test('a name that is only whitespace is rejected', () {
      expect(DeviceName.create('   \t '), isA<Err<DeviceName, Failure>>());
    });
  });

  group('create rejects what would break a peer', () {
    test('an empty name', () {
      expect(
        DeviceName.create(''),
        isA<Err<DeviceName, Failure>>().having(
          (Err<DeviceName, Failure> e) => e.error,
          'error',
          isA<ValidationFailure>(),
        ),
      );
    });

    test('a name over the limit, and reports it as non-retryable', () {
      final result = DeviceName.create('a' * (DeviceName.maxLength + 1));

      expect(result, isA<Err<DeviceName, Failure>>());
      final Err<DeviceName, Failure> err = result as Err<DeviceName, Failure>;
      expect(err.error, same(ValidationFailure.tooLong));
      expect(err.error.isRetryable, isFalse);
    });

    test(
      'control characters, including the newline that would split a TXT record',
      () {
        for (final String input in <String>[
          'a\nb',
          'a\rb',
          'a\tb',
          'a\u0000b',
        ]) {
          expect(
            DeviceName.create(input),
            isA<Err<DeviceName, Failure>>(),
            reason: '"$input" must be rejected',
          );
        }
      },
    );

    test('the failure carries a message meant for a user', () {
      final result = DeviceName.create('   ');

      final Err<DeviceName, Failure> err = result as Err<DeviceName, Failure>;
      expect(err.error.userMessage, isNotEmpty);
      expect(err.error.userMessage, isNot(contains('Exception')));
    });
  });

  group('equality is by value', () {
    test('two names built from the same text are equal', () {
      final DeviceName a =
          (DeviceName.create('Phone') as Success<DeviceName, Failure>).value;
      final DeviceName b =
          (DeviceName.create('Phone') as Success<DeviceName, Failure>).value;

      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('different names are not equal', () {
      final DeviceName a =
          (DeviceName.create('Phone') as Success<DeviceName, Failure>).value;
      final DeviceName b =
          (DeviceName.create('Tablet') as Success<DeviceName, Failure>).value;

      expect(a, isNot(b));
    });
  });

  group('fallback', () {
    test('is a constant so an unconfigured device still has a name', () {
      expect(DeviceName.fallback.value, isNotEmpty);
    });

    // Guards the §34 rule. A fallback derived from the machine would broadcast
    // its hostname to every device on the network.
    test('is not the machine hostname', () {
      expect(DeviceName.fallback.value, isNot(Platform.localHostname));
    });
  });
}
