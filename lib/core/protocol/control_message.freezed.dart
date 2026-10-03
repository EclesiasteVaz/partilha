// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'control_message.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ControlMessage {

/// The `snake_case` discriminator (§41.1).
 String get type;/// Correlates a response or an error with its request.
 String get id;/// The message's own fields. Always present, `{}` when empty.
 Map<String, Object?> get payload;
/// Create a copy of ControlMessage
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ControlMessageCopyWith<ControlMessage> get copyWith => _$ControlMessageCopyWithImpl<ControlMessage>(this as ControlMessage, _$identity);

  /// Serializes this ControlMessage to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ControlMessage&&(identical(other.type, type) || other.type == type)&&(identical(other.id, id) || other.id == id)&&const DeepCollectionEquality().equals(other.payload, payload));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,type,id,const DeepCollectionEquality().hash(payload));

@override
String toString() {
  return 'ControlMessage(type: $type, id: $id, payload: $payload)';
}


}

/// @nodoc
abstract mixin class $ControlMessageCopyWith<$Res>  {
  factory $ControlMessageCopyWith(ControlMessage value, $Res Function(ControlMessage) _then) = _$ControlMessageCopyWithImpl;
@useResult
$Res call({
 String type, String id, Map<String, Object?> payload
});




}
/// @nodoc
class _$ControlMessageCopyWithImpl<$Res>
    implements $ControlMessageCopyWith<$Res> {
  _$ControlMessageCopyWithImpl(this._self, this._then);

  final ControlMessage _self;
  final $Res Function(ControlMessage) _then;

/// Create a copy of ControlMessage
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? type = null,Object? id = null,Object? payload = null,}) {
  return _then(_self.copyWith(
type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,payload: null == payload ? _self.payload : payload // ignore: cast_nullable_to_non_nullable
as Map<String, Object?>,
  ));
}

}


/// Adds pattern-matching-related methods to [ControlMessage].
extension ControlMessagePatterns on ControlMessage {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ControlMessage value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ControlMessage() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ControlMessage value)  $default,){
final _that = this;
switch (_that) {
case _ControlMessage():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ControlMessage value)?  $default,){
final _that = this;
switch (_that) {
case _ControlMessage() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String type,  String id,  Map<String, Object?> payload)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ControlMessage() when $default != null:
return $default(_that.type,_that.id,_that.payload);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String type,  String id,  Map<String, Object?> payload)  $default,) {final _that = this;
switch (_that) {
case _ControlMessage():
return $default(_that.type,_that.id,_that.payload);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String type,  String id,  Map<String, Object?> payload)?  $default,) {final _that = this;
switch (_that) {
case _ControlMessage() when $default != null:
return $default(_that.type,_that.id,_that.payload);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ControlMessage extends ControlMessage {
  const _ControlMessage({required this.type, required this.id, final  Map<String, Object?> payload = const <String, Object?>{}}): _payload = payload,super._();
  factory _ControlMessage.fromJson(Map<String, dynamic> json) => _$ControlMessageFromJson(json);

/// The `snake_case` discriminator (§41.1).
@override final  String type;
/// Correlates a response or an error with its request.
@override final  String id;
/// The message's own fields. Always present, `{}` when empty.
 final  Map<String, Object?> _payload;
/// The message's own fields. Always present, `{}` when empty.
@override@JsonKey() Map<String, Object?> get payload {
  if (_payload is EqualUnmodifiableMapView) return _payload;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_payload);
}


/// Create a copy of ControlMessage
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ControlMessageCopyWith<_ControlMessage> get copyWith => __$ControlMessageCopyWithImpl<_ControlMessage>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ControlMessageToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ControlMessage&&(identical(other.type, type) || other.type == type)&&(identical(other.id, id) || other.id == id)&&const DeepCollectionEquality().equals(other._payload, _payload));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,type,id,const DeepCollectionEquality().hash(_payload));

@override
String toString() {
  return 'ControlMessage(type: $type, id: $id, payload: $payload)';
}


}

/// @nodoc
abstract mixin class _$ControlMessageCopyWith<$Res> implements $ControlMessageCopyWith<$Res> {
  factory _$ControlMessageCopyWith(_ControlMessage value, $Res Function(_ControlMessage) _then) = __$ControlMessageCopyWithImpl;
@override @useResult
$Res call({
 String type, String id, Map<String, Object?> payload
});




}
/// @nodoc
class __$ControlMessageCopyWithImpl<$Res>
    implements _$ControlMessageCopyWith<$Res> {
  __$ControlMessageCopyWithImpl(this._self, this._then);

  final _ControlMessage _self;
  final $Res Function(_ControlMessage) _then;

/// Create a copy of ControlMessage
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? type = null,Object? id = null,Object? payload = null,}) {
  return _then(_ControlMessage(
type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,payload: null == payload ? _self._payload : payload // ignore: cast_nullable_to_non_nullable
as Map<String, Object?>,
  ));
}


}

