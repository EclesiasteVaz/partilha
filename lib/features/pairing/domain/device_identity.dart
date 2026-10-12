import 'package:freezed_annotation/freezed_annotation.dart';

part 'device_identity.freezed.dart';
part 'device_identity.g.dart';

/// Represents local device persistent identity used in pairing and discovery.
///
/// Follows `features/pairing/FEATURE.md` §6 and `AGENTS.md` §33.
@freezed
sealed class DeviceIdentity with _$DeviceIdentity {
  const factory DeviceIdentity({
    required String deviceId,
    required String token,
  }) = _DeviceIdentity;

  factory DeviceIdentity.fromJson(Map<String, Object?> json) =>
      _$DeviceIdentityFromJson(json);
}
