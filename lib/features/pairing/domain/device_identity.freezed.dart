// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'device_identity.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$DeviceIdentity {

 String get deviceId; String get token;
/// Create a copy of DeviceIdentity
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DeviceIdentityCopyWith<DeviceIdentity> get copyWith => _$DeviceIdentityCopyWithImpl<DeviceIdentity>(this as DeviceIdentity, _$identity);

  /// Serializes this DeviceIdentity to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DeviceIdentity&&(identical(other.deviceId, deviceId) || other.deviceId == deviceId)&&(identical(other.token, token) || other.token == token));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,deviceId,token);

@override
String toString() {
  return 'DeviceIdentity(deviceId: $deviceId, token: $token)';
}


}

/// @nodoc
abstract mixin class $DeviceIdentityCopyWith<$Res>  {
  factory $DeviceIdentityCopyWith(DeviceIdentity value, $Res Function(DeviceIdentity) _then) = _$DeviceIdentityCopyWithImpl;
@useResult
$Res call({
 String deviceId, String token
});




}
/// @nodoc
class _$DeviceIdentityCopyWithImpl<$Res>
    implements $DeviceIdentityCopyWith<$Res> {
  _$DeviceIdentityCopyWithImpl(this._self, this._then);

  final DeviceIdentity _self;
  final $Res Function(DeviceIdentity) _then;

/// Create a copy of DeviceIdentity
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? deviceId = null,Object? token = null,}) {
  return _then(_self.copyWith(
deviceId: null == deviceId ? _self.deviceId : deviceId // ignore: cast_nullable_to_non_nullable
as String,token: null == token ? _self.token : token // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [DeviceIdentity].
extension DeviceIdentityPatterns on DeviceIdentity {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _DeviceIdentity value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _DeviceIdentity() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _DeviceIdentity value)  $default,){
final _that = this;
switch (_that) {
case _DeviceIdentity():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _DeviceIdentity value)?  $default,){
final _that = this;
switch (_that) {
case _DeviceIdentity() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String deviceId,  String token)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _DeviceIdentity() when $default != null:
return $default(_that.deviceId,_that.token);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String deviceId,  String token)  $default,) {final _that = this;
switch (_that) {
case _DeviceIdentity():
return $default(_that.deviceId,_that.token);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String deviceId,  String token)?  $default,) {final _that = this;
switch (_that) {
case _DeviceIdentity() when $default != null:
return $default(_that.deviceId,_that.token);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _DeviceIdentity implements DeviceIdentity {
  const _DeviceIdentity({required this.deviceId, required this.token});
  factory _DeviceIdentity.fromJson(Map<String, dynamic> json) => _$DeviceIdentityFromJson(json);

@override final  String deviceId;
@override final  String token;

/// Create a copy of DeviceIdentity
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DeviceIdentityCopyWith<_DeviceIdentity> get copyWith => __$DeviceIdentityCopyWithImpl<_DeviceIdentity>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$DeviceIdentityToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _DeviceIdentity&&(identical(other.deviceId, deviceId) || other.deviceId == deviceId)&&(identical(other.token, token) || other.token == token));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,deviceId,token);

@override
String toString() {
  return 'DeviceIdentity(deviceId: $deviceId, token: $token)';
}


}

/// @nodoc
abstract mixin class _$DeviceIdentityCopyWith<$Res> implements $DeviceIdentityCopyWith<$Res> {
  factory _$DeviceIdentityCopyWith(_DeviceIdentity value, $Res Function(_DeviceIdentity) _then) = __$DeviceIdentityCopyWithImpl;
@override @useResult
$Res call({
 String deviceId, String token
});




}
/// @nodoc
class __$DeviceIdentityCopyWithImpl<$Res>
    implements _$DeviceIdentityCopyWith<$Res> {
  __$DeviceIdentityCopyWithImpl(this._self, this._then);

  final _DeviceIdentity _self;
  final $Res Function(_DeviceIdentity) _then;

/// Create a copy of DeviceIdentity
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? deviceId = null,Object? token = null,}) {
  return _then(_DeviceIdentity(
deviceId: null == deviceId ? _self.deviceId : deviceId // ignore: cast_nullable_to_non_nullable
as String,token: null == token ? _self.token : token // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
