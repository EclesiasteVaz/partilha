/// A file the user chose to send, as transfer needs to see it.
///
/// A path plus a size, and deliberately nothing else. The bytes stay on disk:
/// this type exists so the queue can report progress from real byte counts
/// without any layer having to hold file content in memory
/// (`features/file_transfer/FEATURE.md` §10, §20, `AGENTS.md` §21).
///
/// [sizeInBytes] is read from filesystem metadata, never computed by reading
/// the file, so building a large queue stays O(1) in memory per file.
class SelectedFile {
  const SelectedFile({
    required this.name,
    required this.path,
    required this.sizeInBytes,
  });

  /// Base name, used for display and for the receiver's filename conflict
  /// policy. Never a full path: a path is not a valid filename.
  final String name;

  /// Absolute path on the local filesystem, used only to open a read stream.
  final String path;

  /// Size in bytes, used as the progress denominator, or `null` when the
  /// platform did not report it without reading the file.
  ///
  /// Nullable on purpose. The picker can obtain a size only for some providers,
  /// and the alternative — forcing a `length()` — reads the whole file to learn
  /// how big it is, which is exactly what a large-file app must not do
  /// (`AGENTS.md` §21). When this is `null`, progress has no denominator and
  /// must be shown as indeterminate rather than as a made-up percentage
  /// (`features/file_transfer/FEATURE.md` §20).
  final int? sizeInBytes;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SelectedFile &&
          other.name == name &&
          other.path == path &&
          other.sizeInBytes == sizeInBytes;

  @override
  int get hashCode => Object.hash(name, path, sizeInBytes);

  @override
  String toString() => 'SelectedFile(name: $name, sizeInBytes: $sizeInBytes)';
}
