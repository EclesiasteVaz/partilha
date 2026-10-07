import 'package:partilha/core/errors/failure.dart';
import 'package:partilha/core/result/result.dart';
import 'package:partilha/features/file_transfer/domain/domain.dart';

class QueueTransfersUseCase {
  const QueueTransfersUseCase();

  Future<Result<void, Failure>> call(List<TransferRequest> requests) async {
    // TODO: implement queue
    return const Result.success(null);
  }
}
