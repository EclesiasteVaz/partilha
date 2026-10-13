import 'package:flutter_test/flutter_test.dart';
import 'package:partilha/core/network/local_address_resolver.dart';

void main() {
  const resolver = NetworkInterfaceDeviceAddressResolver();

  test('getLocalIpv4Address returns an IP or fails gracefully without crashing', () async {
    final result = await resolver.getLocalIpv4Address();
    // In CI / local environments without network, it can be a failure;
    // when connected, it returns a valid IPv4 string.
    if (result.isSuccess) {
      final ip = result.valueOrNull!;
      final parts = ip.split('.');
      expect(parts.length, 4);
      for (final part in parts) {
        final octet = int.tryParse(part);
        expect(octet, isNotNull);
        expect(octet! >= 0 && octet <= 255, isTrue);
      }
    } else {
      expect(result.errorOrNull, isNotNull);
    }
  });
}
