import 'package:partilha/core/errors/failure.dart';
import 'package:partilha/core/result/result.dart';
import 'package:partilha/features/file_transfer/domain/domain.dart';

/// Asks the platform for the files to send.
///
/// Exists so the controller depends on an application action rather than on the
/// picker package behind [FileSelectionService] (`AGENTS.md` §12). It adds no
/// orchestration: picking files is not queued work — the queue takes over once
/// the selection exists (`features/file_transfer/FEATURE.md` §16).
class SelectFilesUseCase {
  const SelectFilesUseCase(this._fileSelection);

  final FileSelectionService _fileSelection;

  /// Returns the user's selection, or an empty list if they cancelled.
  Future<Result<List<SelectedFile>, Failure>> call() =>
      _fileSelection.pickFiles();
}
