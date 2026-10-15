import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:partilha/core/platform/downloads_directory_resolver.dart';

void main() {
  group('SystemDownloadsDirectoryResolver', () {
    test('resolves macOS downloads directory if writable or falls back', () {
      final resolver = SystemDownloadsDirectoryResolver(
        platformOverride: 'macos',
      );
      final dir = resolver.resolve();
      expect(dir.existsSync(), isTrue);
      // Second call returns cached directory
      expect(resolver.resolve().path, dir.path);
    });

    test('resolves first writable Android candidate in order', () {
      final tempDir1 = Directory.systemTemp.createTempSync('android_cand1_');
      final tempDir2 = Directory.systemTemp.createTempSync('android_cand2_');
      addTearDown(() {
        if (tempDir1.existsSync()) tempDir1.deleteSync(recursive: true);
        if (tempDir2.existsSync()) tempDir2.deleteSync(recursive: true);
      });

      final resolver = SystemDownloadsDirectoryResolver(
        platformOverride: 'android',
        androidCandidatesOverride: <String>[
          '/non_existent_unwritable_path/Download',
          tempDir1.path,
          tempDir2.path,
        ],
      );

      final resolved = resolver.resolve();
      expect(resolved.path, tempDir1.path);
    });

    test(
      'falls back to systemTemp on Android when no candidates are writable',
      () {
        final resolver = SystemDownloadsDirectoryResolver(
          platformOverride: 'android',
          androidCandidatesOverride: const <String>[
            '/non_existent_path_1/Download',
            '/non_existent_path_2/Download',
          ],
        );

        final resolved = resolver.resolve();
        expect(resolved.path, Directory.systemTemp.path);
      },
    );
  });
}
