import 'package:partilha/features/file_transfer/domain/file_transfer_progress.dart';
import 'package:partilha/features/file_transfer/domain/transfer_request.dart';

abstract interface class TransferRepository {
  Stream<FileTransferProgress> send(TransferRequest request);
}
