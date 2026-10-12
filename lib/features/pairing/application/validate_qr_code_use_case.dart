import 'package:partilha/core/errors/failure.dart';
import 'package:partilha/core/protocol/qr_payload.dart';
import 'package:partilha/core/result/result.dart';
import 'package:partilha/features/pairing/domain/pairing_context.dart';
import 'package:partilha/features/pairing/domain/qr_code_service.dart';

/// Validates raw QR code content into a strongly typed [PairingContext].
class ValidateQrCodeUseCase {
  const ValidateQrCodeUseCase(this._qrCodeService);

  final QrCodeService _qrCodeService;

  Result<PairingContext, Failure> call(String rawContent) =>
      _qrCodeService.validateScanned(rawContent);

  String encode(QrPayload payload) => _qrCodeService.encode(payload);
}
