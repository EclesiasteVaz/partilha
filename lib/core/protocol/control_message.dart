import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:partilha/core/errors/failure.dart';

part 'control_message.freezed.dart';
part 'control_message.g.dart';

/// The fixed set of error codes the protocol may put on the wire.
///
/// Approved in `docs/PROTOCOL.md` §14.2 as the minimal set, every member traceable
/// to a `Failure` constant that already exists. `cancelled` is absent on purpose:
/// cancellation is its own message, not an error.
enum ProtocolErrorCode {
  /// The peer sent something that violates the wire contract (§28).
  invalidMessage,

  /// The token was not accepted, so this device is not paired (§37).
  notPaired,

  /// The user declined the transfer request (§14).
  transferRejected,

  /// The receiver does not have room for the file (§22).
  insufficientStorage,

  /// The peer does not offer what the request needs (§10).
  unsupported;

  /// The exact string that appears on the wire.
  String get wireValue => switch (this) {
    ProtocolErrorCode.invalidMessage => 'invalid_message',
    ProtocolErrorCode.notPaired => 'not_paired',
    ProtocolErrorCode.transferRejected => 'transfer_rejected',
    ProtocolErrorCode.insufficientStorage => 'insufficient_storage',
    ProtocolErrorCode.unsupported => 'unsupported',
  };

  /// Parses a wire value, or `null` when it is not a code this build knows.
  ///
  /// Returning `null` rather than throwing is what lets §27.1 apply: a code
  /// added by a future peer is unrecognised, not fatal.
  static ProtocolErrorCode? tryParse(String value) {
    for (final code in ProtocolErrorCode.values) {
      if (code.wireValue == value) return code;
    }
    return null;
  }

  /// The failure this code maps to, for the sender's own error model.
  ///
  /// The mapping is the reason §14.2 could be a derivation instead of an
  /// invention; keeping it in code makes the two sides impossible to drift.
  Failure get failure => switch (this) {
    ProtocolErrorCode.invalidMessage => TransferFailure.protocolViolation,
    ProtocolErrorCode.notPaired => PairingFailure.rejected,
    ProtocolErrorCode.transferRejected => TransferFailure.remoteRejected,
    ProtocolErrorCode.insufficientStorage => StorageFailure.insufficientSpace,
    ProtocolErrorCode.unsupported => TransferFailure.remoteRejected,
  };
}

/// Every control message shares one envelope.
///
/// Approved in `docs/PROTOCOL.md` §41.2. `payload` is always present, `{}` when
/// empty, so decoding never has to tell "absent" from "empty". `id` is not
/// optional because it is what correlates a response or an error with its
/// request.
///
/// This models the envelope only. The `type` field is deliberately not an enum:
/// which message types exist is still open pending the handshake, and binding the
/// set now would make every schema change a transport contract change.
@freezed
sealed class ControlMessage with _$ControlMessage {
  const factory ControlMessage({
    /// The `snake_case` discriminator (§41.1).
    required String type,

    /// Correlates a response or an error with its request.
    required String id,

    /// The message's own fields. Always present, `{}` when empty.
    @Default(<String, Object?>{}) Map<String, Object?> payload,
  }) = _ControlMessage;

  factory ControlMessage.fromJson(Map<String, Object?> json) =>
      _$ControlMessageFromJson(json);

  /// Present so Freezed treats the body below as belonging to this class rather
  /// than to the generated mixin, which is what allows the getters.
  const ControlMessage._();

  /// Whether this message reports a failure, per §14.1.
  bool get isError => type == 'error';
}

/// The body of an `error` message.
@freezed
sealed class ProtocolError with _$ProtocolError {
  const factory ProtocolError({
    /// Null when the peer sent a code this build does not know, which §27.1
    /// treats as an unknown message rather than a failure.
    required ProtocolErrorCode? code,

    /// The value exactly as it arrived, kept so an unrecognised code can still be
    /// logged.
    ///
    /// Never sent: it is a decode-time artifact, and sending it would put two
    /// representations of the same code on the wire.
    required String rawCode,

    /// Human-readable detail. Never shown verbatim to a user; the local failure's
    /// own message is used instead (§83).
    String? message,
  }) = _ProtocolError;

  // No fromJson on purpose. An unrecognised code arrives as a string this build
  // cannot turn into an enum, which is exactly why §27.1 tolerates it. Parsing is
  // therefore the codec's job, where the distinction is visible; a generated
  // constructor would have to either throw on a valid frame or silently
  // substitute a wrong code.
  //
  // There is no toJson either, for the same reason in the other direction:
  // [errorPayload] is the single place an error frame is built, so a second
  // serialiser could only disagree with it.
  //
  // That also leaves no need for @JsonValue on the enum: [wireValue] is the only
  // definition of the wire spelling, so there is nothing to drift out of sync.

  /// See [ControlMessage._].
  const ProtocolError._();

  /// Whether this error came from a code this build understands.
  bool get isRecognised => code != null;

  /// The local failure for a recognised code.
  ///
  /// Null for an unrecognised code: §27.1 says such an error is tolerated, so
  /// there is nothing local to report.
  Failure? get failure => code?.failure;
}

/// Builds the payload of an `error` message from [code].
Map<String, Object?> errorPayload(ProtocolErrorCode code, {String? message}) =>
    <String, Object?>{'code': code.wireValue, 'message': ?message};
