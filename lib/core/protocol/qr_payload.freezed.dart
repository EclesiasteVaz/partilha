// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'qr_payload.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$QrPayload {

 int get v; String get deviceId; String get deviceName; String get host; int get port; String get token;
/// Create a copy of QrPayload
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$QrPayloadCopyWith<QrPayload> get copyWith => _$QrPayloadCopyWithImpl<QrPayload>(this as QrPayload, _$identity);

  /// Serializes this QrPayload to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is QrPayload&&(identical(other.v, v) || other.v == v)&&(identical(other.deviceId, deviceId) || other.deviceId == deviceId)&&(identical(other.deviceName, deviceName) || other.deviceName == deviceName)&&(identical(other.host, host) || other.host == host)&&(identical(other.port, port) || other.port == port)&&(identical(other.token, token) || other.token == token));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,v,deviceId,deviceName,host,port,token);

@override
String toString() {
  return 'QrPayload(v: $v, deviceId: $deviceId, deviceName: $deviceName, host: $host, port: $port, token: $token)';
}


}

/// @nodoc
abstract mixin class $QrPayloadCopyWith<$Res>  {
  factory $QrPayloadCopyWith(QrPayload value, $Res Function(QrPayload) _then) = _$QrPayloadCopyWithImpl;
@useResult
$Res call({
 int v, String deviceId, String deviceName, String host, int port, String token
});




}
/// @nodoc
class _$QrPayloadCopyWithImpl<$Res>
    implements $QrPayloadCopyWith<$Res> {
  _$QrPayloadCopyWithImpl(this._self, this._then);

  final QrPayload _self;
  final $Res Function(QrPayload) _then;

/// Create a copy of QrPayload
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? v = null,Object? deviceId = null,Object? deviceName = null,Object? host = null,Object? port = null,Object? token = null,}) {
  return _then(_self.copyWith(
v: null == v ? _self.v : v // ignore: cast_nullable_to_non_nullable
as int,deviceId: null == deviceId ? _self.deviceId : deviceId // ignore: cast_nullable_to_non_nullable
as String,deviceName: null == deviceName ? _self.deviceName : deviceName // ignore: cast_nullable_to_non_nullable
as String,host: null == host ? _self.host : host // ignore: cast_nullable_to_non_nullable
as String,port: null == port ? _self.port : port // ignore: cast_nullable_to_non_nullable
as int,token: null == token ? _self.token : token // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [QrPayload].
extension QrPayloadPatterns on QrPayload {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _QrPayload value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _QrPayload() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _QrPayload value)  $default,){
final _that = this;
switch (_that) {
case _QrPayload():
return $default(_that);}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _QrPayload value)?  $default,){
final _that = this;
switch (_that) {
case _QrPayload() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int v,  String deviceId,  String deviceName,  String host,  int port,  String token)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _QrPayload() when $default != null:
return $default(_that.v,_that.deviceId,_that.deviceName,_that.host,_that.port,_that.token);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int v,  String deviceId,  String deviceName,  String host,  int port,  String token)  $default,) {final _that = this;
switch (_that) {
case _QrPayload():
return $default(_that.v,_that.deviceId,_that.deviceName,_that.host,_that.port,_that.token);}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int v,  String deviceId,  String deviceName,  String host,  int port,  String token)?  $default,) {final _that = this;
switch (_that) {
case _QrPayload() when $default != null:
return $default(_that.v,_that.deviceId,_that.deviceName,_that.host,_that.port,_that.token);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _QrPayload implements QrPayload {
  const _QrPayload({required this.v, required this.deviceId, required this.deviceName, required this.host, required this.port, required this.token});
  factory _QrPayload.fromJson(Map<String, dynamic> json) => _$QrPayloadFromJson(json);

@override final  int v;
@override final  String deviceId;
@override final  String deviceName;
@override final  String host;
@override final  int port;
@override final  String token;

/// Create a copy of QrPayload
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$QrPayloadCopyWith<_QrPayload> get copyWith => __$QrPayloadCopyWithImpl<_QrPayload>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$QrPayloadToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _QrPayload&&(identical(other.v, v) || other.v == v)&&(identical(other.deviceId, deviceId) || other.deviceId == deviceId)&&(identical(other.deviceName, deviceName) || other.deviceName == deviceName)&&(identical(other.host, host) || other.host == host)&&(identical(other.port, port) || other.port == port)&&(identical(other.token, token) || other.token == token));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,v,deviceId,deviceName,host,port,token);

@override
String toString() {
  return 'QrPayload(v: $v, deviceId: $deviceId, deviceName: $deviceName, host: $host, port: $port, token: $token)';
}


}

/// @nodoc
abstract mixin class _$QrPayloadCopyWith<$Res> implements $QrPayloadCopyWith<$Res> {
  factory _$QrPayloadCopyWith(_QrPayload value, $Res Function(_QrPayload) _then) = __$QrPayloadCopyWithImpl;
@override @useResult
$Res call({
 int v, String deviceId, String deviceName, String host, int port, String token
});




}
/// @nodoc
class __$QrPayloadCopyWithImpl<$Res>
    implements _$QrPayloadCopyWith<$Res> {
  __$QrPayloadCopyWithImpl(this._self, this._then);

  final _QrPayload _self;
  final $Res Function(_QrPayload) _then;

/// Create a copy of QrPayload
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? v = null,Object? deviceId = null,Object? deviceName = null,Object? host = null,Object? port = null,Object? token = null,}) {
  return _then(_QrPayload(
v: null == v ? _self.v : v // ignore: cast_nullable_to_non_nullable
as int,deviceId: null == deviceId ? _self.deviceId : deviceId // ignore: cast_nullable_to_non_nullable
as String,deviceName: null == deviceName ? _self.deviceName : deviceName // ignore: cast_nullable_to_non_nullable
as String,host: null == host ? _self.host : host // ignore: cast_nullable_to_non_nullable
as String,port: null == port ? _self.port : port // ignore: cast_nullable_to_non_nullable
as int,token: null == token ? _self.token : token // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
