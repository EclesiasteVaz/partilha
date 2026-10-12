// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'pairing_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$PairingState {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PairingState);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'PairingState()';
}


}

/// @nodoc
class $PairingStateCopyWith<$Res>  {
$PairingStateCopyWith(PairingState _, $Res Function(PairingState) __);
}


/// Adds pattern-matching-related methods to [PairingState].
extension PairingStatePatterns on PairingState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( PairingStateInitial value)?  initial,TResult Function( PairingStateGeneratingQr value)?  generatingQr,TResult Function( PairingStateShowingQr value)?  showingQr,TResult Function( PairingStateScanning value)?  scanning,TResult Function( PairingStateValidating value)?  validating,TResult Function( PairingStatePaired value)?  paired,TResult Function( PairingStateFailed value)?  failed,required TResult orElse(),}){
final _that = this;
switch (_that) {
case PairingStateInitial() when initial != null:
return initial(_that);case PairingStateGeneratingQr() when generatingQr != null:
return generatingQr(_that);case PairingStateShowingQr() when showingQr != null:
return showingQr(_that);case PairingStateScanning() when scanning != null:
return scanning(_that);case PairingStateValidating() when validating != null:
return validating(_that);case PairingStatePaired() when paired != null:
return paired(_that);case PairingStateFailed() when failed != null:
return failed(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( PairingStateInitial value)  initial,required TResult Function( PairingStateGeneratingQr value)  generatingQr,required TResult Function( PairingStateShowingQr value)  showingQr,required TResult Function( PairingStateScanning value)  scanning,required TResult Function( PairingStateValidating value)  validating,required TResult Function( PairingStatePaired value)  paired,required TResult Function( PairingStateFailed value)  failed,}){
final _that = this;
switch (_that) {
case PairingStateInitial():
return initial(_that);case PairingStateGeneratingQr():
return generatingQr(_that);case PairingStateShowingQr():
return showingQr(_that);case PairingStateScanning():
return scanning(_that);case PairingStateValidating():
return validating(_that);case PairingStatePaired():
return paired(_that);case PairingStateFailed():
return failed(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( PairingStateInitial value)?  initial,TResult? Function( PairingStateGeneratingQr value)?  generatingQr,TResult? Function( PairingStateShowingQr value)?  showingQr,TResult? Function( PairingStateScanning value)?  scanning,TResult? Function( PairingStateValidating value)?  validating,TResult? Function( PairingStatePaired value)?  paired,TResult? Function( PairingStateFailed value)?  failed,}){
final _that = this;
switch (_that) {
case PairingStateInitial() when initial != null:
return initial(_that);case PairingStateGeneratingQr() when generatingQr != null:
return generatingQr(_that);case PairingStateShowingQr() when showingQr != null:
return showingQr(_that);case PairingStateScanning() when scanning != null:
return scanning(_that);case PairingStateValidating() when validating != null:
return validating(_that);case PairingStatePaired() when paired != null:
return paired(_that);case PairingStateFailed() when failed != null:
return failed(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function()?  initial,TResult Function()?  generatingQr,TResult Function( QrPayload payload,  String rawQrString)?  showingQr,TResult Function()?  scanning,TResult Function()?  validating,TResult Function( PairingContext context)?  paired,TResult Function( Failure failure)?  failed,required TResult orElse(),}) {final _that = this;
switch (_that) {
case PairingStateInitial() when initial != null:
return initial();case PairingStateGeneratingQr() when generatingQr != null:
return generatingQr();case PairingStateShowingQr() when showingQr != null:
return showingQr(_that.payload,_that.rawQrString);case PairingStateScanning() when scanning != null:
return scanning();case PairingStateValidating() when validating != null:
return validating();case PairingStatePaired() when paired != null:
return paired(_that.context);case PairingStateFailed() when failed != null:
return failed(_that.failure);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function()  initial,required TResult Function()  generatingQr,required TResult Function( QrPayload payload,  String rawQrString)  showingQr,required TResult Function()  scanning,required TResult Function()  validating,required TResult Function( PairingContext context)  paired,required TResult Function( Failure failure)  failed,}) {final _that = this;
switch (_that) {
case PairingStateInitial():
return initial();case PairingStateGeneratingQr():
return generatingQr();case PairingStateShowingQr():
return showingQr(_that.payload,_that.rawQrString);case PairingStateScanning():
return scanning();case PairingStateValidating():
return validating();case PairingStatePaired():
return paired(_that.context);case PairingStateFailed():
return failed(_that.failure);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function()?  initial,TResult? Function()?  generatingQr,TResult? Function( QrPayload payload,  String rawQrString)?  showingQr,TResult? Function()?  scanning,TResult? Function()?  validating,TResult? Function( PairingContext context)?  paired,TResult? Function( Failure failure)?  failed,}) {final _that = this;
switch (_that) {
case PairingStateInitial() when initial != null:
return initial();case PairingStateGeneratingQr() when generatingQr != null:
return generatingQr();case PairingStateShowingQr() when showingQr != null:
return showingQr(_that.payload,_that.rawQrString);case PairingStateScanning() when scanning != null:
return scanning();case PairingStateValidating() when validating != null:
return validating();case PairingStatePaired() when paired != null:
return paired(_that.context);case PairingStateFailed() when failed != null:
return failed(_that.failure);case _:
  return null;

}
}

}

/// @nodoc


class PairingStateInitial implements PairingState {
  const PairingStateInitial();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PairingStateInitial);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'PairingState.initial()';
}


}




/// @nodoc


class PairingStateGeneratingQr implements PairingState {
  const PairingStateGeneratingQr();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PairingStateGeneratingQr);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'PairingState.generatingQr()';
}


}




