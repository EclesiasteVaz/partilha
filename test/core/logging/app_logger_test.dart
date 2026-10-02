import 'package:flutter_test/flutter_test.dart';
import 'package:partilha/core/errors/failure.dart';
import 'package:partilha/core/logging/logging.dart';

void main() {
  late RecordingLogSink sink;
  late StructuredLogger logger;

  setUp(() {
    sink = RecordingLogSink();
    logger = StructuredLogger(sink: sink);
  });

  group('levels', () {
    test('emits every level when the threshold is debug', () {
      logger
        ..debug('d')
        ..info('i')
        ..warning('w')
        ..error('e');

      expect(sink.records.map((LogRecord r) => r.level), <LogLevel>[
        LogLevel.debug,
        LogLevel.info,
        LogLevel.warning,
        LogLevel.error,
      ]);
    });

    test('drops records below the threshold', () {
      final quiet = StructuredLogger(sink: sink, threshold: LogLevel.warning);

      quiet
        ..debug('d')
        ..info('i')
        ..warning('w')
        ..error('e');

      expect(sink.records.map((LogRecord r) => r.level), <LogLevel>[
        LogLevel.warning,
        LogLevel.error,
      ]);
    });

    test('the receiver is the threshold and the argument is the record', () {
      // Inclusive at the threshold itself.
      expect(LogLevel.warning.includes(LogLevel.warning), isTrue);
      // Below the threshold is dropped.
      expect(LogLevel.warning.includes(LogLevel.debug), isFalse);
      // Above the threshold is kept.
      expect(LogLevel.warning.includes(LogLevel.error), isTrue);
      // An error threshold drops warnings.
      expect(LogLevel.error.includes(LogLevel.warning), isFalse);
    });

    test('errors are never dropped, even at the highest threshold', () {
      final errorsOnly = StructuredLogger(
        sink: sink,
        threshold: LogLevel.error,
      );

      errorsOnly
        ..warning('w')
        ..error('e');

      expect(sink.records.single.level, LogLevel.error);
    });
  });

  group('failure()', () {
    test('always attaches the retry verdict', () {
      logger.failure('send failed', TransferFailure.connectionLost);

      final record = sink.records.single;
      expect(record.level, LogLevel.warning);
      expect(record.context['retryable'], isTrue);
      expect(record.context['failure'], contains('TransferFailure'));
      expect(record.context['userMessage'], 'The transfer was interrupted.');
    });

    test('marks a non-retryable failure as such', () {
      logger.failure('save failed', StorageFailure.insufficientSpace);

      expect(sink.records.single.context['retryable'], isFalse);
    });

    test('logs the cause without leaking it into userMessage', () {
      const failure = NetworkFailure(cause: _SocketStub('token=abc123'));

      logger.failure('connect failed', failure);

      final record = sink.records.single;
      expect(record.error, isA<_SocketStub>());
      expect(record.context['userMessage'], isNot(contains('abc123')));
    });

    test('carries a stack trace when given one', () {
      logger.failure(
        'connect failed',
        NetworkFailure.unreachable,
        stackTrace: StackTrace.current,
      );

      expect(sink.records.single.stackTrace, isNotNull);
    });
  });

  group('redaction', () {
    test('redacts a sensitive key', () {
      logger.info(
        'pairing',
        context: const <String, Object?>{'token': 'super-secret'},
      );

      expect(sink.records.single.context['token'], redactedPlaceholder);
    });

    test('matches sensitive keys case-insensitively and across separators', () {
      final scrubbed = redactSensitiveContext(const <String, Object?>{
        'deviceToken': 'a',
        'DEVICE_TOKEN': 'b',
        'x-auth-token': 'c',
        'UserPassword': 'd',
        'apiKey': 'e',
      });

      expect(scrubbed.values, everyElement(redactedPlaceholder));
    });

    test('scrubs nested maps', () {
      final scrubbed = redactSensitiveContext(const <String, Object?>{
        'request': <String, Object?>{'token': 'leaked', 'deviceName': 'studio'},
      });

      final nested = scrubbed['request']! as Map<String, Object?>;
      expect(nested['token'], redactedPlaceholder);
      expect(nested['deviceName'], 'studio');
    });

    test('scrubs maps inside lists', () {
      final scrubbed = redactSensitiveContext(const <String, Object?>{
        'peers': <Object?>[
          <String, Object?>{'token': 'leaked'},
        ],
      });

      final list = scrubbed['peers']! as List<Object?>;
      final first = list.single! as Map<String, Object?>;
      expect(first['token'], redactedPlaceholder);
    });

    test('leaves ordinary context untouched', () {
      logger.info(
        'discovery',
        context: const <String, Object?>{
          'deviceName': 'studio',
          'port': 47821,
          'capabilities': <String>['send', 'receive'],
        },
      );

      final record = sink.records.single;
      expect(record.context['deviceName'], 'studio');
      expect(record.context['port'], 47821);
      expect(record.context['capabilities'], <String>['send', 'receive']);
    });

    test('never mutates the caller map', () {
      final original = <String, Object?>{'token': 'keep'};

      redactSensitiveContext(original);

      expect(original['token'], 'keep');
    });

    test('an empty context stays empty', () {
      expect(redactSensitiveContext(const <String, Object?>{}), isEmpty);
    });
  });

  group('record', () {
    test('renders level, timestamp and message', () {
      logger.info('discovery started');

      final rendered = sink.records.single.toString();
      expect(rendered, startsWith('[INFO]'));
      expect(rendered, contains('discovery started'));
    });

    test('uses the injected clock', () {
      final fixed = StructuredLogger(
        sink: sink,
        clock: () => DateTime.utc(2026, 10, 2, 12),
      );

      fixed.info('at a known time');

      expect(sink.records.single.timestamp, DateTime.utc(2026, 10, 2, 12));
    });
  });
}

final class _SocketStub implements Exception {
  const _SocketStub(this.details);

  final String details;

  @override
  String toString() => 'SocketStub: $details';
}
