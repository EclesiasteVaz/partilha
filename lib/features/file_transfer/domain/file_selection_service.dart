import 'package:partilha/core/errors/failure.dart';
import 'package:partilha/core/result/result.dart';
import 'package:partilha/features/file_transfer/domain/selected_file.dart';

/// Opens the platform's file picker and returns what the user chose.
///
/// A project-owned contract rather than the package's own type, so the picker
/// can be replaced without touching domain, application or presentation
/// (`AGENTS.md` §22, §39). `dart:io` cannot present a native dialog, so some
/// platform package is unavoidable; this contract is what keeps that choice
/// contained (`AGENTS.md` §42).
abstract interface class FileSelectionService {
  /// Presents the picker and returns the selection.
  ///
  /// An **empty list means the user cancelled**, not that nothing was found, so
  /// callers must not present it as an error (`AGENTS.md` §28, §83).
  ///
  /// Individual files may still be missing from the result on Android: the
  /// picker caches each file before returning it and silently skips the ones
  /// whose cache copy failed. See `features/file_transfer/FEATURE.md` §30.
  Future<Result<List<SelectedFile>, Failure>> pickFiles();
}
