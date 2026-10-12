// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'wire_transfer_id.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$WireTransferId {

 String get value;
/// Create a copy of WireTransferId
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$WireTransferIdCopyWith<WireTransferId> get copyWith => _$WireTransferIdCopyWithImpl<WireTransferId>(this as WireTransferId, _$identity);

  /// Serializes this WireTransferId to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is WireTransferId&&(identical(other.value, value) || other.value == value));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,value);

@override
String toString() {
  return 'WireTransferId(value: $value)';
}


}

/// @nodoc
abstract mixin class $WireTransferIdCopyWith<$Res>  {
  factory $WireTransferIdCopyWith(WireTransferId value, $Res Function(WireTransferId) _then) = _$WireTransferIdCopyWithImpl;
@useResult
$Res call({
 String value
});




}
/// @nodoc
class _$WireTransferIdCopyWithImpl<$Res>
    implements $WireTransferIdCopyWith<$Res> {
  _$WireTransferIdCopyWithImpl(this._self, this._then);

  final WireTransferId _self;
  final $Res Function(WireTransferId) _then;

/// Create a copy of WireTransferId
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? value = null,}) {
  return _then(_self.copyWith(
value: null == value ? _self.value : value // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [WireTransferId].
extension WireTransferIdPatterns on WireTransferId {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _WireTransferId value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _WireTransferId() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _WireTransferId value)  $default,){
final _that = this;
switch (_that) {
case _WireTransferId():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _WireTransferId value)?  $default,){
final _that = this;
switch (_that) {
case _WireTransferId() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String value)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _WireTransferId() when $default != null:
return $default(_that.value);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String value)  $default,) {final _that = this;
switch (_that) {
case _WireTransferId():
return $default(_that.value);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String value)?  $default,) {final _that = this;
switch (_that) {
case _WireTransferId() when $default != null:
return $default(_that.value);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _WireTransferId implements WireTransferId {
  const _WireTransferId(this.value);
  factory _WireTransferId.fromJson(Map<String, dynamic> json) => _$WireTransferIdFromJson(json);

@override final  String value;

/// Create a copy of WireTransferId
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$WireTransferIdCopyWith<_WireTransferId> get copyWith => __$WireTransferIdCopyWithImpl<_WireTransferId>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$WireTransferIdToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _WireTransferId&&(identical(other.value, value) || other.value == value));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,value);

@override
String toString() {
  return 'WireTransferId(value: $value)';
}


}

/// @nodoc
abstract mixin class _$WireTransferIdCopyWith<$Res> implements $WireTransferIdCopyWith<$Res> {
  factory _$WireTransferIdCopyWith(_WireTransferId value, $Res Function(_WireTransferId) _then) = __$WireTransferIdCopyWithImpl;
@override @useResult
$Res call({
 String value
});




}
/// @nodoc
class __$WireTransferIdCopyWithImpl<$Res>
    implements _$WireTransferIdCopyWith<$Res> {
  __$WireTransferIdCopyWithImpl(this._self, this._then);

  final _WireTransferId _self;
  final $Res Function(_WireTransferId) _then;

/// Create a copy of WireTransferId
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? value = null,}) {
  return _then(_WireTransferId(
null == value ? _self.value : value // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
