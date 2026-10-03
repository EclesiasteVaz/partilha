import 'package:partilha/core/errors/failure.dart';
import 'package:partilha/core/network/certificate_fingerprint.dart';
import 'package:partilha/core/network/transport_frame.dart';
import 'package:partilha/core/result/result.dart';

/// Where to connect, and the certificate to expect.
///
/// The pin travels with the target rather than being configured on the transport
/// because it is per-pairing data (`docs/PROTOCOL.md` §8). A transport shared
/// across pairings must not be able to forget which certificate it is verifying.
final class TransportTarget {
  const TransportTarget({
    required this.host,
    required this.port,
    required this.certificateFingerprint,
  });

  /// The address of the peer, as announced by the receiver.
  final String host;

  /// The TCP port the receiver is listening on.
  final int port;

  /// The only certificate that will be accepted.
  final CertificateFingerprint certificateFingerprint;

  @override
  String toString() => 'TransportTarget($host:$port)';
}

/// The project-owned realtime transport.
///
/// Sits above `dart:io`'s `WebSocket` and hides it completely: no `WebSocket`,
/// no `Stream<dynamic>`, and no `dart:io` exception crosses this boundary
/// (`AGENTS.md` §18, `docs/ARCHITECTURE.md` §27).
///
/// It owns exactly the wire mechanics that are already decided — TLS with a
/// pinned certificate, the control/data frame split, the frame size limit, and
/// the serialized-transfer constraint. It deliberately owns nothing about the
/// message schema, which is still open for approval.
abstract interface class WebSocketTransport {
  /// Opens a pinned connection to [target].
  ///
  /// Fails when the peer cannot be reached, when TLS fails, or when the
  /// presented certificate does not match [TransportTarget.certificateFingerprint].
  /// A mismatch is never downgraded to a warning: an unpinned connection is not
  /// a connection this design has agreed to make.
  Future<Result<void, Failure>> connect(TransportTarget target);

  /// Frames and lifecycle, in arrival order.
  ///
  /// The single stream completes when the connection closes. Events already
  /// delivered stay delivered, so a consumer never has to distinguish "closed"
  /// from "closed after emitting".
  Stream<TransportEvent> get events;

  /// Whether frames may currently be sent.
  bool get isConnected;

  /// Sends a control message as a JSON text frame.
  ///
  /// Rejected while a file stream is in flight, because that is a protocol
  /// violation rather than a message (`docs/PROTOCOL.md` §33.3).
  Future<Result<void, Failure>> sendControl(String json);

  /// Sends one chunk of file bytes as a binary frame.
  ///
  /// Rejects a chunk larger than [kMaxFrameBytes] instead of silently splitting
  /// it, so the frame size the caller thinks it sent is the frame size on the
  /// wire.
  Future<Result<void, Failure>> sendData(List<int> bytes);

  /// Sends [source] as a sequence of frames no larger than [kMaxFrameBytes].
  ///
  /// Chunks as it reads rather than buffering, so an arbitrarily large file
  /// transfers in constant memory (`AGENTS.md` §19, §21). Fails with
  /// `TransferFailure.cancelled` when [stop] completes, leaving the source
  /// subscription cancelled.
  ///
  /// One stream at a time, matching the serialized-transfer decision
  /// (`docs/PROTOCOL.md` §33.6).
  Future<Result<void, Failure>> sendStream(
    Stream<List<int>> source, {
    Future<void>? stop,
  });

  /// Closes the connection. Safe to call more than once.
  Future<void> close();
}
