import 'dart:typed_data';

import 'package:partilha/core/errors/failure.dart';

/// The largest frame Partilha accepts, in bytes.
///
/// Fixed rather than negotiated (`docs/PROTOCOL.md` §33.4). Frames are chunks of
/// a file, never the file itself, so this bounds how much memory a single
/// transfer holds at once without constraining file size.
///
/// ## What this limit can and cannot do
///
/// The limit stops the application from *processing* an oversized frame: the
/// frame is dropped without being copied, written or decoded, and the connection
/// is closed immediately so the peer cannot keep the stream busy.
///
/// It cannot stop the platform from *allocating* it. `dart:io` materialises a
/// complete WebSocket frame into a `Uint8List` before the application ever sees
/// it, and exposes no hook to inspect a frame's size before that happens. Closing
/// the connection on the first violation is therefore what limits the damage to
/// one allocation per connection rather than a sustained flood, and it is why the
/// check must never be relaxed into a warning.
const int kMaxFrameBytes = 64 * 1024;

/// A single frame as it crosses the wire.
///
/// The two cases mirror the two WebSocket frame types on purpose: the
/// discriminator is the transport's own, so nothing inside the payload has to
/// declare what it is (`docs/PROTOCOL.md` §33.2). Base64 is therefore never
/// needed and file bytes stay exactly as they are on disk.
sealed class TransportFrame {
  const TransportFrame();

  /// Whether this frame can be sent while a file stream is in flight.
  ///
  /// Only data frames may. A control frame in the middle of a stream is a
  /// protocol violation rather than a message, because accepting it would let a
  /// sender interleave control traffic into bytes already being written with no
  /// way for the receiver to tell it from a desynchronised stream
  /// (`docs/PROTOCOL.md` §33.3).
  bool get isAllowedDuringDataStream;
}

/// A control message, carried as JSON text.
///
/// The payload is deliberately left as text. Parsing it into typed models belongs
/// to the protocol layer above, which keeps this contract independent of the
/// message schema that is still open for approval.
final class ControlFrame extends TransportFrame {
  const ControlFrame(this.payload);

  /// The JSON text of the control message.
  final String payload;

  @override
  bool get isAllowedDuringDataStream => false;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ControlFrame && other.payload == payload;

  @override
  int get hashCode => payload.hashCode;

  @override
  String toString() => 'ControlFrame(${payload.length} chars)';
}

/// A chunk of file bytes.
final class DataFrame extends TransportFrame {
  DataFrame(this.bytes) : assert(bytes.length <= kMaxFrameBytes);

  /// The raw bytes, never copied by the transport.
  final Uint8List bytes;

  @override
  bool get isAllowedDuringDataStream => true;

  @override
  String toString() => 'DataFrame(${bytes.length} bytes)';
}

/// Something the transport observed, as a single ordered stream.
///
/// One stream rather than several, because the receiver is entitled to rely on
/// send order (`docs/PROTOCOL.md` §33.5) and splitting control, data and
/// lifecycle into separate streams would invite code that observes them
/// inconsistently.
sealed class TransportEvent {
  const TransportEvent();
}

/// The connection is open and frames may be sent.
final class TransportConnected extends TransportEvent {
  const TransportConnected();
}

/// A control message arrived.
final class ControlReceived extends TransportEvent {
  const ControlReceived(this.payload);

  /// The JSON text, exactly as received.
  final String payload;

  @override
  String toString() => 'ControlReceived(${payload.length} chars)';
}

/// A chunk of file bytes arrived.
final class DataReceived extends TransportEvent {
  DataReceived(this.bytes);

  /// The bytes, owned by the transport and not copied.
  final Uint8List bytes;

  @override
  String toString() => 'DataReceived(${bytes.length} bytes)';
}

/// A frame exceeded [kMaxFrameBytes] and was dropped.
///
/// Always terminal for the connection: the contract says to close, so the
/// transport does rather than leaving it to every caller.
final class OversizedFrame extends TransportEvent {
  const OversizedFrame(this.actualBytes);

  /// The size that was rejected, kept for logging without buffering the frame.
  final int actualBytes;

  @override
  String toString() => 'OversizedFrame($actualBytes bytes)';
}

/// A control message arrived while a file stream was in flight.
///
/// A violation rather than a delivered message (`docs/PROTOCOL.md` §33.3).
final class ControlDuringDataStream extends TransportEvent {
  const ControlDuringDataStream();

  @override
  String toString() => 'ControlDuringDataStream()';
}

/// The connection closed. [reason] distinguishes an orderly close from a fault.
final class TransportDisconnected extends TransportEvent {
  const TransportDisconnected(this.reason);

  /// Why the connection ended, as a typed failure when there was one.
  ///
  /// `null` means the peer closed cleanly, which is not a failure at all: it is
  /// the normal end of a session.
  final Failure? reason;

  @override
  String toString() => 'TransportDisconnected(${reason ?? 'clean'})';
}
