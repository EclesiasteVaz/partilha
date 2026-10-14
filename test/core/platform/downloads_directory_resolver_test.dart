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

    test('resolves fallback on unknown platform without throwing', () {
      final resolver = SystemDownloadsDirectoryResolver(
        platformOverride: 'unknown',
      );
      final dir = resolver.resolve();
      expect(dir.existsSync(), isTrue);
      expect(dir.path, Directory.systemTemp.path);
    });
  });
}