/// @nodoc


class PairingStateShowingQr implements PairingState {
  const PairingStateShowingQr({required this.payload, required this.rawQrString});
  

 final  QrPayload payload;
 final  String rawQrString;

/// Create a copy of PairingState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PairingStateShowingQrCopyWith<PairingStateShowingQr> get copyWith => _$PairingStateShowingQrCopyWithImpl<PairingStateShowingQr>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PairingStateShowingQr&&(identical(other.payload, payload) || other.payload == payload)&&(identical(other.rawQrString, rawQrString) || other.rawQrString == rawQrString));
}


@override
int get hashCode => Object.hash(runtimeType,payload,rawQrString);

@override
String toString() {
  return 'PairingState.showingQr(payload: $payload, rawQrString: $rawQrString)';
}


}

/// @nodoc
abstract mixin class $PairingStateShowingQrCopyWith<$Res> implements $PairingStateCopyWith<$Res> {
  factory $PairingStateShowingQrCopyWith(PairingStateShowingQr value, $Res Function(PairingStateShowingQr) _then) = _$PairingStateShowingQrCopyWithImpl;
@useResult
$Res call({
 QrPayload payload, String rawQrString
});


$QrPayloadCopyWith<$Res> get payload;

}
/// @nodoc
class _$PairingStateShowingQrCopyWithImpl<$Res>
    implements $PairingStateShowingQrCopyWith<$Res> {
  _$PairingStateShowingQrCopyWithImpl(this._self, this._then);

  final PairingStateShowingQr _self;
  final $Res Function(PairingStateShowingQr) _then;

/// Create a copy of PairingState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? payload = null,Object? rawQrString = null,}) {
  return _then(PairingStateShowingQr(
payload: null == payload ? _self.payload : payload // ignore: cast_nullable_to_non_nullable
as QrPayload,rawQrString: null == rawQrString ? _self.rawQrString : rawQrString // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

/// Create a copy of PairingState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$QrPayloadCopyWith<$Res> get payload {
  
  return $QrPayloadCopyWith<$Res>(_self.payload, (value) {
    return _then(_self.copyWith(payload: value));
  });
}
}

/// @nodoc


class PairingStateScanning implements PairingState {
  const PairingStateScanning();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PairingStateScanning);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'PairingState.scanning()';
}


}




/// @nodoc


class PairingStateValidating implements PairingState {
  const PairingStateValidating();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PairingStateValidating);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'PairingState.validating()';
}


}




/// @nodoc


class PairingStatePaired implements PairingState {
  const PairingStatePaired({required this.context});
  

 final  PairingContext context;

/// Create a copy of PairingState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PairingStatePairedCopyWith<PairingStatePaired> get copyWith => _$PairingStatePairedCopyWithImpl<PairingStatePaired>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PairingStatePaired&&(identical(other.context, context) || other.context == context));
}


@override
int get hashCode => Object.hash(runtimeType,context);

@override
String toString() {
  return 'PairingState.paired(context: $context)';
}


}

/// @nodoc
abstract mixin class $PairingStatePairedCopyWith<$Res> implements $PairingStateCopyWith<$Res> {
  factory $PairingStatePairedCopyWith(PairingStatePaired value, $Res Function(PairingStatePaired) _then) = _$PairingStatePairedCopyWithImpl;
@useResult
$Res call({
 PairingContext context
});


$PairingContextCopyWith<$Res> get context;

}
/// @nodoc
class _$PairingStatePairedCopyWithImpl<$Res>
    implements $PairingStatePairedCopyWith<$Res> {
  _$PairingStatePairedCopyWithImpl(this._self, this._then);

  final PairingStatePaired _self;
  final $Res Function(PairingStatePaired) _then;

/// Create a copy of PairingState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? context = null,}) {
  return _then(PairingStatePaired(
context: null == context ? _self.context : context // ignore: cast_nullable_to_non_nullable
as PairingContext,
  ));
}

/// Create a copy of PairingState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PairingContextCopyWith<$Res> get context {
  
  return $PairingContextCopyWith<$Res>(_self.context, (value) {
    return _then(_self.copyWith(context: value));
  });
}
}

/// @nodoc


class PairingStateFailed implements PairingState {
  const PairingStateFailed({required this.failure});
  

 final  Failure failure;

/// Create a copy of PairingState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PairingStateFailedCopyWith<PairingStateFailed> get copyWith => _$PairingStateFailedCopyWithImpl<PairingStateFailed>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PairingStateFailed&&(identical(other.failure, failure) || other.failure == failure));
}


@override
int get hashCode => Object.hash(runtimeType,failure);

@override
String toString() {
  return 'PairingState.failed(failure: $failure)';
}


}

/// @nodoc
abstract mixin class $PairingStateFailedCopyWith<$Res> implements $PairingStateCopyWith<$Res> {
  factory $PairingStateFailedCopyWith(PairingStateFailed value, $Res Function(PairingStateFailed) _then) = _$PairingStateFailedCopyWithImpl;
@useResult
$Res call({
 Failure failure
});




}
/// @nodoc
class _$PairingStateFailedCopyWithImpl<$Res>
    implements $PairingStateFailedCopyWith<$Res> {
  _$PairingStateFailedCopyWithImpl(this._self, this._then);

  final PairingStateFailed _self;
  final $Res Function(PairingStateFailed) _then;

/// Create a copy of PairingState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? failure = null,}) {
  return _then(PairingStateFailed(
failure: null == failure ? _self.failure : failure // ignore: cast_nullable_to_non_nullable
as Failure,
  ));
}


}

// dart format on
