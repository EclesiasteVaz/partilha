import 'package:partilha/core/errors/failure.dart';
import 'package:partilha/core/result/result.dart';
import 'package:partilha/features/file_transfer/domain/domain.dart';

class WebSocketTransferRepository implements TransferRepository {
  const WebSocketTransferRepository();

  @override
  Future<Result<void, Failure>> send(TransferRequest request) async {
    // TODO: integrate with WebSocketTransport
    return const Result.success(null);
  }
}
