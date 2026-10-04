import 'package:partilha/core/errors/failure.dart';
import 'package:partilha/core/result/result.dart';

/// The name this device presents to nearby Partilha devices.
///
/// A value object rather than a `String` because the rules that make a name
/// presentable are not the rules that make it a valid string: the same text can
/// be a legal identifier and an unusable device name, and the difference is
/// exactly what a peer displays. Wrapping it keeps every consumer from
/// re-deciding the question.
///
/// Immutable, so it can be held in immutable state and compared by value
/// without a copy on every rebuild (`AGENTS.md` §46).
class DeviceName {
  const DeviceName._(this.value);

  /// The longest name accepted.
  ///
  /// This name travels in an mDNS TXT record (§7.2), which has a 255-byte budget
  /// shared with the record keys, and it is shown in a list row on the peer. A
  /// longer name would either be truncated by the protocol or overflow the UI, so
  /// it is rejected while the user is still typing rather than at discovery time.
  ///
  /// The discovery side enforces the same limit when reading an untrusted
  /// announcement; the two limits must stay equal or a name this screen accepts
  /// could be refused by a peer.
  static const int maxLength = 64;

  /// Builds a name, or the failure explaining why it cannot be one.
  ///
  /// Returns a [Result] instead of throwing because an empty or overlong name is
  /// an ordinary thing a user does, not a programming error. The caller shows
  /// the message; it does not crash (`AGENTS.md` §83).
  static Result<DeviceName, Failure> create(String input) {
    final String value = input.trim();

    if (value.isEmpty) {
      return const Result<DeviceName, Failure>.failure(ValidationFailure.empty);
    }

    if (value.length > maxLength) {
      return const Result<DeviceName, Failure>.failure(
        ValidationFailure.tooLong,
      );
    }

    // Control characters would survive the trim and render as invisible padding
    // or a broken line in the peer's list, so they are rejected outright instead
    // of being stripped: silently rewriting what the user typed hides the
    // problem from them.
    for (final int code in value.runes) {
      if (_isDisallowed(code)) {
        return const Result<DeviceName, Failure>.failure(
          ValidationFailure.malformed,
        );
      }
    }

    return Result<DeviceName, Failure>.success(DeviceName._(value));
  }

  /// The fallback used before the user has chosen a name.
  ///
  /// A constant rather than the hostname, a model or an account: §34 requires a
  /// user-defined name, and inferring one from the machine would leak it to every
  /// device on the network, which is the leak that rule exists to prevent.
  static const DeviceName fallback = DeviceName._('Partilha');

  /// The name as it will be transmitted.
  final String value;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is DeviceName && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}

/// Whether [code] must not appear in a device name.
///
/// Every C0 control character and DEL, which covers newline and carriage return:
/// those two are the classic log-injection and record-splitting vector, and a TXT
/// record is a place where an unescaped newline can terminate the value early.
/// Allowing them would mean the stored name and the advertised name disagree.
bool _isDisallowed(int code) => code < 0x20 || code == 0x7f;
