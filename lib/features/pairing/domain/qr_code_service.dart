import 'package:partilha/core/errors/failure.dart';
import 'package:partilha/core/protocol/qr_payload.dart';
import 'package:partilha/core/result/result.dart';
import 'package:partilha/features/pairing/domain/pairing_context.dart';

/// Contract isolating QR encoding, decoding and validation.
///
/// Follows `AGENTS.md` §39 ("QR scanning and generation must be isolated
/// behind project-owned abstractions").
abstract interface class QrCodeService {
  /// Encodes a [QrPayload] into a JSON string suitable for rendering in a QR code.
  String encode(QrPayload payload);

  /// Validates a raw string scanned from a QR code, returning a [PairingContext]
  /// or a typed [PairingFailure].
  Result<PairingContext, Failure> validateScanned(String rawQrContent);
}
