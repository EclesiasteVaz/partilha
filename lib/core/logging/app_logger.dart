import 'package:partilha/core/errors/failure.dart';

/// Severity of a [LogRecord].
///
/// Ordered from least to most severe so a sink can filter by threshold.
enum LogLevel {
  debug('DEBUG'),
  info('INFO'),
  warning('WARNING'),
  error('ERROR');

  const LogLevel(this.label);

  final String label;

  /// Whether a record at [level] should be emitted when the threshold is this.
  bool includes(LogLevel level) => level.index >= index;
}

/// One emitted log entry.
///
/// Immutable so a record can be handed to a background sink without the caller
/// mutating it afterwards (`AGENTS.md` §21).
class LogRecord {
  const LogRecord({
    required this.level,
    required this.message,
    required this.timestamp,
    this.context = const <String, Object?>{},
    this.error,
    this.stackTrace,
  });

  final LogLevel level;

  /// Developer-facing description. Free text, but must not embed secrets
  /// (`AGENTS.md` §52).
  final String message;

  final DateTime timestamp;

  /// Structured key/value detail.
  ///
  /// Keys matching [sensitiveContextKeys] are replaced with `[redacted]` before
  /// the record reaches any sink.
  final Map<String, Object?> context;

  /// The original exception, when one caused this record.
  ///
  /// Its `toString()` is logged, never the message shown to users
  /// (`AGENTS.md` §52, §83).
  final Object? error;

  final StackTrace? stackTrace;

  @override
  String toString() {
    final buffer = StringBuffer()
      ..write('[${level.label}] ')
      ..write(timestamp.toIso8601String())
      ..write(' ')
      ..write(message);

    if (context.isNotEmpty) {
      buffer.write(' $context');
    }
    if (error != null) {
      buffer.write(' error=$error');
    }
    return buffer.toString();
  }
}

/// Context keys whose values are replaced with `[redacted]`.
///
/// Deliberately conservative: it matches on substrings, so `deviceToken`,
/// `auth_token` and `X-TOKEN` are all covered. A key that should never be
/// logged but is not listed here will leak, so add it rather than renaming the
/// call site.
const Set<String> sensitiveContextKeys = <String>{
  'token',
  'secret',
  'password',
  'passphrase',
  'credential',
  'authorization',
  'apikey',
  'privatekey',
  'certificate',
};

/// The placeholder substituted for a sensitive value.
const String redactedPlaceholder = '[redacted]';

/// Returns [context] with every sensitive value replaced.
///
/// A key is considered sensitive when any of [sensitiveContextKeys] appears in
/// its lowercased name. Nested maps are scrubbed too, because the interesting
/// secrets are usually one level down inside a request or payload map.
Map<String, Object?> redactSensitiveContext(Map<String, Object?> context) {
  if (context.isEmpty) {
    return const <String, Object?>{};
  }

  final scrubbed = <String, Object?>{};
  for (final MapEntry(key: key, value: value) in context.entries) {
    if (_isSensitiveKey(key)) {
      scrubbed[key] = redactedPlaceholder;
      continue;
    }
    scrubbed[key] = switch (value) {
      final Map<String, Object?> nested => redactSensitiveContext(nested),
      final List<Object?> list =>
        list
            .map(
              (Object? item) => switch (item) {
                final Map<String, Object?> nested => redactSensitiveContext(
                  nested,
                ),
                _ => item,
              },
            )
            .toList(growable: false),
      _ => value,
    };
  }
  return scrubbed;
}

bool _isSensitiveKey(String key) {
  final normalized = key.toLowerCase().replaceAll(RegExp('[^a-z0-9]'), '');
  for (final String marker in sensitiveContextKeys) {
    if (normalized.contains(marker)) {
      return true;
    }
  }
  return false;
}

/// Destination for [LogRecord]s.
///
/// Kept as an interface so the console implementation can be replaced by a
/// file or crash-reporting sink without touching call sites, and so tests can
/// capture records instead of writing to stdout (`AGENTS.md` §17).
abstract interface class LogSink {
  void write(LogRecord record);
}

/// The application's logging contract.
///
/// Logging goes through this rather than `print()` so that level filtering and
/// redaction are enforced in one place (`AGENTS.md` §52).
abstract interface class AppLogger {
  /// Records fine-grained tracing. Compiled out of release builds by the
  /// default threshold, not by call sites.
  void debug(
    String message, {
    Map<String, Object?> context,
    Object? error,
    StackTrace? stackTrace,
  });

