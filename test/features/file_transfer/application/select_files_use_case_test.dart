import 'package:flutter_test/flutter_test.dart';
import 'package:partilha/core/errors/failure.dart';
import 'package:partilha/core/result/result.dart';
import 'package:partilha/features/file_transfer/application/application.dart';
import 'package:partilha/features/file_transfer/domain/domain.dart';

import '../domain/fake_file_selection_service.dart';

void main() {
  const List<SelectedFile> files = <SelectedFile>[
    SelectedFile(name: 'a.txt', path: '/tmp/a.txt', sizeInBytes: 3),
    SelectedFile(name: 'b.txt', path: '/tmp/b.txt', sizeInBytes: 0),
  ];

  group('a selection the user made', () {
    test('is returned as-is, without being copied or reordered', () async {
      final FakeFileSelectionService service = FakeFileSelectionService(
        result: const Result<List<SelectedFile>, Failure>.success(files),
      );

      final Result<List<SelectedFile>, Failure> result =
          await SelectFilesUseCase(service)();

      expect(result.valueOrNull, files);
    });
  });

  group('a cancelled picker', () {
    test('is an empty success, not a failure', () async {
      // Cancelling is an explicit choice, not an error, and turning it into a
      // failure would make the UI report a problem the user caused on purpose
      // (AGENTS.md §28, §83).
      final FakeFileSelectionService service = FakeFileSelectionService();

      final Result<List<SelectedFile>, Failure> result =
          await SelectFilesUseCase(service)();

      expect(result.isSuccess, isTrue);
      expect(result.valueOrNull, isEmpty);
    });
  });

  group('a picker that failed', () {
    test('propagates the failure', () async {
      final FakeFileSelectionService service = FakeFileSelectionService(
        result: const Result<List<SelectedFile>, Failure>.failure(
          UnknownFailure(userMessage: 'The files could not be opened.'),
        ),
      );

      final Result<List<SelectedFile>, Failure> result =
          await SelectFilesUseCase(service)();

      expect(result.isFailure, isTrue);
    });
  });

  test('does not call the picker until it is invoked', () async {
    final FakeFileSelectionService service = FakeFileSelectionService();
    SelectFilesUseCase(service);

    expect(service.callCount, 0);
  });
}
