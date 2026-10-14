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
      final Directory dir = Directory(path);
      if (!dir.existsSync()) {
        dir.createSync(recursive: true);
      }
      final probe = File(
        '${dir.path}/.partilha_space_${DateTime.now().microsecondsSinceEpoch}',
      );
      probe.writeAsStringSync('');
      probe.deleteSync();

      return const Result.success(StorageStatus(hasEnoughSpace: true));
    } on FileSystemException catch (e) {
      // OS error 28 is ENOSPC (No space left on device) on macOS, Linux, and Android.
      if (e.osError?.errorCode == 28) {
        return const Result.success(StorageStatus(hasEnoughSpace: false));
      }
      return const Result.failure(StorageFailure.writeFailed);
    } on Object {
      return const Result.failure(StorageFailure.writeFailed);
    }
  }
}
