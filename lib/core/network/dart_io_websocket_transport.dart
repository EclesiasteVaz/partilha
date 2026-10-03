import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:partilha/core/errors/failure.dart';
import 'package:partilha/core/logging/app_logger.dart';
import 'package:partilha/core/network/certificate_fingerprint.dart';
import 'package:partilha/core/network/transport_frame.dart';
import 'package:partilha/core/network/websocket_transport.dart';
import 'package:partilha/core/result/result.dart';

/// `dart:io` implementation of [WebSocketTransport].
///
/// The only file in the application that touches `WebSocket`, `HttpClient` or
/// `X509Certificate`.
final class DartIoWebSocketTransport implements WebSocketTransport {
  DartIoWebSocketTransport(this._logger);

  final AppLogger _logger;

  final StreamController<TransportEvent> _events =
      StreamController<TransportEvent>.broadcast();

  WebSocket? _socket;

  /// Owned by the connection and closed with it.
  ///
  /// `WebSocket.connect` needs a client to reach the socket, and an `HttpClient`
  /// holds a connection pool that would otherwise keep the process alive.
  HttpClient? _httpClient;

  StreamSubscription<Object?>? _subscription;
  StreamSubscription<List<int>>? _sourceSubscription;
  Completer<void>? _streamStopped;

  bool _dataStreamActive = false;
  bool _closed = false;

  @override
  Stream<TransportEvent> get events => _events.stream;

  @override
  bool get isConnected => _socket != null && !_closed;

  @override
  Future<Result<void, Failure>> connect(TransportTarget target) async {
    if (isConnected) {
      return const Result.failure(NetworkFailure.connectionLost);
    }

    final fingerprint = target.certificateFingerprint;
    final client = HttpClient(context: SecurityContext())
      // An empty trust store, deliberately. Platform roots must not be able to
      // vouch for a device, and with nothing trusted the callback below is
      // reached for every connection instead of only for certificates some
      // platform happened to reject.
      ..badCertificateCallback = (certificate, _, _) =>
          _matchesPin(certificate, fingerprint);

    // Declared outside the try so that a socket obtained but not yet adopted is
    // still closed when a later step fails.
    WebSocket? websocket;
    try {
      websocket = await WebSocket.connect(
        'wss://${target.host}:${target.port}/',
        customClient: client,
      );

      _httpClient = client;
      _socket = websocket;

      _subscription = websocket.listen(
        _onFrame,
        onError: (Object error, StackTrace stackTrace) {
          _logger.warning(
            'Transport error',
            error: error,
            stackTrace: stackTrace,
          );
          _fail(NetworkFailure.connectionLost);
        },
        onDone: () => _fail(null),
        cancelOnError: false,
      );

      _logger.debug(
        'Transport connected',
        context: <String, Object?>{'host': target.host, 'port': target.port},
      );
      _events.add(const TransportConnected());
      return const Result.success(null);
    } on HandshakeException catch (error) {
      await websocket?.close();
      client.close(force: true);
      // Almost always a pin mismatch: the socket connected but the certificate
      // did not verify. Reporting it as an unreachable peer would hide a
      // security-relevant event behind a retry.
      _logger.warning(
        'TLS handshake rejected',
        context: <String, Object?>{'host': target.host, 'port': target.port},
        error: error,
      );
      return Result.failure(
        PairingFailure(
          cause: error,
          context: const <String, Object?>{
            'reason': 'certificate did not match the pinned fingerprint',
          },
        ),
      );
    } on SocketException catch (error) {
      await websocket?.close();
      client.close(force: true);
      _logger.warning(
        'Transport could not connect',
        context: <String, Object?>{'host': target.host, 'port': target.port},
        error: error,
      );
      return Result.failure(
        NetworkFailure(
          cause: error,
          context: <String, Object?>{
            'reason': error.message,
            if (error.osError != null) 'osError': error.osError!.message,
          },
        ),
      );
    }
  }

  @override
  Future<Result<void, Failure>> sendControl(String json) async {
    final socket = _socket;
    if (socket == null || _closed) {
      return const Result.failure(NetworkFailure.connectionLost);
    }
    if (_dataStreamActive || json.length > kMaxFrameBytes) {
      return const Result.failure(TransferFailure.protocolViolation);
    }
    socket.add(json);
    return const Result.success(null);
  }

  @override
  Future<Result<void, Failure>> sendData(List<int> bytes) async {
    final socket = _socket;
    if (socket == null || _closed) {
      return const Result.failure(NetworkFailure.connectionLost);
    }
    if (bytes.length > kMaxFrameBytes) {
      return const Result.failure(TransferFailure.protocolViolation);
    }
    socket.add(bytes is Uint8List ? bytes : Uint8List.fromList(bytes));
    return const Result.success(null);
  }

