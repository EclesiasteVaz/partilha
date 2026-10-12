import 'package:freezed_annotation/freezed_annotation.dart';

part 'pairing_context.freezed.dart';
part 'pairing_context.g.dart';

/// Represents a validated pairing context produced after scanning and verifying
/// the peer's QR code payload.
///
/// Follows `features/pairing/FEATURE.md` §11 and `AGENTS.md` §37.
@freezed
sealed class PairingContext with _$PairingContext {
  const factory PairingContext({
    required String peerDeviceId,
    required String peerDeviceName,
    required String peerHost,
    required int peerPort,
    required String token,
    String? certificateFingerprint,
  }) = _PairingContext;

  factory PairingContext.fromJson(Map<String, Object?> json) =>
      _$PairingContextFromJson(json);
}
