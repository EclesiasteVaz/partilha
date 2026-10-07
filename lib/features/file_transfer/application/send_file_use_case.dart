import 'package:partilha/features/file_transfer/domain/domain.dart';

class SendFileUseCase {
  const SendFileUseCase(this._repo);

  final TransferRepository _repo;

  Stream<FileTransferProgress> call(TransferRequest request) =>
      _repo.send(request);
}
