import 'package:partilha/features/file_transfer/domain/transfer_repository.dart';

/// Closes any active peer session and releases underlying network transports.
class CloseTransferSessionUseCase {
  const CloseTransferSessionUseCase(this._repository);

  final TransferRepository _repository;

  Future<void> call() => _repository.closeSession();
}