  @override
  Future<Result<void, Failure>> sendStream(
    Stream<List<int>> source, {
    Future<void>? stop,
  }) async {
    final socket = _socket;
    if (socket == null || _closed) {
      return const Result.failure(NetworkFailure.connectionLost);
    }
    // Transfers are serialized, so a second stream on one connection would be
    // indistinguishable from a continuation of the first
    // (`docs/PROTOCOL.md` §33.6).
    if (_dataStreamActive) {
      return const Result.failure(TransferFailure.protocolViolation);
    }

    final stopped = Completer<void>();
    _streamStopped = stopped;
    _dataStreamActive = true;

    try {
      final completer = Completer<Result<void, Failure>>();

      _sourceSubscription = source.listen(
        (chunk) {
          if (chunk.length > kMaxFrameBytes) {
            // Refuse rather than split: silently splitting would put bytes on the
            // wire that the caller never framed.
            if (!completer.isCompleted) {
              completer.complete(
                const Result<void, Failure>.failure(
                  TransferFailure.protocolViolation,
                ),
              );
            }
            return;
          }
          socket.add(chunk is Uint8List ? chunk : Uint8List.fromList(chunk));
        },
        onError: (Object error, StackTrace stackTrace) {
          if (!completer.isCompleted) {
            completer.complete(
              Result<void, Failure>.failure(
                TransferFailure(
                  cause: error,
                  context: const <String, Object?>{
                    'reason': 'source stream failed',
                  },
                ),
              ),
            );
          }
        },
        onDone: () {
          if (!completer.isCompleted) {
            completer.complete(const Result<void, Failure>.success(null));
          }
        },
        cancelOnError: false,
      );

      if (stop != null) {
        unawaited(
          stop.then((_) {
            if (!stopped.isCompleted) stopped.complete();
          }),
        );
      }

      final outcome = await Future.any<Object?>([
        completer.future,
        stopped.future.then<Object?>(
          (_) => const Result<void, Failure>.failure(TransferFailure.cancelled),
        ),
      ]);

      return outcome as Result<void, Failure>;
    } finally {
      _dataStreamActive = false;
      await _sourceSubscription?.cancel();
      _sourceSubscription = null;
      _streamStopped = null;
    }
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _signalStreamStopped();
    await _subscription?.cancel();
    _subscription = null;
    await _sourceSubscription?.cancel();
    _sourceSubscription = null;
    await _disposeSocket();
    if (!_events.isClosed) await _events.close();
  }

  /// Classifies an incoming stream element and enforces the wire contract.
  ///
  /// `dart:io` surfaces text frames as `String` and binary frames as
  /// `Uint8List`, so the frame type is the discriminator
  /// (`docs/PROTOCOL.md` §33.2). Normalising here is what stops that detail from
  /// leaking past this boundary.
  void _onFrame(Object? frame) {
    switch (frame) {
      case final String text:
        if (_dataStreamActive) {
          _logger.warning(
            'Control message arrived during a file stream',
            context: const <String, Object?>{'action': 'closing connection'},
          );
          _events.add(const ControlDuringDataStream());
          _fail(TransferFailure.protocolViolation);
          return;
        }
        _events.add(ControlReceived(text));

      case final Uint8List bytes:
        if (bytes.length > kMaxFrameBytes) {
          // Dropped without being copied or written, then closed: the contract
          // says reject, not truncate.
          _logger.warning(
            'Frame exceeded the maximum size',
            context: <String, Object?>{
              'bytes': bytes.length,
              'max': kMaxFrameBytes,
            },
          );
          _events.add(OversizedFrame(bytes.length));
          _fail(TransferFailure.protocolViolation);
          return;
        }
        _events.add(DataReceived(bytes));

      default:
        _logger.warning(
          'Unexpected frame type',
          context: <String, Object?>{'type': frame.runtimeType.toString()},
        );
        _fail(TransferFailure.protocolViolation);
    }
  }

  bool _matchesPin(X509Certificate certificate, CertificateFingerprint pin) {
    final actual = CertificateFingerprint.fromCertificate(certificate);
    if (actual == pin) return true;
    // Both fingerprints are logged, never the certificate: enough to diagnose a
    // mismatch, not enough to be a secret.
    _logger.warning(
      'Certificate does not match the pinned fingerprint',
      context: <String, Object?>{'expected': pin.hex, 'actual': actual.hex},
    );
    return false;
  }

  /// Ends the connection once, with an optional reason.
  ///
  /// `null` means an orderly close, which is the normal end of a session and not
  /// a failure, so it is reported as such rather than as an error.
  void _fail(Failure? reason) {
    if (_socket == null) return;
    unawaited(_disposeSocket());
    if (!_events.isClosed) _events.add(TransportDisconnected(reason));
  }

  Future<void> _disposeSocket() async {
    final socket = _socket;
    final client = _httpClient;
    _socket = null;
    _httpClient = null;
    await socket?.close();
    // An idle keep-alive connection would otherwise hold the process open.
    client?.close(force: true);
  }

  void _signalStreamStopped() {
    final stopped = _streamStopped;
    _streamStopped = null;
    if (stopped != null && !stopped.isCompleted) stopped.complete();
  }
}
