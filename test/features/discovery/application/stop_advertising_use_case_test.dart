import 'package:flutter_test/flutter_test.dart';
import 'package:partilha/core/errors/failure.dart';
import 'package:partilha/core/result/result.dart';
import 'package:partilha/features/discovery/application/stop_advertising_use_case.dart';
import 'package:partilha/features/discovery/domain/domain.dart';

class FakeDiscoveryService implements DiscoveryService {
  bool stopCalled = false;

  @override
  Future<Result<List<DiscoveredDevice>, Failure>> discover() async =>
      const Result.success(<DiscoveredDevice>[]);

  @override
  Future<Result<void, Failure>> startAdvertising({
    required String deviceId,
    required String deviceName,
    required int port,
    required Map<String, String> capabilities,
    String? interfaceName,
  }) async => const Result.success(null);

  @override
  Future<Result<void, Failure>> stopAdvertising() async {
    stopCalled = true;
    return const Result.success(null);
  }
}

void main() {
  test('StopAdvertisingUseCase delegates to DiscoveryService', () async {
    final service = FakeDiscoveryService();
    final useCase = StopAdvertisingUseCase(service);

    final result = await useCase.call();

    expect(result.isSuccess, isTrue);
    expect(service.stopCalled, isTrue);
  });
}
