import 'package:partilha/core/errors/failure.dart';
import 'package:partilha/core/result/result.dart';
import 'package:partilha/features/file_transfer/domain/domain.dart';

/// A [FileSelectionService] the tests drive directly.
///
/// Returns a scripted result instead of opening a dialog, which is what makes
/// the cancellation and failure paths testable at all: a real picker cannot be
/// told to fail (`AGENTS.md` §60.1).
class FakeFileSelectionService implements FileSelectionService {
  FakeFileSelectionService({
    this.result = const Result<List<SelectedFile>, Failure>.success(
      <SelectedFile>[],
    ),
  });

  /// What the next call returns. Assign before triggering the pick.
  Result<List<SelectedFile>, Failure> result;

  /// How many times the picker was asked. Asserts a screen did not re-open it.
  int callCount = 0;

  @override
  Future<Result<List<SelectedFile>, Failure>> pickFiles() async {
    callCount++;
    return result;
  }
}