/// @nodoc
mixin _$ProtocolError {

/// Null when the peer sent a code this build does not know, which §27.1
/// treats as an unknown message rather than a failure.
 ProtocolErrorCode? get code;/// The value exactly as it arrived, kept so an unrecognised code can still be
/// logged.
///
/// Never sent: it is a decode-time artifact, and sending it would put two
/// representations of the same code on the wire.
 String get rawCode;/// Human-readable detail. Never shown verbatim to a user; the local failure's
/// own message is used instead (§83).
 String? get message;
/// Create a copy of ProtocolError
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ProtocolErrorCopyWith<ProtocolError> get copyWith => _$ProtocolErrorCopyWithImpl<ProtocolError>(this as ProtocolError, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ProtocolError&&(identical(other.code, code) || other.code == code)&&(identical(other.rawCode, rawCode) || other.rawCode == rawCode)&&(identical(other.message, message) || other.message == message));
}


@override
int get hashCode => Object.hash(runtimeType,code,rawCode,message);

@override
String toString() {
  return 'ProtocolError(code: $code, rawCode: $rawCode, message: $message)';
}


}

/// @nodoc
abstract mixin class $ProtocolErrorCopyWith<$Res>  {
  factory $ProtocolErrorCopyWith(ProtocolError value, $Res Function(ProtocolError) _then) = _$ProtocolErrorCopyWithImpl;
@useResult
$Res call({
 ProtocolErrorCode? code, String rawCode, String? message
});




}
/// @nodoc
class _$ProtocolErrorCopyWithImpl<$Res>
    implements $ProtocolErrorCopyWith<$Res> {
  _$ProtocolErrorCopyWithImpl(this._self, this._then);

  final ProtocolError _self;
  final $Res Function(ProtocolError) _then;

/// Create a copy of ProtocolError
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? code = freezed,Object? rawCode = null,Object? message = freezed,}) {
  return _then(_self.copyWith(
code: freezed == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as ProtocolErrorCode?,rawCode: null == rawCode ? _self.rawCode : rawCode // ignore: cast_nullable_to_non_nullable
as String,message: freezed == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [ProtocolError].
extension ProtocolErrorPatterns on ProtocolError {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ProtocolError value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ProtocolError() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ProtocolError value)  $default,){
final _that = this;
switch (_that) {
case _ProtocolError():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ProtocolError value)?  $default,){
final _that = this;
switch (_that) {
case _ProtocolError() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( ProtocolErrorCode? code,  String rawCode,  String? message)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ProtocolError() when $default != null:
return $default(_that.code,_that.rawCode,_that.message);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( ProtocolErrorCode? code,  String rawCode,  String? message)  $default,) {final _that = this;
switch (_that) {
case _ProtocolError():
return $default(_that.code,_that.rawCode,_that.message);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( ProtocolErrorCode? code,  String rawCode,  String? message)?  $default,) {final _that = this;
switch (_that) {
case _ProtocolError() when $default != null:
return $default(_that.code,_that.rawCode,_that.message);case _:
  return null;

}
}

}

/// @nodoc


class _ProtocolError extends ProtocolError {
  const _ProtocolError({required this.code, required this.rawCode, this.message}): super._();
  

/// Null when the peer sent a code this build does not know, which §27.1
/// treats as an unknown message rather than a failure.
@override final  ProtocolErrorCode? code;
/// The value exactly as it arrived, kept so an unrecognised code can still be
/// logged.
///
/// Never sent: it is a decode-time artifact, and sending it would put two
/// representations of the same code on the wire.
@override final  String rawCode;
/// Human-readable detail. Never shown verbatim to a user; the local failure's
/// own message is used instead (§83).
@override final  String? message;

/// Create a copy of ProtocolError
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ProtocolErrorCopyWith<_ProtocolError> get copyWith => __$ProtocolErrorCopyWithImpl<_ProtocolError>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ProtocolError&&(identical(other.code, code) || other.code == code)&&(identical(other.rawCode, rawCode) || other.rawCode == rawCode)&&(identical(other.message, message) || other.message == message));
}


@override
int get hashCode => Object.hash(runtimeType,code,rawCode,message);

@override
String toString() {
  return 'ProtocolError(code: $code, rawCode: $rawCode, message: $message)';
}


}

/// @nodoc
abstract mixin class _$ProtocolErrorCopyWith<$Res> implements $ProtocolErrorCopyWith<$Res> {
  factory _$ProtocolErrorCopyWith(_ProtocolError value, $Res Function(_ProtocolError) _then) = __$ProtocolErrorCopyWithImpl;
@override @useResult
$Res call({
 ProtocolErrorCode? code, String rawCode, String? message
});




}
/// @nodoc
class __$ProtocolErrorCopyWithImpl<$Res>
    implements _$ProtocolErrorCopyWith<$Res> {
  __$ProtocolErrorCopyWithImpl(this._self, this._then);

  final _ProtocolError _self;
  final $Res Function(_ProtocolError) _then;

/// Create a copy of ProtocolError
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? code = freezed,Object? rawCode = null,Object? message = freezed,}) {
  return _then(_ProtocolError(
code: freezed == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as ProtocolErrorCode?,rawCode: null == rawCode ? _self.rawCode : rawCode // ignore: cast_nullable_to_non_nullable
as String,message: freezed == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
