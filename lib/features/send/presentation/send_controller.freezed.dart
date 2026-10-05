// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'send_controller.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$SendState implements DiagnosticableTreeMixin {

 SendStatus get status; SelectedDevice? get selectedDevice; String? get errorMessage;
/// Create a copy of SendState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SendStateCopyWith<SendState> get copyWith => _$SendStateCopyWithImpl<SendState>(this as SendState, _$identity);


@override
void debugFillProperties(DiagnosticPropertiesBuilder properties) {
  properties
    ..add(DiagnosticsProperty('type', 'SendState'))
    ..add(DiagnosticsProperty('status', status))..add(DiagnosticsProperty('selectedDevice', selectedDevice))..add(DiagnosticsProperty('errorMessage', errorMessage));
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SendState&&(identical(other.status, status) || other.status == status)&&(identical(other.selectedDevice, selectedDevice) || other.selectedDevice == selectedDevice)&&(identical(other.errorMessage, errorMessage) || other.errorMessage == errorMessage));
}


@override
int get hashCode => Object.hash(runtimeType,status,selectedDevice,errorMessage);

@override
String toString({ DiagnosticLevel minLevel = DiagnosticLevel.info }) {
  return 'SendState(status: $status, selectedDevice: $selectedDevice, errorMessage: $errorMessage)';
}


}

/// @nodoc
abstract mixin class $SendStateCopyWith<$Res>  {
  factory $SendStateCopyWith(SendState value, $Res Function(SendState) _then) = _$SendStateCopyWithImpl;
@useResult
$Res call({
 SendStatus status, SelectedDevice? selectedDevice, String? errorMessage
});




}
/// @nodoc
class _$SendStateCopyWithImpl<$Res>
    implements $SendStateCopyWith<$Res> {
  _$SendStateCopyWithImpl(this._self, this._then);

  final SendState _self;
  final $Res Function(SendState) _then;

/// Create a copy of SendState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? status = null,Object? selectedDevice = freezed,Object? errorMessage = freezed,}) {
  return _then(_self.copyWith(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as SendStatus,selectedDevice: freezed == selectedDevice ? _self.selectedDevice : selectedDevice // ignore: cast_nullable_to_non_nullable
as SelectedDevice?,errorMessage: freezed == errorMessage ? _self.errorMessage : errorMessage // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [SendState].
extension SendStatePatterns on SendState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SendState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SendState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SendState value)  $default,){
final _that = this;
switch (_that) {
case _SendState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SendState value)?  $default,){
final _that = this;
switch (_that) {
case _SendState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( SendStatus status,  SelectedDevice? selectedDevice,  String? errorMessage)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SendState() when $default != null:
return $default(_that.status,_that.selectedDevice,_that.errorMessage);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( SendStatus status,  SelectedDevice? selectedDevice,  String? errorMessage)  $default,) {final _that = this;
switch (_that) {
case _SendState():
return $default(_that.status,_that.selectedDevice,_that.errorMessage);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( SendStatus status,  SelectedDevice? selectedDevice,  String? errorMessage)?  $default,) {final _that = this;
switch (_that) {
case _SendState() when $default != null:
return $default(_that.status,_that.selectedDevice,_that.errorMessage);case _:
  return null;

}
}

}

/// @nodoc


class _SendState with DiagnosticableTreeMixin implements SendState {
  const _SendState({this.status = SendStatus.idle, this.selectedDevice, this.errorMessage});
  

@override@JsonKey() final  SendStatus status;
@override final  SelectedDevice? selectedDevice;
@override final  String? errorMessage;

/// Create a copy of SendState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SendStateCopyWith<_SendState> get copyWith => __$SendStateCopyWithImpl<_SendState>(this, _$identity);


@override
void debugFillProperties(DiagnosticPropertiesBuilder properties) {
  properties
    ..add(DiagnosticsProperty('type', 'SendState'))
    ..add(DiagnosticsProperty('status', status))..add(DiagnosticsProperty('selectedDevice', selectedDevice))..add(DiagnosticsProperty('errorMessage', errorMessage));
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SendState&&(identical(other.status, status) || other.status == status)&&(identical(other.selectedDevice, selectedDevice) || other.selectedDevice == selectedDevice)&&(identical(other.errorMessage, errorMessage) || other.errorMessage == errorMessage));
}


@override
int get hashCode => Object.hash(runtimeType,status,selectedDevice,errorMessage);

@override
String toString({ DiagnosticLevel minLevel = DiagnosticLevel.info }) {
  return 'SendState(status: $status, selectedDevice: $selectedDevice, errorMessage: $errorMessage)';
}


}

/// @nodoc
abstract mixin class _$SendStateCopyWith<$Res> implements $SendStateCopyWith<$Res> {
  factory _$SendStateCopyWith(_SendState value, $Res Function(_SendState) _then) = __$SendStateCopyWithImpl;
@override @useResult
$Res call({
 SendStatus status, SelectedDevice? selectedDevice, String? errorMessage
});




}
/// @nodoc
class __$SendStateCopyWithImpl<$Res>
    implements _$SendStateCopyWith<$Res> {
  __$SendStateCopyWithImpl(this._self, this._then);

  final _SendState _self;
  final $Res Function(_SendState) _then;

/// Create a copy of SendState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? status = null,Object? selectedDevice = freezed,Object? errorMessage = freezed,}) {
  return _then(_SendState(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as SendStatus,selectedDevice: freezed == selectedDevice ? _self.selectedDevice : selectedDevice // ignore: cast_nullable_to_non_nullable
as SelectedDevice?,errorMessage: freezed == errorMessage ? _self.errorMessage : errorMessage // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
