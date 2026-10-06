import 'dart:async';

import 'dart:io';
import 'dart:typed_data';

import 'package:partilha/core/errors/failure.dart';
import 'package:partilha/core/logging/app_logger.dart';
import 'package:partilha/core/result/result.dart';
import 'package:partilha/features/file_transfer/domain/domain.dart';

/// Placeholder implementation. This enforces the framing rule at the surface
/// (discriminates text/binary) but does not parse JSON or write files yet.
/// Enough to compile, to reason about lifecycle, and to let tests cover
/// lifecycle without implementing the full receiver.
final class DartIoTransferServer implements TransferServer {
  DartIoTransferServer(this._logger);

  final AppLogger _logger;
  final StreamController<TransferServerEvent> _events =
      StreamController<TransferServerEvent>.broadcast();

  HttpServer? _server;
  final Set<WebSocket> _clients = <WebSocket>{};
  StreamSubscription<HttpRequest>? _subscription;

  @override
  Stream<TransferServerEvent> get events => _events.stream;

  @override
  Future<Result<void, Failure>> start({required int port}) async {
    if (_server != null) {
      return const Result.failure(TransferFailure.connectionLost);
    }
    try {
      final HttpServer server = await HttpServer.bind(
        InternetAddress.anyIPv4,
        port,
        shared: true,
      );
      _server = server;
      _subscription = server.listen(_handleRequest);
      _events.add(TransferServerListening(port: server.port));
      return const Result.success(null);
    } on SocketException catch (e, st) {
      _logger.warning(
        'Failed to bind transfer server',
        error: e,
        stackTrace: st,
      );
      return const Result.failure(TransferFailure.connectionLost);
    } on Object catch (e, st) {
      _logger.failure(
        'Failed to start transfer server',
        TransferFailure.connectionLost,
        context: <String, Object?>{},
        stackTrace: st,
      );
      return const Result.failure(TransferFailure.connectionLost);
    }
  }

  @override
  Future<Result<void, Failure>> stop() async {
    if (_server == null) return const Result.success(null);
    await _subscription?.cancel();
    _subscription = null;
    for (final WebSocket ws in _clients.toList()) {
      await ws.close();
    }
    _clients.clear();
    await _server?.close(force: true);
    _server = null;
    return const Result.success(null);
  }

  Future<void> _handleRequest(HttpRequest request) async {
    try {
      final WebSocket ws = await WebSocketTransformer.upgrade(request);
      _clients.add(ws);
      final StreamSubscription<Object?> sub = ws.listen(
        (Object? data) {
          if (data is String) {
            // Control frame. Not parsed yet; protocol violation rules apply when
            // in middle of stream (§33.3) — not enforced until streaming state
            // exists. For now just ignore or would go to control parser later.
          } else if (data is List<int>) {
            if (data.length > 65536) {
              _events.add(
                TransferServerError(failure: TransferFailure.protocolViolation),
              );
              unawaited(
                ws.close(WebSocketStatus.protocolError, 'frame too large'),
              );
              _clients.remove(ws);
              return;
            }
            // Bytes frame — will be aggregated per transfer.
            _events.add(
              TransferServerBytesReceived(
                transferId: 'pending',
                bytes: Uint8List.fromList(data),
              ),
            );
          }
        },
        onDone: () => _clients.remove(ws),
        onError: (_) => _clients.remove(ws),
      );
      ws.done.then((_) => sub.cancel());
    } on Object catch (e, st) {
      _logger.warning('Rejected WebSocket upgrade', error: e, stackTrace: st);
      await request.response.close();
    }
  }
}
