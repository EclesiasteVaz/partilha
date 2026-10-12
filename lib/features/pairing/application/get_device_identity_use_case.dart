import 'package:partilha/core/errors/failure.dart';
import 'package:partilha/core/result/result.dart';
import 'package:partilha/features/pairing/domain/device_identity.dart';
import 'package:partilha/features/pairing/domain/pairing_repository.dart';

/// Retrieves or creates the device identity for pairing.
class GetDeviceIdentityUseCase {
  const GetDeviceIdentityUseCase(this._repository);

  final PairingRepository _repository;

  Future<Result<DeviceIdentity, Failure>> call() =>
      _repository.getOrCreateIdentity();
}
