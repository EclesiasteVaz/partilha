import 'dart:io';

/// Resolves the destination directory where received downloads should be stored.
///
/// Follows `AGENTS.md` §23 (system's appropriate Downloads / Transfers location).
abstract interface class DownloadsDirectoryResolver {
  Directory resolve();
}

/// Project-owned implementation of [DownloadsDirectoryResolver].
class SystemDownloadsDirectoryResolver implements DownloadsDirectoryResolver {
  SystemDownloadsDirectoryResolver({
    this.platformOverride,
    this.androidCandidatesOverride,
  });

  /// Allows unit testing platform resolution on different environments.
  final String? platformOverride;

  /// Allows unit testing candidate fallback sequence on Android.
  final List<String>? androidCandidatesOverride;

  Directory? _cached;

  @override
  Directory resolve() {
    if (_cached != null && _cached!.existsSync()) {
      return _cached!;
    }

    final isAndroid =
        platformOverride == 'android' ||
        (platformOverride == null && Platform.isAndroid);
    final isMacOS =
        platformOverride == 'macos' ||
        (platformOverride == null && Platform.isMacOS);
    final isLinux =
        platformOverride == 'linux' ||
        (platformOverride == null && Platform.isLinux);
    final isWindows =
        platformOverride == 'windows' ||
        (platformOverride == null && Platform.isWindows);

    Directory? resolved;

    if (isAndroid) {
      final candidates =
          androidCandidatesOverride ?? _defaultAndroidCandidates();

      for (final candidate in candidates) {
        final dir = Directory(candidate);
        if (_isWritable(dir)) {
          resolved = dir;
          break;
        }
      }
    } else if (isMacOS || isLinux) {
      final home = Platform.environment['HOME'];
      if (home != null && home.isNotEmpty) {
        final dir = Directory('$home/Downloads');
        if (_isWritable(dir)) {
          resolved = dir;
        }
      }
    } else if (isWindows) {
      final userProfile = Platform.environment['USERPROFILE'];
      if (userProfile != null && userProfile.isNotEmpty) {
        final dir = Directory('$userProfile\\Downloads');
        if (_isWritable(dir)) {
          resolved = dir;
        }
      }
    }

    resolved ??= Directory.systemTemp;
    _cached = resolved;
    return resolved;
  }

  List<String> _defaultAndroidCandidates() {
    String packageName = 'com.partilha.partilha';
    try {
      final cmd = File('/proc/self/cmdline');
      if (cmd.existsSync()) {
        final text = cmd.readAsStringSync().replaceAll('\x00', '').trim();
        if (text.isNotEmpty) {
          packageName = text;
        }
      }
    } on Object catch (_) {}

    return <String>[
      '/storage/emulated/0/Download',
      '/sdcard/Download',
      if (Platform.environment['EXTERNAL_STORAGE'] != null)
        '${Platform.environment['EXTERNAL_STORAGE']}/Download',
      '/storage/emulated/0/Android/data/$packageName/files/Download',
      '/storage/emulated/0/Android/data/$packageName/files',
      '/sdcard/Android/data/$packageName/files/Download',
      '/data/user/0/$packageName/app_flutter/Download',
      '/data/user/0/$packageName/files/Download',
      '/data/data/$packageName/files/Download',
    ];
  }

  bool _isWritable(Directory dir) {
    try {
      if (!dir.existsSync()) {
        dir.createSync(recursive: true);
      }
      final probe = File(
        '${dir.path}/.partilha_probe_${DateTime.now().microsecondsSinceEpoch}',
      );
      probe.writeAsStringSync('probe');
      probe.deleteSync();
      return true;
    } on Object catch (_) {
      return false;
    }
  }
}
