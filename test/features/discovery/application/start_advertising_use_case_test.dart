import 'package:flutter_test/flutter_test.dart';
import 'package:partilha/core/errors/failure.dart';
import 'package:partilha/core/result/result.dart';
import 'package:partilha/features/discovery/application/start_advertising_use_case.dart';
import 'package:partilha/features/discovery/domain/domain.dart';

class FakeDiscoveryService implements DiscoveryService {
  bool advertiseCalled = false;
  String? lastDeviceId;
  String? lastDeviceName;
  int? lastPort;
  Map<String, String>? lastCapabilities;

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
  }) async {
    advertiseCalled = true;
    lastDeviceId = deviceId;
    lastDeviceName = deviceName;
    lastPort = port;
    lastCapabilities = capabilities;
    return const Result.success(null);
  }

  @override
  Future<Result<void, Failure>> stopAdvertising() async =>
      const Result.success(null);
}

void main() {
  test('StartAdvertisingUseCase delegates to DiscoveryService', () async {
    final service = FakeDiscoveryService();
    final useCase = StartAdvertisingUseCase(service);

    final result = await useCase.call(
      deviceId: 'dev-1',
      deviceName: 'Device One',
      port: 8080,
      capabilities: {'file-transfer': '1'},
    );

    expect(result.isSuccess, isTrue);
    expect(service.advertiseCalled, isTrue);
    expect(service.lastDeviceId, equals('dev-1'));
    expect(service.lastDeviceName, equals('Device One'));
    expect(service.lastPort, equals(8080));
    expect(service.lastCapabilities, equals({'file-transfer': '1'}));
  });
}
