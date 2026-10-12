import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:partilha/features/pairing/data/secure_storage_pairing_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SecureStoragePairingRepository', () {
    test(
      'creates new deviceId and token if none exist and persists them',
      () async {
        FlutterSecureStorage.setMockInitialValues({});
        final repository = SecureStoragePairingRepository(
          secureStorage: const FlutterSecureStorage(),
        );

        final res1 = await repository.getOrCreateIdentity();
        expect(res1.isSuccess, isTrue);

        final identity1 = res1.valueOrNull!;
        expect(identity1.deviceId.isNotEmpty, isTrue);
        expect(identity1.token.isNotEmpty, isTrue);

        // Second call returns exactly the same persistent identity
        final res2 = await repository.getOrCreateIdentity();
        expect(res2.isSuccess, isTrue);
        final identity2 = res2.valueOrNull!;
        expect(identity2.deviceId, identity1.deviceId);
        expect(identity2.token, identity1.token);
      },
    );
  });
}