  /// Records a normal, expected event.
  void info(
    String message, {
    Map<String, Object?> context,
    Object? error,
    StackTrace? stackTrace,
  });

  /// Records something unexpected that the application recovered from.
  void warning(
    String message, {
    Map<String, Object?> context,
    Object? error,
    StackTrace? stackTrace,
  });

  /// Records a failure the application could not recover from.
  void error(
    String message, {
    Map<String, Object?> context,
    Object? error,
    StackTrace? stackTrace,
  });

  /// Records a [Failure] together with its retryability.
  ///
  /// Typed as [Failure] rather than `Object` so the retry classification is
  /// always attached. Without it, a logged failure gives no hint whether the
  /// operation deserves another attempt, which is the distinction `AGENTS.md`
  /// §82 requires.
  void failure(
    String message,
    Failure failure, {
    Map<String, Object?> context,
    StackTrace? stackTrace,
  });
}

/// Writes records through [sink], dropping anything below [threshold].
///
/// Redaction happens here rather than at each call site, so no call site can
/// forget it.
class StructuredLogger implements AppLogger {
  factory StructuredLogger({
    required LogSink sink,
    LogLevel threshold = LogLevel.debug,
    DateTime Function()? clock,
  }) => StructuredLogger._(sink, threshold, clock ?? DateTime.now);

  /// Named initializers cannot be private, so the public factory above exists
  /// only to hand off to this one.
  StructuredLogger._(this._sink, this._threshold, this._clock);

  final LogSink _sink;
  final LogLevel _threshold;
  final DateTime Function() _clock;

  @override
  void debug(
    String message, {
    Map<String, Object?> context = const <String, Object?>{},
    Object? error,
    StackTrace? stackTrace,
  }) => _emit(
    LogLevel.debug,
    message,
    context: context,
    error: error,
    stackTrace: stackTrace,
  );

  @override
  void info(
    String message, {
    Map<String, Object?> context = const <String, Object?>{},
    Object? error,
    StackTrace? stackTrace,
  }) => _emit(
    LogLevel.info,
    message,
    context: context,
    error: error,
    stackTrace: stackTrace,
  );

  @override
  void warning(
    String message, {
    Map<String, Object?> context = const <String, Object?>{},
    Object? error,
    StackTrace? stackTrace,
  }) => _emit(
    LogLevel.warning,
    message,
    context: context,
    error: error,
    stackTrace: stackTrace,
  );

  @override
  void error(
    String message, {
    Map<String, Object?> context = const <String, Object?>{},
    Object? error,
    StackTrace? stackTrace,
  }) => _emit(
    LogLevel.error,
    message,
    context: context,
    error: error,
    stackTrace: stackTrace,
  );

  @override
  void failure(
    String message,
    Failure failure, {
    Map<String, Object?> context = const <String, Object?>{},
    StackTrace? stackTrace,
  }) => _emit(
    LogLevel.warning,
    message,
    context: <String, Object?>{
      ...context,
      'failure': failure.toString(),
      'userMessage': failure.userMessage,
      'retryable': failure.isRetryable,
    },
    error: failure.cause,
    stackTrace: stackTrace,
  );

  void _emit(
    LogLevel level,
    String message, {
    required Map<String, Object?> context,
    Object? error,
    StackTrace? stackTrace,
  }) {
    // `includes` is defined on the threshold, so the receiver must be the
    // configured threshold and the argument the record being considered.
    if (!_threshold.includes(level)) {
      return;
    }
    _sink.write(
      LogRecord(
        level: level,
        message: message,
        timestamp: _clock(),
        context: redactSensitiveContext(context),
        error: error,
        stackTrace: stackTrace,
      ),
    );
  }
}

/// Writes to stdout.
///
/// Acceptable for development and tests. Production builds should substitute a
/// sink that writes to the platform log rather than the console.
class ConsoleLogSink implements LogSink {
  const ConsoleLogSink();

  @override
  void write(LogRecord record) {
    // ignore: avoid_print
    print(record);
  }
}

/// Captures records in memory. Intended for tests.
class RecordingLogSink implements LogSink {
  final List<LogRecord> records = <LogRecord>[];

  @override
  void write(LogRecord record) {
    records.add(record);
  }

  void clear() {
    records.clear();
  }
}
