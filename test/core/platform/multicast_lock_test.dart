import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:partilha/core/errors/failure.dart';
import 'package:partilha/core/platform/platform.dart';
import 'package:partilha/core/result/result.dart';

void main() {
  // A method channel needs a live binding, including on a desktop test run.
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MethodChannelMulticastLock', () {
    // The channel is exercised through the test binding's mock handlers, which
    // is what makes the Android branch assertable on a desktop test run.
    final MethodChannelMulticastLock lock = MethodChannelMulticastLock(
      channel: const MethodChannel('partilha/multicast_lock'),
    );

    setUp(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('partilha/multicast_lock'),
            (MethodCall call) async => null,
          );
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('partilha/multicast_lock'),
            null,
          );
    });

    test('acquire forwards to the host and reports success', () async {
      expect((await lock.acquire()).isSuccess, isTrue);
    });

    test('release forwards to the host and reports success', () async {
      expect((await lock.release()).isSuccess, isTrue);
    });

    test(
      'a platform error becomes a typed failure, not an exception',
      () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              const MethodChannel('partilha/multicast_lock'),
              (MethodCall call) async =>
                  throw PlatformException(code: 'unavailable'),
            );

        final Result<void, Failure> result = await lock.acquire();

        expect(result.isFailure, isTrue);
        expect(result.errorOrNull, isA<DiscoveryFailure>());
      },
    );

    test('a missing host is treated as success, not as an error', () async {
      // Reached when the app runs somewhere the channel is not registered. It
      // must not force every caller to branch on platform.
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('partilha/multicast_lock'),
            null,
          );

      expect((await lock.acquire()).isSuccess, isTrue);
    });
  });

  group('UnrestrictedMulticastLock', () {
    const UnrestrictedMulticastLock lock = UnrestrictedMulticastLock();

    test('acquire and release always succeed', () async {
      expect((await lock.acquire()).isSuccess, isTrue);
      expect((await lock.release()).isSuccess, isTrue);
    });

    test('releasing without acquiring does not throw', () async {
      // Teardown paths release defensively; throwing there would mask the
      // original error.
      await expectLater(lock.release(), completes);
    });
  });

  group('createMulticastLock', () {
    test(
      'returns an implementation the caller can use without a platform check',
      () {
        expect(createMulticastLock(), isA<MulticastLock>());
      },
    );
  });
}
