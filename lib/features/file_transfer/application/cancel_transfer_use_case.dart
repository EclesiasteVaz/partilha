import 'package:partilha/core/errors/failure.dart';
import 'package:partilha/core/result/result.dart';

class CancelTransferUseCase {
  const CancelTransferUseCase();

  Future<Result<void, Failure>> call(String transferId) async {
    // TODO: implement cancellation
    return const Result.success(null);
  }
}
