import 'package:partilha/features/file_transfer/domain/domain.dart';

class WebSocketTransferRepository implements TransferRepository {
  const WebSocketTransferRepository();

  @override
  Stream<FileTransferProgress> send(TransferRequest request) async* {
    // TODO: integrate with WebSocketTransport
    yield FileTransferProgress(
      transferId: request.id,
      bytesTransferred: 0,
      totalBytes: request.sizeInBytes ?? 0,
    );
  }
}
