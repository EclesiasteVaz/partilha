// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'qr_payload.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_QrPayload _$QrPayloadFromJson(Map<String, dynamic> json) => _QrPayload(
  v: (json['v'] as num).toInt(),
  deviceId: json['deviceId'] as String,
  deviceName: json['deviceName'] as String,
  host: json['host'] as String,
  port: (json['port'] as num).toInt(),
  token: json['token'] as String,
);

Map<String, dynamic> _$QrPayloadToJson(_QrPayload instance) =>
    <String, dynamic>{
      'v': instance.v,
      'deviceId': instance.deviceId,
      'deviceName': instance.deviceName,
      'host': instance.host,
      'port': instance.port,
      'token': instance.token,
    };
