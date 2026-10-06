import 'package:partilha/core/errors/failure.dart';
import 'package:partilha/core/result/result.dart';

class StorageStatus {
  const StorageStatus({required this.hasEnoughSpace});

  final bool hasEnoughSpace;
}

abstract interface class StorageValidationService {
  Future<Result<StorageStatus, Failure>> check({
    required String path,
    required int? sizeInBytes,
  });
}
