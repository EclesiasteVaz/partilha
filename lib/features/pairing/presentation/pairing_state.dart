import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:partilha/core/errors/failure.dart';
import 'package:partilha/core/protocol/qr_payload.dart';
import 'package:partilha/features/pairing/domain/pairing_context.dart';

part 'pairing_state.freezed.dart';

/// Immutable states of the pairing flow per `features/pairing/FEATURE.md` §8:
/// `initial`, `generatingQr`, `showingQr`, `scanning`, `validating`, `paired`, `failed`.
@freezed
sealed class PairingState with _$PairingState {
  const factory PairingState.initial() = PairingStateInitial;

  const factory PairingState.generatingQr() = PairingStateGeneratingQr;

  const factory PairingState.showingQr({
    required QrPayload payload,
    required String rawQrString,
  }) = PairingStateShowingQr;

  const factory PairingState.scanning() = PairingStateScanning;

  const factory PairingState.validating() = PairingStateValidating;

  const factory PairingState.paired({required PairingContext context}) =
      PairingStatePaired;

  const factory PairingState.failed({required Failure failure}) =
      PairingStateFailed;
}
