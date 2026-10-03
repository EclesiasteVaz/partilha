import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:partilha/core/errors/failure.dart';
import 'package:partilha/core/network/certificate_fingerprint.dart';
import 'package:partilha/core/network/dart_io_websocket_transport.dart';
import 'package:partilha/core/network/transport_frame.dart';
import 'package:partilha/core/network/websocket_transport.dart';

import 'test_tls_certificate.dart';

/// Exercises the transport against a real TLS WebSocket server.
///
/// A mocked socket would only test the mock. What matters here is that a
/// certificate which does not match the pin is genuinely refused, and that the
/// frame split and the size limit survive a real WebSocket.
void main() {
  // Generated with the openssl CLI, so these tests can only run where it is
  // installed. Skipping is reported rather than silently passing. Resolved in
  // setUpAll, before any setUp runs.
  late bool openssl;

  late TestSelfSignedCertificate certificate;
  late HttpServer server;
  late Completer<WebSocket?> accepted;
  late RecordingLogger logger;
  late DartIoWebSocketTransport transport;

  /// Server-side listeners, cancelled in tearDown so no subscription outlives
  /// its test (`AGENTS.md` §81).
  final List<StreamSubscription<dynamic>> listeners =
      <StreamSubscription<dynamic>>[];

  void listen(WebSocket socket, void Function(Object?) onData) =>
      listeners.add(socket.listen(onData));

  /// The accepted server-side socket, or a clear failure when none was reached.
  Future<WebSocket> peer() async {
    final socket = await accepted.future;
    if (socket == null) {
      throw StateError('no WebSocket connection reached the server');
    }
    return socket;
  }

  Future<void> startServer() async {
    server = await HttpServer.bindSecure(
      InternetAddress.loopbackIPv4,
      0,
      certificate.createServerContext(),
    );
    // Serves the first upgrade and tolerates never receiving one: a rejected
    // pin fails the TLS handshake before any HTTP request exists, and that is a
    // normal outcome here rather than an error.
    accepted = Completer<WebSocket?>();
    unawaited(
      server
          .forEach((request) async {
            if (!accepted.isCompleted) {
              accepted.complete(await WebSocketTransformer.upgrade(request));
            }
          })
          .catchError((Object _) {
            if (!accepted.isCompleted) accepted.complete(null);
          }),
    );
  }

  TransportTarget target({String? pinHex}) => TransportTarget(
    host: 'localhost',
    port: server.port,
    certificateFingerprint: CertificateFingerprint.parse(
      pinHex ?? certificate.fingerprintHex,
    ).valueOrNull!,
  );

  /// Subscribes immediately so no event can slip through before a test starts
  /// waiting for it, which a broadcast stream would otherwise allow.
  EventRecorder recorder() => EventRecorder(transport.events);

  setUpAll(() async {
    openssl = await TestSelfSignedCertificate.isAvailable();
    if (!openssl) {
      markTestSkipped(
        'openssl is not installed, so no certificate can be '
        'generated for the TLS server',
      );
      return;
    }
    certificate = await TestSelfSignedCertificate.create();
  });

  tearDownAll(() async {
    if (openssl) certificate.dispose();
  });

  setUp(() async {
    if (!openssl) return;
    logger = RecordingLogger();
    await startServer();
    transport = DartIoWebSocketTransport(logger);
  });

  tearDown(() async {
    if (!openssl) return;
    await transport.close();
    for (final listener in listeners) {
      await listener.cancel();
    }
    listeners.clear();
    await server.close(force: true);
  });

  group('certificate pinning', () {
    test('connects when the presented certificate matches the pin', () async {
      final result = await transport.connect(target());

      expect(result.isSuccess, isTrue);
      expect(transport.isConnected, isTrue);
    });

    test('refuses a certificate that does not match the pin, rather than '
        'connecting unverified', () async {
      final result = await transport.connect(target(pinHex: 'a' * 64));

      expect(result.isSuccess, isFalse);
      expect(
        result.errorOrNull,
        isA<PairingFailure>(),
        reason: 'a pin mismatch must not look like a transport problem',
      );
      expect(transport.isConnected, isFalse);
    });

    test('logs the mismatch for diagnosis', () async {
      await transport.connect(target(pinHex: 'b' * 64));

      expect(
        logger.warnings,
        contains('Certificate does not match the pinned fingerprint'),
      );
    });

    test('a pin mismatch is not reported as an unreachable peer, so a retry '
        'cannot bury it', () async {
      final result = await transport.connect(target(pinHex: 'c' * 64));

      expect(result.errorOrNull, isNot(isA<NetworkFailure>()));
    });

    test('reports an unreachable peer as a network failure', () async {
      final result = await transport.connect(
        TransportTarget(
          host: 'localhost',
          port: 1,
          certificateFingerprint: CertificateFingerprint.parse(
            certificate.fingerprintHex,
          ).valueOrNull!,
        ),
      );

      expect(result.isFailure, isTrue);
      expect(result.errorOrNull, isA<NetworkFailure>());
    });
  });

  group('frame classification', () {
    test('a text frame arrives as control traffic', () async {
      await transport.connect(target());
      final events = recorder();
      final serverSocket = await peer();
      addTearDown(serverSocket.close);
      addTearDown(serverSocket.close);

      final payload = jsonEncode(<String, String>{'type': 'ping'});
      serverSocket.add(payload);

      expect((await events.next<ControlReceived>()).payload, payload);
    });

    test('a binary frame arrives as data, byte for byte', () async {
      await transport.connect(target());
      final events = recorder();
      final serverSocket = await peer();
      addTearDown(serverSocket.close);
      addTearDown(serverSocket.close);
      final payload = Uint8List.fromList(
        List<int>.generate(512, (i) => i % 256),
      );

      serverSocket.add(payload);

      expect((await events.next<DataReceived>()).bytes, payload);
    });

    test('sending control writes a text frame, not base64', () async {
      await transport.connect(target());
      final serverSocket = await peer();
      addTearDown(serverSocket.close);
      addTearDown(serverSocket.close);
      final seen = <Object?>[];
      listen(serverSocket, seen.add);

      await transport.sendControl('{"type":"ping"}');
      await pumpEventQueue();

      expect(seen, contains('{"type":"ping"}'));
    });

    test('sending data writes a binary frame with the bytes intact', () async {
      await transport.connect(target());
      final serverSocket = await peer();
      addTearDown(serverSocket.close);
      addTearDown(serverSocket.close);
      final seen = <Object?>[];
      listen(serverSocket, seen.add);
      final payload = Uint8List.fromList(List<int>.filled(1024, 7));

      await transport.sendData(payload);
      await pumpEventQueue();

      final received = seen.whereType<Uint8List>().toList();
      expect(received, isNotEmpty);
      expect(received.first, payload);
    });
  });

  group('frame size limit', () {
    test('the limit is 64 KiB', () {
      expect(kMaxFrameBytes, 64 * 1024);
    });

    test('refuses to send a chunk larger than the limit', () async {
      await transport.connect(target());
      await peer();

      final result = await transport.sendData(Uint8List(kMaxFrameBytes + 1));

      expect(result.isFailure, isTrue);
      expect(result.errorOrNull, isA<TransferFailure>());
    });

    test('accepts a chunk exactly at the limit', () async {
      await transport.connect(target());
      await peer();

      expect(
        (await transport.sendData(Uint8List(kMaxFrameBytes))).isSuccess,
        isTrue,
      );
    });

    test('an oversized incoming frame is dropped, never delivered, and closes '
        'the connection', () async {
      await transport.connect(target());
      final events = recorder();
      final serverSocket = await peer();
      addTearDown(serverSocket.close);
      addTearDown(serverSocket.close);

      serverSocket.add(Uint8List(kMaxFrameBytes + 1));

      expect(
        (await events.next<OversizedFrame>()).actualBytes,
        kMaxFrameBytes + 1,
      );
      expect(
        events.received.whereType<DataReceived>(),
        isEmpty,
        reason: 'an oversized frame must never reach the transfer layer',
      );
      expect(await events.next<TransportDisconnected>(), isNotNull);
    });
  });

  group('sendStream', () {
    test('streams every chunk in order', () async {
      await transport.connect(target());
      final serverSocket = await peer();
      addTearDown(serverSocket.close);
      addTearDown(serverSocket.close);
      final received = <int>[];
      listen(serverSocket, (event) {
        if (event is Uint8List) received.addAll(event);
      });
      final chunks = <List<int>>[
        List<int>.filled(16, 1),
        List<int>.filled(16, 2),
        List<int>.filled(16, 3),
      ];

      final result = await transport.sendStream(Stream.fromIterable(chunks));

      expect(result.isSuccess, isTrue);
      await pumpEventQueue();
      expect(received, <int>[...chunks[0], ...chunks[1], ...chunks[2]]);
    });

    test('rejects a source chunk larger than the limit', () async {
      await transport.connect(target());
      await peer();

      final result = await transport.sendStream(
        Stream<List<int>>.value(Uint8List(kMaxFrameBytes + 1)),
      );

      expect(result.isFailure, isTrue);
      expect(result.errorOrNull, isA<TransferFailure>());
    });

    test(
      'cancellation is reported as cancelled, not as a lost connection',
      () async {
        await transport.connect(target());
        await peer();
        final cancel = Completer<void>();

        final sending = transport.sendStream(
          Stream<List<int>>.periodic(
            const Duration(milliseconds: 5),
            (_) => Uint8List(8),
          ),
          stop: cancel.future,
        );
        cancel.complete();
        final result = await sending;

        expect(result.errorOrNull, TransferFailure.cancelled);
        expect(
          result.errorOrNull,
          isNot(isA<NetworkFailure>()),
          reason: 'a local cancellation must not look like a network fault',
        );
      },
    );

    test('a second concurrent stream is refused, because transfers are '
        'serialized', () async {
      await transport.connect(target());
      await peer();
      final cancel = Completer<void>();
      final never = Completer<void>();

      final first = transport.sendStream(
        Stream<List<int>>.periodic(
          const Duration(milliseconds: 5),
          (_) => Uint8List(8),
        ),
        stop: cancel.future,
      );
      // Give the first stream time to claim the connection.
      await Future<void>.delayed(const Duration(milliseconds: 20));

      final second = await transport.sendStream(
        Stream<List<int>>.value(Uint8List(8)),
      );

      expect(second.isFailure, isTrue);
      cancel.complete();
      never.complete();
      await first;
    });

    test('a control frame during a file stream is a protocol violation, not a '
        'message', () async {
      await transport.connect(target());
      final events = recorder();
      final serverSocket = await peer();
      addTearDown(serverSocket.close);
      addTearDown(serverSocket.close);
      final cancel = Completer<void>();

      final sending = transport.sendStream(
        Stream<List<int>>.periodic(
          const Duration(milliseconds: 5),
          (_) => Uint8List(8),
        ),
        stop: cancel.future,
      );
      await Future<void>.delayed(const Duration(milliseconds: 30));
      serverSocket.add('{"type":"progress"}');

      expect(await events.next<ControlDuringDataStream>(), isNotNull);
      cancel.complete();
      await sending;
    });
  });

  group('lifecycle', () {
    test('refuses to send once closed', () async {
      await transport.connect(target());
      await peer();
      await transport.close();

      expect((await transport.sendControl('{}')).isFailure, isTrue);
      expect((await transport.sendData(<int>[1])).isFailure, isTrue);
    });

    test('closing twice is safe', () async {
      await transport.connect(target());
      await peer();

      await transport.close();
      await transport.close();

      expect(transport.isConnected, isFalse);
    });

    test(
      'reports an orderly close as a disconnect rather than a failure',
      () async {
        await transport.connect(target());
        final events = recorder();
        final serverSocket = await peer();
        addTearDown(serverSocket.close);
        addTearDown(serverSocket.close);

        await serverSocket.close();

        expect((await events.next<TransportDisconnected>()).reason, isNull);
      },
    );
  });
}

/// Collects transport events and lets a test await the next one of a type.
class EventRecorder {
  EventRecorder(Stream<TransportEvent> stream) {
    addTearDown(stream.listen(_record).cancel);
  }

  final List<TransportEvent> received = <TransportEvent>[];
  final Map<Type, Completer<TransportEvent>> _waiting =
      <Type, Completer<TransportEvent>>{};

  void _record(TransportEvent event) {
    received.add(event);
    final completer = _waiting.remove(event.runtimeType);
    if (completer != null && !completer.isCompleted) completer.complete(event);
  }

  /// Completes with the next event of type [T], or immediately if one already
  /// arrived.
  Future<T> next<T extends TransportEvent>() {
    for (final event in received) {
      if (event is T) return Future<T>.value(event);
    }
    final completer = Completer<TransportEvent>();
    _waiting[T] = completer;
    return completer.future.then((event) => event as T);
  }
}
