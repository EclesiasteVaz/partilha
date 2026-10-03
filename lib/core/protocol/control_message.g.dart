// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'control_message.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ControlMessage _$ControlMessageFromJson(Map<String, dynamic> json) =>
    _ControlMessage(
      type: json['type'] as String,
      id: json['id'] as String,
      payload:
          json['payload'] as Map<String, dynamic>? ?? const <String, Object?>{},
    );

Map<String, dynamic> _$ControlMessageToJson(_ControlMessage instance) =>
    <String, dynamic>{
      'type': instance.type,
      'id': instance.id,
      'payload': instance.payload,
    };
