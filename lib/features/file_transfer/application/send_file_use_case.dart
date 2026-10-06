import 'package:partilha/core/errors/failure.dart';
import 'package:partilha/core/result/result.dart';
import 'package:partilha/features/file_transfer/domain/domain.dart';

class SendFileUseCase {
  const SendFileUseCase(this._repo);

  final TransferRepository _repo;

  Future<Result<void, Failure>> call(TransferRequest request) async {
    return _repo.send(request);
  }
}
