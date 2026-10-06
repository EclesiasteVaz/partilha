import 'dart:io';

import 'package:partilha/core/errors/failure.dart';
import 'package:partilha/core/result/result.dart';
import 'package:partilha/features/file_transfer/domain/domain.dart';

class DartIoStorageValidationService implements StorageValidationService {
  @override
  Future<Result<StorageStatus, Failure>> check({
    required String path,
    required int? sizeInBytes,
  }) async {
    try {
      final Directory dir = Directory(File(path).parent.path);
      if (!dir.existsSync()) {
        dir.createSync(recursive: true);
      }
      final FileStat stat = dir.statSync();
      final int free = stat.type != FileSystemEntityType.notFound
          ? stat.size
          : 0; // placeholder
      final int required = sizeInBytes ?? 0;
      return Result.success(StorageStatus(hasEnoughSpace: required <= free));
    } on Object {
      return const Result.failure(StorageFailure.writeFailed);
    }
  }
}
