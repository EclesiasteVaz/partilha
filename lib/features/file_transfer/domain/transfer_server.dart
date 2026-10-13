import 'dart:typed_data';

import 'package:partilha/core/errors/failure.dart';
import 'package:partilha/core/result/result.dart';
import 'package:partilha/features/file_transfer/domain/selected_file.dart';

/// Identifies a file being offered by a peer.
class TransferOffer {
  const TransferOffer({
    required this.id,
    required this.name,
    required this.sizeInBytes,
    required this.meta,
  });

  /// Opaque transfer identifier as sent by the peer.
  final String id;

  /// Display name, must be validated before creating a local file.
  final String name;

  final int? sizeInBytes;

  final Map<String, String> meta;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TransferOffer &&
          other.id == id &&
          other.name == name &&
          other.sizeInBytes == sizeInBytes &&
          _mapEquals(other.meta, meta);

  @override
  int get hashCode => Object.hash(
    id,
    name,
    sizeInBytes,
    Object.hashAllUnordered(
      meta.entries.map((e) => Object.hash(e.key, e.value)),
    ),
  );

  static bool _mapEquals(Map<String, String> a, Map<String, String> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (final MapEntry<String, String> e in a.entries) {
      if (!b.containsKey(e.key) || b[e.key] != e.value) return false;
    }
    return true;
  }
}

/// Server lifecycle events.
sealed class TransferServerEvent {}

final class TransferServerListening extends TransferServerEvent {
  TransferServerListening({required this.port});

  final int port;
}

final class TransferServerOfferReceived extends TransferServerEvent {
  TransferServerOfferReceived({required this.offer});

  final TransferOffer offer;
}

final class TransferServerBytesReceived extends TransferServerEvent {
  TransferServerBytesReceived({required this.transferId, required this.bytes});

  final String transferId;
  final Uint8List bytes;
}

final class TransferServerDone extends TransferServerEvent {
  TransferServerDone({required this.transferId, required this.file});

  final String transferId;
  final SelectedFile file;
}

final class TransferServerError extends TransferServerEvent {
  TransferServerError({required this.failure});

  final Failure failure;
}

/// A minimal receiving-side server. No send side here; transfer server's job
/// is to accept WebSocket connections and demux frames by type, enforcing
/// `docs/PROTOCOL.md` §33 (text = control, binary = bytes, 64 KiB limit, no
/// interleaving). Concrete handler details are filled in as the protocol becomes
/// concrete.
abstract interface class TransferServer {
  Stream<TransferServerEvent> get events;

  /// The active bound port of the server, or `null` if stopped.
  int? get port;

  Future<Result<void, Failure>> start({required int port});

  Future<Result<void, Failure>> stop();
}
