import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:partilha/core/errors/failure.dart';
import 'package:partilha/core/logging/app_logger.dart';

/// A self-signed certificate generated on the fly, for tests only.
///
/// Generated with the `openssl` CLI because neither `dart:io` nor the platform
/// can create a certificate. This is deliberately test-only: on a device the
/// receiver needs a persistent per-device certificate, and how that is created is
/// a platform decision that is still open. Baking an `openssl` dependency into
/// the application would be wrong.
class TestSelfSignedCertificate {
  TestSelfSignedCertificate._(
    this.directory,
    this.certificatePath,
    this.keyPath,
  );

  final Directory directory;
  final String certificatePath;
  final String keyPath;

  /// The SHA-256 fingerprint of the DER encoding, as the transport computes it.
  late final String fingerprintHex = _fingerprintOf(certificatePath);

  /// Whether a certificate can be generated on this machine.
  ///
  /// The transport tests need `openssl`, which is present on the developer
  /// machines and on the CI runners but is not guaranteed everywhere, so a
  /// machine without it skips rather than fails.
  static Future<bool> isAvailable() async {
    try {
      final result = await Process.run('openssl', <String>['version']);
      return result.exitCode == 0;
    } on ProcessException {
      return false;
    }
  }

  /// Creates a self-signed certificate for [host] in a temporary directory.
  static Future<TestSelfSignedCertificate> create({
    String host = 'localhost',
  }) async {
    final directory = await Directory.systemTemp.createTemp('partilha_tls_');
    final certificatePath = '${directory.path}/cert.pem';
    final keyPath = '${directory.path}/key.pem';

    final result = await Process.run('openssl', <String>[
      'req',
      '-x509',
      '-newkey',
      'rsa:2048',
      '-nodes',
      '-keyout',
      keyPath,
      '-out',
      certificatePath,
      '-days',
      '1',
      '-subj',
      '/CN=$host',
      '-addext',
      'subjectAltName=DNS:$host',
    ]);

    if (result.exitCode != 0) {
      await directory.delete(recursive: true);
      throw StateError(
        'openssl failed to generate a test certificate: ${result.stderr}',
      );
    }

    return TestSelfSignedCertificate._(directory, certificatePath, keyPath);
  }

  /// A [SecurityContext] that trusts this certificate, standing in for the
  /// receiver's persistent identity.
  SecurityContext createServerContext() => SecurityContext()
    ..useCertificateChain(certificatePath)
    ..usePrivateKey(keyPath);

  void dispose() {
    if (directory.existsSync()) directory.deleteSync(recursive: true);
  }

  /// Reads the DER encoding and hashes it, matching the QR pin exactly.
  static String _fingerprintOf(String certificatePath) => sha256
      .convert(_derOf(certificatePath))
      .bytes
      .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
      .join();

  static Uint8List _derOf(String certificatePath) {
    final result = Process.runSync(
      'openssl',
      <String>['x509', '-in', certificatePath, '-outform', 'der'],
      // DER is binary, so stdout must stay raw bytes instead of being decoded
      // as UTF-8 text.
      stdoutEncoding: null,
    );
    if (result.exitCode != 0) {
      throw StateError(
        'openssl failed to read the certificate: ${result.stderr}',
      );
    }
    return Uint8List.fromList(result.stdout as List<int>);
  }
}

/// A logger that records instead of printing, so tests can assert on what the
/// transport reported without writing to stdout.
class RecordingLogger implements AppLogger {
  final List<LogCall> calls = <LogCall>[];

  List<String> get warnings =>
      calls.where((c) => c.level == 'warning').map((c) => c.message).toList();

  @override
  void debug(
    String message, {
    Map<String, Object?>? context,
    Object? error,
    StackTrace? stackTrace,
  }) => calls.add(LogCall('debug', message, context, error));

  @override
  void info(
    String message, {
    Map<String, Object?>? context,
    Object? error,
    StackTrace? stackTrace,
  }) => calls.add(LogCall('info', message, context, error));

  @override
  void warning(
    String message, {
    Map<String, Object?>? context,
    Object? error,
    StackTrace? stackTrace,
  }) => calls.add(LogCall('warning', message, context, error));

  @override
  void error(
    String message, {
    Map<String, Object?>? context,
    Object? error,
    StackTrace? stackTrace,
  }) => calls.add(LogCall('error', message, context, error));

  @override
  void failure(
    String message,
    Failure failure, {
    Map<String, Object?>? context,
    StackTrace? stackTrace,
  }) => calls.add(LogCall('failure', message, context, failure));
}

class LogCall {
  const LogCall(this.level, this.message, this.context, this.error);

  final String level;
  final String message;
  final Map<String, Object?>? context;
  final Object? error;
}
