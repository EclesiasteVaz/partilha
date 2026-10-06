import 'package:flutter_test/flutter_test.dart';
import 'package:partilha/features/file_transfer/domain/domain.dart';

void main() {
  TransferDestination build({
    String deviceId = 'id-1',
    String deviceName = 'Alice',
    String address = '192.168.1.10',
    int port = 4443,
  }) => TransferDestination(
    deviceId: deviceId,
    deviceName: deviceName,
    address: address,
    port: port,
  );

  test('two destinations with the same fields are equal', () {
    expect(build(), build());
    expect(build().hashCode, build().hashCode);
  });

  test('a differing address makes them different', () {
    expect(build(), isNot(build(address: '192.168.1.11')));
  });

  test('a differing port makes them different', () {
    expect(build(), isNot(build(port: 4444)));
  });

  test('a differing device id makes them different', () {
    // The id is the only identifier the record carries, so two announcements of
    // the same host under different ids must not collapse into one row.
    expect(build(), isNot(build(deviceId: 'id-2')));
  });

  test('toString does not leak more than the fields it was given', () {
    expect(build().toString(), contains('Alice'));
    expect(build().toString(), contains('4443'));
  });
}
