import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:partilha/features/file_transfer/data/dart_io_storage_validation_service.dart';

void main() {
  late Directory tempDir;
  late DartIoStorageValidationService service;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('storage_test_');
    service = DartIoStorageValidationService();
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('DartIoStorageValidationService', () {
    test(
      'succeeds and reports hasEnoughSpace true for valid writable directory',
      () async {
        final result = await service.check(
          path: tempDir.path,
          sizeInBytes: 1024 * 1024 * 10, // 10 MB
        );

        expect(result.isSuccess, isTrue);
        expect(result.valueOrNull?.hasEnoughSpace, isTrue);
      },
    );
  });
}
