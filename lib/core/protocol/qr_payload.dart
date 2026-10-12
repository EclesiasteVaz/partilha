import 'package:freezed_annotation/freezed_annotation.dart';

part 'qr_payload.freezed.dart';
part 'qr_payload.g.dart';

@freezed
sealed class QrPayload with _$QrPayload {
  const factory QrPayload({
    required int v,
    required String deviceId,
    required String deviceName,
    required String host,
    required int port,
    required String token,
  }) = _QrPayload;

  factory QrPayload.fromJson(Map<String, dynamic> json) =>
      _$QrPayloadFromJson(json);
}
