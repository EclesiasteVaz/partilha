// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pairing_context.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_PairingContext _$PairingContextFromJson(Map<String, dynamic> json) =>
    _PairingContext(
      peerDeviceId: json['peerDeviceId'] as String,
      peerDeviceName: json['peerDeviceName'] as String,
      peerHost: json['peerHost'] as String,
      peerPort: (json['peerPort'] as num).toInt(),
      token: json['token'] as String,
      certificateFingerprint: json['certificateFingerprint'] as String?,
    );

Map<String, dynamic> _$PairingContextToJson(_PairingContext instance) =>
    <String, dynamic>{
      'peerDeviceId': instance.peerDeviceId,
      'peerDeviceName': instance.peerDeviceName,
      'peerHost': instance.peerHost,
      'peerPort': instance.peerPort,
      'token': instance.token,
      'certificateFingerprint': instance.certificateFingerprint,
    };
