// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'transfer_controller.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$TransferState implements DiagnosticableTreeMixin {

 TransferStatus get status; TransferDestination? get destination; List<SelectedFile> get files; Failure? get error;
/// Create a copy of TransferState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TransferStateCopyWith<TransferState> get copyWith => _$TransferStateCopyWithImpl<TransferState>(this as TransferState, _$identity);


@override
void debugFillProperties(DiagnosticPropertiesBuilder properties) {
  properties
    ..add(DiagnosticsProperty('type', 'TransferState'))
    ..add(DiagnosticsProperty('status', status))..add(DiagnosticsProperty('destination', destination))..add(DiagnosticsProperty('files', files))..add(DiagnosticsProperty('error', error));
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TransferState&&(identical(other.status, status) || other.status == status)&&(identical(other.destination, destination) || other.destination == destination)&&const DeepCollectionEquality().equals(other.files, files)&&(identical(other.error, error) || other.error == error));
}


@override
int get hashCode => Object.hash(runtimeType,status,destination,const DeepCollectionEquality().hash(files),error);

@override
String toString({ DiagnosticLevel minLevel = DiagnosticLevel.info }) {
  return 'TransferState(status: $status, destination: $destination, files: $files, error: $error)';
}


}

/// @nodoc
abstract mixin class $TransferStateCopyWith<$Res>  {
  factory $TransferStateCopyWith(TransferState value, $Res Function(TransferState) _then) = _$TransferStateCopyWithImpl;
@useResult
$Res call({
 TransferStatus status, TransferDestination? destination, List<SelectedFile> files, Failure? error
});




}
/// @nodoc
class _$TransferStateCopyWithImpl<$Res>
    implements $TransferStateCopyWith<$Res> {
  _$TransferStateCopyWithImpl(this._self, this._then);

  final TransferState _self;
  final $Res Function(TransferState) _then;

/// Create a copy of TransferState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? status = null,Object? destination = freezed,Object? files = null,Object? error = freezed,}) {
  return _then(_self.copyWith(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as TransferStatus,destination: freezed == destination ? _self.destination : destination // ignore: cast_nullable_to_non_nullable
as TransferDestination?,files: null == files ? _self.files : files // ignore: cast_nullable_to_non_nullable
as List<SelectedFile>,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as Failure?,
  ));
}

}


/// Adds pattern-matching-related methods to [TransferState].
extension TransferStatePatterns on TransferState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TransferState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TransferState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TransferState value)  $default,){
final _that = this;
switch (_that) {
case _TransferState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TransferState value)?  $default,){
final _that = this;
switch (_that) {
case _TransferState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( TransferStatus status,  TransferDestination? destination,  List<SelectedFile> files,  Failure? error)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TransferState() when $default != null:
return $default(_that.status,_that.destination,_that.files,_that.error);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( TransferStatus status,  TransferDestination? destination,  List<SelectedFile> files,  Failure? error)  $default,) {final _that = this;
switch (_that) {
case _TransferState():
return $default(_that.status,_that.destination,_that.files,_that.error);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( TransferStatus status,  TransferDestination? destination,  List<SelectedFile> files,  Failure? error)?  $default,) {final _that = this;
switch (_that) {
case _TransferState() when $default != null:
return $default(_that.status,_that.destination,_that.files,_that.error);case _:
  return null;

}
}

}

/// @nodoc


class _TransferState with DiagnosticableTreeMixin implements TransferState {
  const _TransferState({this.status = TransferStatus.initial, this.destination, final  List<SelectedFile> files = const <SelectedFile>[], this.error}): _files = files;
  

@override@JsonKey() final  TransferStatus status;
@override final  TransferDestination? destination;
 final  List<SelectedFile> _files;
@override@JsonKey() List<SelectedFile> get files {
  if (_files is EqualUnmodifiableListView) return _files;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_files);
}

@override final  Failure? error;

/// Create a copy of TransferState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TransferStateCopyWith<_TransferState> get copyWith => __$TransferStateCopyWithImpl<_TransferState>(this, _$identity);


@override
void debugFillProperties(DiagnosticPropertiesBuilder properties) {
  properties
    ..add(DiagnosticsProperty('type', 'TransferState'))
    ..add(DiagnosticsProperty('status', status))..add(DiagnosticsProperty('destination', destination))..add(DiagnosticsProperty('files', files))..add(DiagnosticsProperty('error', error));
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TransferState&&(identical(other.status, status) || other.status == status)&&(identical(other.destination, destination) || other.destination == destination)&&const DeepCollectionEquality().equals(other._files, _files)&&(identical(other.error, error) || other.error == error));
}


@override
int get hashCode => Object.hash(runtimeType,status,destination,const DeepCollectionEquality().hash(_files),error);

@override
String toString({ DiagnosticLevel minLevel = DiagnosticLevel.info }) {
  return 'TransferState(status: $status, destination: $destination, files: $files, error: $error)';
}


}

/// @nodoc
abstract mixin class _$TransferStateCopyWith<$Res> implements $TransferStateCopyWith<$Res> {
  factory _$TransferStateCopyWith(_TransferState value, $Res Function(_TransferState) _then) = __$TransferStateCopyWithImpl;
@override @useResult
$Res call({
 TransferStatus status, TransferDestination? destination, List<SelectedFile> files, Failure? error
});




}
/// @nodoc
class __$TransferStateCopyWithImpl<$Res>
    implements _$TransferStateCopyWith<$Res> {
  __$TransferStateCopyWithImpl(this._self, this._then);

  final _TransferState _self;
  final $Res Function(_TransferState) _then;

/// Create a copy of TransferState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? status = null,Object? destination = freezed,Object? files = null,Object? error = freezed,}) {
  return _then(_TransferState(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as TransferStatus,destination: freezed == destination ? _self.destination : destination // ignore: cast_nullable_to_non_nullable
as TransferDestination?,files: null == files ? _self._files : files // ignore: cast_nullable_to_non_nullable
as List<SelectedFile>,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as Failure?,
  ));
}


}

// dart format on
