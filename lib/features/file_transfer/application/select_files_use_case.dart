import 'package:partilha/core/errors/failure.dart';
import 'package:partilha/core/result/result.dart';
import 'package:partilha/features/file_transfer/domain/domain.dart';

/// Asks the platform for the files to send.
///
/// Exists so the controller depends on an application action rather than on the
/// picker package behind [FileSelectionService] (`AGENTS.md` §12). It adds no
/// orchestration: the queue is not implemented yet, so there is nothing to
/// coordinate, and inventing coordination now would be policy nobody approved
/// (`features/file_transfer/FEATURE.md` §34).
class SelectFilesUseCase {
  const SelectFilesUseCase(this._fileSelection);

  final FileSelectionService _fileSelection;

  /// Returns the user's selection, or an empty list if they cancelled.
  Future<Result<List<SelectedFile>, Failure>> call() =>
      _fileSelection.pickFiles();
}
