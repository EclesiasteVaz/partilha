import 'dart:convert';

import 'package:partilha/core/errors/failure.dart';
import 'package:partilha/core/protocol/control_message.dart';

/// The outcome of reading one control frame.
///
/// Three cases because the protocol genuinely has three outcomes for a frame, and
/// collapsing them would force a caller to re-derive the distinction: a frame can
/// be understood, understood as something new, or rejected.
sealed class DecodedControl {
  const DecodedControl();
}

/// The message was understood.
final class ControlDecoded extends DecodedControl {
  const ControlDecoded(this.message, {this.error});

  final ControlMessage message;

  /// The error body, when this is an `error` message.
  ///
  /// `null` for every other type. A recognised code is the only thing that
  /// carries a local [Failure]; an unrecognised one stays unrecognised so §27.1
  /// can apply.
  ///
  /// Parsed by the codec rather than derived on access, so that reading it cannot
  /// fail on a message that was already accepted as well formed.
  final ProtocolError? error;
}

/// The `type` is not one this build knows. Log and ignore (§27.1).
final class ControlUnknownType extends DecodedControl {
  const ControlUnknownType(this.type);

  /// The unrecognised discriminator, for logging.
  final String type;
}

/// The frame violates the envelope contract. Close the connection (§28).
final class ControlMalformed extends DecodedControl {
  const ControlMalformed(this.reason);

  /// A short, log-safe description of what was wrong.
  ///
  /// Never the raw frame: it is untrusted input and may carry a token or file
  /// names, and logging it verbatim would write those to disk (§52).
  final String reason;
}

/// Reads control frames as untrusted input.
///
/// This is the trust boundary for the control channel, and it is deliberately the
/// only place JSON is parsed. Nothing above it sees a map, and nothing below it
/// assumes its input was well formed.
abstract final class ControlMessageCodec {
  /// Decodes one JSON text frame.
  static DecodedControl decode(String frame) {
    final Object? parsed;
    try {
      parsed = jsonDecode(frame);
    } on FormatException catch (error) {
      return ControlMalformed('not valid JSON: ${error.message}');
    }

    if (parsed is! Map<String, Object?>) {
      return const ControlMalformed('envelope is not a JSON object');
    }

    final type = parsed['type'];
    if (type is! String || type.isEmpty) {
      return const ControlMalformed(
        'type is missing or not a non-empty string',
      );
    }

    final id = parsed['id'];
    if (id is! String || id.isEmpty) {
      return ControlMalformed('message "$type" has a missing or empty id');
    }

    // §41.2 requires the field to be present. Tolerating its absence would make
    // the contract unenforceable, since the two cases would behave identically.
    if (!parsed.containsKey('payload')) {
      return ControlMalformed('message "$type" has no payload');
    }
    final payload = parsed['payload'];
    if (payload is! Map<String, Object?>) {
      return ControlMalformed(
        'message "$type" has a payload that is not an object',
      );
    }

    final message = ControlMessage(type: type, id: id, payload: payload);

    if (type == 'error') {
      return _decodeError(message);
    }
    return ControlDecoded(message);
  }

  /// Builds the `error` message for [code], answering request [id].
  ///
  /// The error body is the payload itself (§14.1), not a field nested inside it:
  /// an `error` message has exactly one meaning, so wrapping its body in a
  /// container would describe nothing.
  static ControlMessage errorMessage({
    required String id,
    required ProtocolErrorCode code,
    String? message,
  }) => ControlMessage(
    type: 'error',
    id: id,
    payload: errorPayload(code, message: message),
  );

  static DecodedControl _decodeError(ControlMessage message) {
    // The payload is the error body (§14.1).
    final rawCode = message.payload['code'];
    if (rawCode is! String || rawCode.isEmpty) {
      return const ControlMalformed(
        'error message has a missing or empty code',
      );
    }

    final detail = message.payload['message'];

    // An unrecognised code is not a malformed message. The peer is speaking a
    // dialect this build does not have, which §27.1 says to tolerate: the
    // original value is preserved so it can be logged and diagnosed.
    return ControlDecoded(
      message,
      error: ProtocolError(
        code: ProtocolErrorCode.tryParse(rawCode),
        rawCode: rawCode,
        message: detail is String ? detail : null,
      ),
    );
  }
}
