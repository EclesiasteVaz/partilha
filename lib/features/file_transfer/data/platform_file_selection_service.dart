import 'package:file_picker/file_picker.dart';
import 'package:partilha/core/errors/failure.dart';
import 'package:partilha/core/logging/app_logger.dart';
import 'package:partilha/core/result/result.dart';
import 'package:partilha/features/file_transfer/domain/domain.dart';
import 'package:path/path.dart' as p;

/// Presents the platform file picker.
///
/// The only place `file_picker` is imported. Presentation asks for a
/// [FileSelectionService]; it never sees `PlatformFilePickerResult` or
/// `PlatformFile` (`AGENTS.md` §22, §51).
///
/// **Android copies each selected file into the app cache** before returning it,
/// streaming in 8 KiB blocks so memory stays flat, and hands back a real
/// filesystem path. That is why a path-based [SelectedFile] is the right domain
/// shape here: `dart:io` can stream the copy directly
/// (`features/file_transfer/FEATURE.md` §30).
///
/// Two consequences are inherited rather than hidden, and both are recorded in
/// the feature document:
///
/// - the original file and its cache copy exist at the same time, so peak disk
///   use is roughly twice the selection;
/// - a copy that fails is dropped from the result **without any error**, so the
///   returned list can be shorter than what the user picked and this layer has
///   no way to detect it.
///
class PlatformFileSelectionService implements FileSelectionService {
  const PlatformFileSelectionService(this._logger);

  final AppLogger _logger;

  @override
  Future<Result<List<SelectedFile>, Failure>> pickFiles() async {
    try {
      // `pickFiles` is the multi-select entry point in this version, so
      // multiple files need no separate flag.
      final List<PlatformFile> picked = await FilePicker.pickFiles();

      // A cancelled dialog arrives as an empty list. That is not a failure, so
      // nothing is logged and no error is produced (`AGENTS.md` §28).
      return Result<List<SelectedFile>, Failure>.success(
        picked.map(_toSelectedFile).whereType<SelectedFile>().toList(),
      );
    } on Object catch (cause, stackTrace) {
      // No failure category covers a picker that could not be shown, and the
      // hierarchy is sealed on purpose. Adding a category for one plugin call
      // would be the fragmentation `AGENTS.md` §14 warns against, so the
      // honest classification is UnknownFailure: retrying is not assumed safe.
      _logger.failure(
        'File selection failed',
        UnknownFailure(cause: cause),
        context: <String, Object?>{'stackTrace': stackTrace.toString()},
        stackTrace: stackTrace,
      );
      return Result<List<SelectedFile>, Failure>.failure(
        UnknownFailure(
          userMessage: 'The files could not be opened.',
          cause: cause,
          context: <String, Object?>{'stackTrace': stackTrace.toString()},
        ),
      );
    }
  }

  /// Projects the picker's file into the domain type, or drops it.
  ///
  /// Returns `null` — rather than throwing — when the platform gave no usable
  /// path. A file with no path cannot be streamed, so keeping it in the list
  /// would only fail later, further from the cause
  /// (`features/file_transfer/FEATURE.md` §12).
  SelectedFile? _toSelectedFile(PlatformFile file) {
    final String? path = file.path;
    if (path == null || path.isEmpty) {
      _logger.warning(
        'Dropping selected file without a path',
        context: <String, Object?>{'name': file.name},
      );
      return null;
    }

    return SelectedFile(
      // `p.basename` rather than trusting the reported name: the name is display
      // metadata, the path is what we will actually open.
      name: p.basename(path),
      path: path,
      // `lengthSync` and never `length`: the async variant falls back to reading
      // the file to discover its size, which would pull a whole video into
      // memory just to label a list row (`AGENTS.md` §21).
      sizeInBytes: file.lengthSync(),
    );
  }
}
