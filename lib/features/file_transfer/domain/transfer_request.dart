import 'package:partilha/features/file_transfer/domain/selected_file.dart';
import 'package:partilha/features/file_transfer/domain/transfer_destination.dart';

enum TransferType { file }

/// One unit of send work: this file, to that device.
///
/// The queue builds a request per selected file and hands it to the
/// repository unchanged, so the request is the full description of what a send
/// attempt does (`FEATURE.md` §17).
class TransferRequest {
  const TransferRequest({
    required this.id,
    required this.destination,
    required this.file,
    this.type = TransferType.file,
  });

  /// Local queue identifier, assigned when the item is enqueued.
  ///
  /// Deliberately not a protocol identifier: the wire format of a transfer id
  /// is still an open decision (`FEATURE.md` §34), and inventing a format here
  /// would quietly pre-empt it.
  final String id;

  /// Where the bytes go. Carried on the request rather than on the repository
  /// so one repository instance can serve several destinations without
  /// holding session state.
  final TransferDestination destination;

  final SelectedFile file;

  final TransferType type;

  String get name => file.name;

  int? get sizeInBytes => file.sizeInBytes;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TransferRequest &&
          other.id == id &&
          other.destination == destination &&
          other.file == file &&
          other.type == type;

  @override
  int get hashCode => Object.hash(id, destination, file, type);

  @override
  String toString() => 'TransferRequest($id, $name, $sizeInBytes)';
}
