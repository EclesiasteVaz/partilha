import 'dart:io';

import 'package:flutter/services.dart';

/// Platform abstraction for finalizing received files into the system's
/// public Downloads location and opening received files with the OS viewer.
///
/// Isolates platform-specific storage and intent mechanics behind a
/// project-owned contract (`AGENTS.md` §23, §41).
abstract interface class ReceivedFileService {
  /// Publishes a received file into the system's user-visible Downloads
  /// collection if it was written to an app-scoped staging directory (such as
  /// on Android 10+ under Scoped Storage), returning the final display path.
  Future<String> finalizeReceivedFile({
    required String sourcePath,
    required String fileName,
  });

  /// Opens the received file at [path] using the operating system's default
  /// viewer application, or falls back to the system Downloads explorer on
  /// Android when no viewer is registered for the file type.
  ///
  /// Returns `true` if an external application or explorer was launched.
  Future<bool> openReceivedFile(String path);
}

/// Default platform implementation of [ReceivedFileService].
class PlatformReceivedFileService implements ReceivedFileService {
  PlatformReceivedFileService({
    MethodChannel? channel,
    this.platformOverride,
    Future<ProcessResult> Function(String executable, List<String> arguments)?
    processRunner,
  }) : _channel = channel ?? const MethodChannel(_channelName),
       _processRunner = processRunner ?? Process.run;

  static const String _channelName = 'partilha/downloads';

  final MethodChannel _channel;

  /// Allows unit tests to exercise platform branches deterministically.
  final String? platformOverride;

  final Future<ProcessResult> Function(
    String executable,
    List<String> arguments,
  )
  _processRunner;

  bool get _isAndroid =>
      platformOverride == 'android' ||
      (platformOverride == null && Platform.isAndroid);

  bool get _isMacOS =>
      platformOverride == 'macos' ||
      (platformOverride == null && Platform.isMacOS);

  bool get _isLinux =>
      platformOverride == 'linux' ||
      (platformOverride == null && Platform.isLinux);

  bool get _isWindows =>
      platformOverride == 'windows' ||
      (platformOverride == null && Platform.isWindows);

  @override
  Future<String> finalizeReceivedFile({
    required String sourcePath,
    required String fileName,
  }) async {
    if (!_isAndroid) {
      return sourcePath;
    }

    try {
      final String? publishedPath = await _channel.invokeMethod<String>(
        'saveToDownloads',
        <String, String>{'sourcePath': sourcePath, 'fileName': fileName},
      );
      if (publishedPath != null && publishedPath.isNotEmpty) {
        return publishedPath;
      }
      return sourcePath;
    } on PlatformException {
      return sourcePath;
    } on MissingPluginException {
      return sourcePath;
    }
  }

  @override
  Future<bool> openReceivedFile(String path) async {
    if (path.isEmpty) {
      return false;
    }

    if (_isAndroid) {
      try {
        final bool? opened = await _channel.invokeMethod<bool>(
          'openFile',
          <String, String>{'path': path},
        );
        return opened ?? false;
      } on PlatformException {
        return false;
      } on MissingPluginException {
        return false;
      }
    }

    try {
      if (_isMacOS) {
        final result = await _processRunner('open', <String>[path]);
        return result.exitCode == 0;
      }
      if (_isLinux) {
        final result = await _processRunner('xdg-open', <String>[path]);
        return result.exitCode == 0;
      }
      if (_isWindows) {
        final result = await _processRunner('explorer', <String>[path]);
        return result.exitCode == 0;
      }
    } on Object {
      return false;
    }

    return false;
  }
}
