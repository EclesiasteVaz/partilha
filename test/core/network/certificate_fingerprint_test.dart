import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:partilha/core/errors/failure.dart';
import 'package:partilha/core/network/certificate_fingerprint.dart';

void main() {
  // The SHA-256 of an empty input, which is the one digest in this file that can
  // be checked against a value published anywhere rather than recomputed here.
  const emptySha256 =
      'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855';

  group('fromDer', () {
    test('produces the published SHA-256 of empty input', () {
      expect(CertificateFingerprint.fromDer(Uint8List(0)).hex, emptySha256);
    });

    test('is lowercase hex of exactly 64 characters', () {
      final fingerprint = CertificateFingerprint.fromDer(
        Uint8List.fromList(List<int>.filled(200, 0xAB)),
      );

      expect(fingerprint.hex, hasLength(CertificateFingerprint.hexLength));
      expect(fingerprint.hex, matches(RegExp(r'^[0-9a-f]{64}$')));
    });

    test('is stable for the same input', () {
      final der = Uint8List.fromList(<int>[1, 2, 3, 4, 5]);

      expect(
        CertificateFingerprint.fromDer(der),
        CertificateFingerprint.fromDer(der),
      );
    });

    test('differs when a single byte differs', () {
      final a = CertificateFingerprint.fromDer(
        Uint8List.fromList(<int>[1, 2, 3]),
      );
      final b = CertificateFingerprint.fromDer(
        Uint8List.fromList(<int>[1, 2, 4]),
      );

      expect(a, isNot(b));
    });
  });

  group('parse', () {
    test('accepts a well-formed fingerprint', () {
      final result = CertificateFingerprint.parse(emptySha256);

      expect(result.isSuccess, isTrue);
      expect(result.valueOrNull!.hex, emptySha256);
    });

    test('normalises uppercase to the canonical lowercase form', () {
      final result = CertificateFingerprint.parse(emptySha256.toUpperCase());

      expect(result.valueOrNull!.hex, emptySha256);
    });

    test('trims surrounding whitespace from a scanned code', () {
      final result = CertificateFingerprint.parse('  $emptySha256\n');

      expect(result.valueOrNull!.hex, emptySha256);
    });

    test('a truncated pin is rejected rather than accepted loosely', () {
      // The dangerous outcome is a pin that parses but verifies nothing, which
      // would leave the connection unpinned while still looking paired.
      final result = CertificateFingerprint.parse(emptySha256.substring(0, 63));

      expect(result.isFailure, isTrue);
      expect(result.errorOrNull, isA<ValidationFailure>());
    });

    test('an empty value is rejected', () {
      expect(CertificateFingerprint.parse('').isFailure, isTrue);
    });

    test('a non-hexadecimal value of the right length is rejected', () {
      final result = CertificateFingerprint.parse('z' * 64);

      expect(result.isFailure, isTrue);
    });

    test('an over-long value is rejected', () {
      expect(
        CertificateFingerprint.parse('${emptySha256}ff').isFailure,
        isTrue,
      );
    });
  });

  group('isValid', () {
    test('agrees with parse for every shape it is asked about', () {
      for (final raw in <String>[
        emptySha256,
        emptySha256.toUpperCase(),
        ' $emptySha256 ',
        emptySha256.substring(0, 10),
        '',
        'z' * 64,
      ]) {
        expect(
          CertificateFingerprint.isValid(raw),
          CertificateFingerprint.parse(raw).isSuccess,
          reason: 'disagreement for "$raw"',
        );
      }
    });
  });

  group('equality', () {
    test('two instances parsed from equivalent text are equal', () {
      final lower = CertificateFingerprint.parse(emptySha256).valueOrNull!;
      final upper = CertificateFingerprint.parse(
        emptySha256.toUpperCase(),
      ).valueOrNull!;

      expect(lower, upper);
      expect(lower.hashCode, upper.hashCode);
    });

    test('is not equal to a different type with a matching value', () {
      final fingerprint = CertificateFingerprint.parse(
        emptySha256,
      ).valueOrNull!;

      expect(fingerprint, isNot(emptySha256));
    });
  });
}
