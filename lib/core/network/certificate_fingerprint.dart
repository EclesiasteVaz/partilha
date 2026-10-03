import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:partilha/core/errors/failure.dart';
import 'package:partilha/core/result/result.dart';

/// The SHA-256 fingerprint of a device certificate, as lowercase hexadecimal.
///
/// This is the pin the sender verifies before it sends anything
/// (`docs/SECURITY.md` §26.1). It is computed over the certificate's **full DER
/// encoding**, not over its public key, which is what makes it a statement about
/// one specific certificate: replacing the certificate invalidates the pairing
/// and the user re-pairs. That is the accepted trade-off, recorded rather than
/// discovered later.
///
/// The value is canonical lowercase hex so that a fingerprint parsed from a QR
/// payload, one computed from a presented certificate and one stored in a
/// pairing all compare equal through plain string equality.
final class CertificateFingerprint {
  const CertificateFingerprint._(this.hex);

  /// Number of hex characters a SHA-256 fingerprint has.
  static const int hexLength = 64;

  static final RegExp _hexPattern = RegExp(r'^[0-9a-f]{64}$');

  /// The canonical lowercase hex representation.
  final String hex;

  /// Computes the fingerprint of [der], the raw DER encoding of a certificate.
  factory CertificateFingerprint.fromDer(Uint8List der) =>
      CertificateFingerprint._(_toHex(sha256.convert(der).bytes));

  /// Computes the fingerprint of the certificate the peer presented.
  factory CertificateFingerprint.fromCertificate(X509Certificate certificate) =>
      CertificateFingerprint.fromDer(certificate.der);

  /// Parses a fingerprint that arrived from outside the application, such as
  /// the QR payload.
  ///
  /// Case is normalised rather than rejected, because a QR scanner gives no
  /// guarantee about how the hex was typed. Length and alphabet are enforced,
  /// because a truncated or malformed pin must never silently degrade into
  /// "nothing to verify": it would leave the connection unpinned while still
  /// looking paired.
  static Result<CertificateFingerprint, Failure> parse(String raw) {
    final normalized = raw.trim().toLowerCase();
    if (!_hexPattern.hasMatch(normalized)) {
      return const Result.failure(ValidationFailure.malformed);
    }
    return Result.success(CertificateFingerprint._(normalized));
  }

  /// Whether [raw] can be parsed as a fingerprint.
  ///
  /// Lets the pairing layer reject a malformed QR payload before a connection is
  /// ever attempted, rather than failing during the handshake.
  static bool isValid(String raw) =>
      _hexPattern.hasMatch(raw.trim().toLowerCase());

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CertificateFingerprint && other.hex == hex;

  @override
  int get hashCode => hex.hashCode;

  @override
  String toString() => 'CertificateFingerprint($hex)';

  static String _toHex(List<int> bytes) =>
      bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
}
