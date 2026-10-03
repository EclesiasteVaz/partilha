import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:partilha/core/errors/failure.dart';
import 'package:partilha/core/protocol/protocol.dart';

/// The codec is the trust boundary for the control channel, so these tests are
/// mostly about what it refuses: a frame is untrusted input and a permissive
/// decoder is how a peer reaches application state.
void main() {
  group('envelope happy path', () {
    test('decodes a well-formed envelope', () {
      final decoded = ControlMessageCodec.decode(
        '{"type":"transfer_request","id":"t-1","payload":{"size":10}}',
      );

      expect(decoded, isA<ControlDecoded>());
      final message = (decoded as ControlDecoded).message;
      expect(message.type, 'transfer_request');
      expect(message.id, 't-1');
      expect(message.payload['size'], 10);
    });

    test('an empty payload object is valid', () {
      final decoded = ControlMessageCodec.decode(
        '{"type":"transfer_accepted","id":"t-1","payload":{}}',
      );

      expect(decoded, isA<ControlDecoded>());
      expect((decoded as ControlDecoded).message.payload, isEmpty);
    });

    test('isError is true only for the error type', () {
      expect(
        ControlMessageCodec.errorMessage(
          id: 't-1',
          code: ProtocolErrorCode.invalidMessage,
        ).isError,
        isTrue,
      );
      expect(
        const ControlMessage(type: 'transfer_progress', id: 't-1').isError,
        isFalse,
      );
    });

    test('round-trips through JSON without losing fields', () {
      const original = ControlMessage(
        type: 'transfer_request',
        id: 't-1',
        payload: <String, Object?>{'fileName': 'photo.jpg', 'size': 1234},
      );

      final decoded = ControlMessage.fromJson(original.toJson());

      expect(decoded, original);
    });

    test(
      'ignores unknown top-level fields, which keeps it forward compatible',
      () {
        final decoded = ControlMessageCodec.decode(
          '{"type":"ping","id":"t-1","payload":{},"addedLater":true}',
        );

        expect(decoded, isA<ControlDecoded>());
        expect((decoded as ControlDecoded).message.type, 'ping');
      },
    );
  });

  group('malformed frames are rejected, never coerced', () {
    void expectMalformed(String frame) {
      final decoded = ControlMessageCodec.decode(frame);
      expect(
        decoded,
        isA<ControlMalformed>(),
        reason: 'expected "$frame" to be rejected',
      );
    }

    test('rejects text that is not JSON', () {
      expectMalformed('not json at all');
    });

    test('rejects JSON that is not an object', () {
      expectMalformed('[]');
      expectMalformed('"a string"');
      expectMalformed('42');
      expectMalformed('null');
    });

    test('rejects a missing or non-string type', () {
      expectMalformed('{"id":"t-1","payload":{}}');
      expectMalformed('{"type":7,"id":"t-1","payload":{}}');
      expectMalformed('{"type":"","id":"t-1","payload":{}}');
    });

    test('rejects a missing or empty id', () {
      // Without an id there is no way to answer a specific request (§41.2).
      expectMalformed('{"type":"ping","payload":{}}');
      expectMalformed('{"type":"ping","id":"","payload":{}}');
      expectMalformed('{"type":"ping","id":1,"payload":{}}');
    });

    test('rejects a missing payload rather than defaulting it', () {
      // §41.2 requires the field; tolerating absence would make the contract
      // unenforceable because the two cases would behave identically.
      expectMalformed('{"type":"ping","id":"t-1"}');
    });

    test('rejects a payload that is not an object', () {
      expectMalformed('{"type":"ping","id":"t-1","payload":"text"}');
      expectMalformed('{"type":"ping","id":"t-1","payload":[1,2]}');
    });

    test('rejects an error message with no usable code', () {
      // The payload is the error body (§14.1), so a missing, empty or non-string
      // code leaves the caller with nothing to act on.
      expectMalformed('{"type":"error","id":"t-1","payload":{}}');
      expectMalformed('{"type":"error","id":"t-1","payload":{"code":""}}');
      expectMalformed('{"type":"error","id":"t-1","payload":{"code":9}}');
      expectMalformed('{"type":"error","id":"t-1","payload":{"code":null}}');
    });

    test('the rejection reason never echoes the frame itself', () {
      // The frame is untrusted and may carry a token or file names; logging it
      // verbatim would write those to disk (§52).
      const frame =
          '{"type":"ping","token":"super-secret","payload":"not-an-object"}';
      final decoded = ControlMessageCodec.decode(frame) as ControlMalformed;

      expect(decoded.reason, isNot(contains('super-secret')));
    });
  });

  group('error messages', () {
    test('a recognised code maps to its typed failure', () {
      final decoded =
          ControlMessageCodec.decode(
                jsonEncode(<String, Object?>{
                  'type': 'error',
                  'id': 't-1',
                  'payload': <String, Object?>{
                    'code': 'insufficient_storage',
                    'message': 'no room',
                  },
                }),
              )
              as ControlDecoded;

      final error = decoded.error!;
      expect(error.isRecognised, isTrue);
      expect(error.code, ProtocolErrorCode.insufficientStorage);
      expect(error.failure, StorageFailure.insufficientSpace);
      expect(error.message, 'no room');
    });

    test(
      'the approved wire strings reach the wire, not the Dart enum names',
      () {
        // Regression guard: json_serializable writes an enum by its Dart name by
        // default, which would put "ProtocolErrorCode.notPaired" on the wire
        // instead of the approved "not_paired" (§2.4, §14.2).
        expect(errorPayload(ProtocolErrorCode.notPaired), <String, Object?>{
          'code': 'not_paired',
        });
        for (final code in ProtocolErrorCode.values) {
          expect(
            jsonEncode(errorPayload(code)),
            contains('"code":"${code.wireValue}"'),
            reason: '${code.name} must not leak its Dart name',
          );
        }
      },
    );

    test('an absent detail message omits the key instead of sending null', () {
      // §14.1 shows message as optional. Emitting `"message": null` would claim
      // the peer said something, when it said nothing.
      expect(
        errorPayload(ProtocolErrorCode.notPaired).containsKey('message'),
        isFalse,
      );
      expect(
        errorPayload(ProtocolErrorCode.notPaired, message: 'x').keys.toList(),
        <String>['code', 'message'],
      );
    });

    test('the payload carries only code and message', () {
      // errorPayload is the single place an error frame is built, so its keys are
      // the wire contract. rawCode is a decode-time artifact and must never be
      // sent, or the same code would travel in two representations.
      expect(
        errorPayload(
          ProtocolErrorCode.unsupported,
          message: 'why',
        ).keys.toList(),
        <String>['code', 'message'],
      );
    });

    test('every approved code has its own wire value and failure', () {
      // Guards against two codes collapsing onto one value, and against a code
      // that silently stops mapping to a failure (§14.2).
      final wireValues = ProtocolErrorCode.values.map((c) => c.wireValue);

      expect(wireValues.toSet(), hasLength(ProtocolErrorCode.values.length));
      for (final code in ProtocolErrorCode.values) {
        expect(code.failure, isA<Failure>());
        expect(ProtocolErrorCode.tryParse(code.wireValue), code);
      }
    });

    test('the approved codes are exactly the documented set', () {
      expect(
        ProtocolErrorCode.values.map((code) => code.wireValue).toList()..sort(),
        <String>[
          'insufficient_storage',
          'invalid_message',
          'not_paired',
          'transfer_rejected',
          'unsupported',
        ],
      );
    });

    test(
      'an unrecognised code is kept verbatim and carries no failure, so it is '
      'tolerated rather than treated as broken',
      () {
        final decoded =
            ControlMessageCodec.decode(
                  jsonEncode(<String, Object?>{
                    'type': 'error',
                    'id': 't-1',
                    'payload': <String, Object?>{'code': 'invented_later'},
                  }),
                )
                as ControlDecoded;

        final error = decoded.error!;
        expect(error.isRecognised, isFalse);
        expect(error.rawCode, 'invented_later');
        expect(error.failure, isNull);
      },
    );

    test('a non-string detail message is dropped rather than crashing', () {
      final decoded =
          ControlMessageCodec.decode(
                '{"type":"error","id":"t-1","payload":{"code":"not_paired",'
                '"message":42}}',
              )
              as ControlDecoded;

      expect(decoded.error!.message, isNull);
      expect(decoded.error!.isRecognised, isTrue);
    });

    test('the error body is the payload itself, not a field inside it', () {
      // §14.1 shows `"payload": {"code": ..., "message": ...}`. An `error` message
      // has a single meaning, so a nested container would describe nothing.
      final message = ControlMessageCodec.errorMessage(
        id: 't-9',
        code: ProtocolErrorCode.insufficientStorage,
        message: 'no room',
      );

      expect(message.payload['code'], 'insufficient_storage');
      expect(message.payload['message'], 'no room');
      expect(message.payload.containsKey('error'), isFalse);
    });

    test('errorMessage produces a frame the codec accepts', () {
      final message = ControlMessageCodec.errorMessage(
        id: 't-9',
        code: ProtocolErrorCode.transferRejected,
        message: 'declined',
      );

      final decoded = ControlMessageCodec.decode(jsonEncode(message.toJson()));

      expect(decoded, isA<ControlDecoded>());
      final error = (decoded as ControlDecoded).error!;
      expect(error.code, ProtocolErrorCode.transferRejected);
      expect(error.failure, TransferFailure.remoteRejected);
    });
  });

  group('tryParse', () {
    test('returns null for an unknown value instead of throwing', () {
      expect(ProtocolErrorCode.tryParse('nope'), isNull);
      expect(ProtocolErrorCode.tryParse(''), isNull);
    });

    test('is exact, so a near miss is not silently accepted', () {
      expect(ProtocolErrorCode.tryParse('not_paired '), isNull);
      expect(ProtocolErrorCode.tryParse('NotPaired'), isNull);
    });
  });
}
