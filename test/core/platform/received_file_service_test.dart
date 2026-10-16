import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:partilha/core/platform/platform.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel channel = MethodChannel('partilha/downloads');

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  group('PlatformReceivedFileService (Android)', () {
    test(
      'finalizeReceivedFile invokes saveToDownloads and returns published path',
      () async {
        MethodCall? capturedCall;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (MethodCall call) async {
              capturedCall = call;
              return '/storage/emulated/0/Download/photo.jpg';
            });

        final service = PlatformReceivedFileService(
          channel: channel,
          platformOverride: 'android',
        );

        final finalPath = await service.finalizeReceivedFile(
          sourcePath:
              '/storage/emulated/0/Android/data/com.partilha.partilha/files/Download/photo.jpg',
          fileName: 'photo.jpg',
        );

        expect(capturedCall?.method, 'saveToDownloads');
        expect(capturedCall?.arguments, <String, String>{
          'sourcePath':
              '/storage/emulated/0/Android/data/com.partilha.partilha/files/Download/photo.jpg',
          'fileName': 'photo.jpg',
        });
        expect(finalPath, '/storage/emulated/0/Download/photo.jpg');
      },
    );

    test(
      'finalizeReceivedFile falls back to sourcePath when channel throws',
      () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              channel,
              (MethodCall call) async => throw PlatformException(code: 'error'),
            );

        final service = PlatformReceivedFileService(
          channel: channel,
          platformOverride: 'android',
        );

        const source = '/data/user/0/com.partilha.partilha/files/doc.pdf';
        final finalPath = await service.finalizeReceivedFile(
          sourcePath: source,
          fileName: 'doc.pdf',
        );

        expect(finalPath, source);
      },
    );

    test('openReceivedFile invokes openFile and returns host result', () async {
      MethodCall? capturedCall;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
            capturedCall = call;
            return true;
          });

      final service = PlatformReceivedFileService(
        channel: channel,
        platformOverride: 'android',
      );

      final opened = await service.openReceivedFile(
        '/storage/emulated/0/Download/photo.jpg',
      );

      expect(opened, isTrue);
      expect(capturedCall?.method, 'openFile');
      expect(capturedCall?.arguments, <String, String>{
        'path': '/storage/emulated/0/Download/photo.jpg',
      });
    });
  });

  group('PlatformReceivedFileService (macOS)', () {
    test('finalizeReceivedFile returns sourcePath directly', () async {
      final service = PlatformReceivedFileService(platformOverride: 'macos');
      const source = '/Users/test/Downloads/report.pdf';

      final result = await service.finalizeReceivedFile(
        sourcePath: source,
        fileName: 'report.pdf',
      );

      expect(result, source);
    });

    test('openReceivedFile launches open command on macOS', () async {
      String? executedBin;
      List<String>? executedArgs;

      final service = PlatformReceivedFileService(
        platformOverride: 'macos',
        processRunner: (String executable, List<String> arguments) async {
          executedBin = executable;
          executedArgs = arguments;
          return ProcessResult(1, 0, '', '');
        },
      );

      final opened = await service.openReceivedFile(
        '/Users/test/Downloads/report.pdf',
      );

      expect(opened, isTrue);
      expect(executedBin, 'open');
      expect(executedArgs, <String>['/Users/test/Downloads/report.pdf']);
    });

    test('openReceivedFile returns false for empty path', () async {
      final service = PlatformReceivedFileService(platformOverride: 'macos');
      expect(await service.openReceivedFile(''), isFalse);
    });
  });
}
