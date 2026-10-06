import 'package:partilha/core/errors/failure.dart';
import 'package:partilha/core/result/result.dart';
import 'package:partilha/features/file_transfer/domain/transfer_type.dart';

abstract interface class TransferRepository {
  Future<Result<void, Failure>> send(TransferRequest request);
}
