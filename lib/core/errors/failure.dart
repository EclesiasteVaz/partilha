/// Typed representation of everything that can go wrong inside the app.
///
/// Infrastructure exceptions (`SocketException`, `DatabaseException`,
/// `PlatformException`, ...) are converted into a `Failure` at the data-layer
/// boundary so they never reach domain or presentation contracts
/// (`AGENTS.md` §15).
///
/// The hierarchy is `sealed` on purpose: every failure mode the application
/// can produce is enumerable, which lets presentation code switch exhaustively
/// and refuse to compile when a new failure type is introduced
/// (`AGENTS.md` §83).
sealed class Failure {
  const Failure({this.cause, this.context = const <String, Object?>{}});

  /// The original infrastructure exception, when one exists.
  ///
  /// Kept for diagnostics only. Never render this to users: it can contain
  /// paths, tokens or addresses that must not reach the UI (`AGENTS.md` §52,
  /// §83). Log it through the project logger instead.
  final Object? cause;

  /// Diagnostic key/value pairs for logging (`AGENTS.md` §52).
  ///
  /// Never include secrets here. The logger redacts known-sensitive keys, but
  /// a key that is not on that list is written verbatim.
  final Map<String, Object?> context;

  /// Whether re-running the exact same operation could plausibly succeed.
  ///
  /// Retry logic must consult this instead of retrying blindly
  /// (`AGENTS.md` §82). Retrying a failure that cannot succeed wastes the
  /// user's battery and hides the real problem; not retrying a transient one
  /// turns a blip into a dead end.
  ///
  /// The value lives in [FailureRetryability] rather than on each subclass so
  /// the whole retry table can be asserted by one test instead of trusting
  /// every subclass to agree with its own name.

  /// A short, user-safe description.
  ///
  /// This is the only text presentation is allowed to show. It must never
  /// embed an exception message, a filesystem path or a device address
  /// (`AGENTS.md` §83, §84).
  String get userMessage;

  @override
  String toString() =>
      '$kind(userMessage: $userMessage, retryable: $isRetryable, '
      'cause: ${cause?.runtimeType})';
}

/// A stable, public identifier for the failure category.
///
/// Derived from the sealed hierarchy rather than from `runtimeType`, because
/// the concrete implementations are library-private: logging `runtimeType`
/// would put `_TransferConnectionLostFailure` in the log instead of
/// `TransferFailure`, leaking an internal name and making the output
/// unreadable and unstable (`AGENTS.md` §52, §56).
extension FailureKind on Failure {
  String get kind => switch (this) {
    NetworkFailure() => 'NetworkFailure',
    StorageFailure() => 'StorageFailure',
    PermissionFailure() => 'PermissionFailure',
    DiscoveryFailure() => 'DiscoveryFailure',
    PairingFailure() => 'PairingFailure',
    TransferFailure() => 'TransferFailure',
    ValidationFailure() => 'ValidationFailure',
    UnknownFailure() => 'UnknownFailure',
  };
}

/// The network could not be reached, or the connection failed mid-operation.
/// Final so the data layer can construct it with a cause, while the set of
/// failure categories stays closed and exhaustively switchable.
final class NetworkFailure extends Failure {
  const NetworkFailure({
    super.cause,
    super.context,
    this.userMessage = 'Could not reach the other device.',
  });

  @override
  final String userMessage;

  /// A connection that could not be established at all. Usually transient:
  /// the peer may be asleep, the network may be switching, or the user may
  /// have walked out of range and back.
  static const unreachable = _NetworkUnreachableFailure();

  /// The connection dropped while the operation was in flight. Transient by
  /// nature, which is what makes the transfer retry budget meaningful.
  static const connectionLost = _NetworkConnectionLostFailure();

  /// The operation exceeded its deadline. Retryable because the peer may
  /// simply have been slow rather than broken.
  static const timedOut = _NetworkTimedOutFailure();
}

final class _NetworkUnreachableFailure extends NetworkFailure {
  const _NetworkUnreachableFailure()
    : super(userMessage: 'Could not reach the other device.');
}

final class _NetworkConnectionLostFailure extends NetworkFailure {
  const _NetworkConnectionLostFailure()
    : super(userMessage: 'The connection was lost.');
}

final class _NetworkTimedOutFailure extends NetworkFailure {
  const _NetworkTimedOutFailure()
    : super(userMessage: 'The other device did not respond in time.');
}

/// Anything that involves the filesystem or SQLite.
/// Final so the data layer can construct it with a cause, while the set of
/// failure categories stays closed and exhaustively switchable.
final class StorageFailure extends Failure {
  const StorageFailure({
    super.cause,
    super.context,
    this.userMessage = 'Could not access local storage.',
  });

  @override
  final String userMessage;

  /// Not enough free space at the destination.
  ///
  /// Explicitly **not** retryable. Retrying without the user freeing space
  /// would fail identically, and `AGENTS.md` §24 requires the transfer not to
  /// start at all when the destination cannot hold the file.
  static const insufficientSpace = _StorageInsufficientSpaceFailure();

  /// The filesystem rejected a write. Not retryable without a change on the
  /// user's side: a read-only volume, a revoked grant, a full disk.
  static const writeFailed = _StorageWriteFailedFailure();

  /// The database is unavailable or refused a statement. Treated as
  /// non-retryable because retrying corrupts an already failing write path.
  static const databaseUnavailable = _StorageDatabaseFailure();
}

final class _StorageInsufficientSpaceFailure extends StorageFailure {
  const _StorageInsufficientSpaceFailure()
    : super(userMessage: 'Not enough space to save the files.');
}

final class _StorageWriteFailedFailure extends StorageFailure {
  const _StorageWriteFailedFailure()
    : super(userMessage: 'Could not write to the destination.');
}

final class _StorageDatabaseFailure extends StorageFailure {
  const _StorageDatabaseFailure()
    : super(userMessage: 'Local storage is unavailable.');
}

/// An operating-system permission was not granted.
/// Final so the data layer can construct it with a cause, while the set of
/// failure categories stays closed and exhaustively switchable.
final class PermissionFailure extends Failure {
  const PermissionFailure({
    super.cause,
    super.context,
    this.userMessage = 'Permission is required to continue.',
  });

  @override
  final String userMessage;

  /// The user declined this time. Not retryable automatically: re-prompting
  /// without the user acting is hostile (`AGENTS.md` §40).
  static const denied = _PermissionDeniedFailure();

  /// The user declined permanently, or policy forbids it. Retrying is
  /// pointless; the user must change a system setting.
  static const permanentlyDenied = _PermissionPermanentlyDeniedFailure();
}

final class _PermissionDeniedFailure extends PermissionFailure {
  const _PermissionDeniedFailure()
    : super(userMessage: 'Permission is required to continue.');
}

final class _PermissionPermanentlyDeniedFailure extends PermissionFailure {
  const _PermissionPermanentlyDeniedFailure()
    : super(userMessage: 'Permission is blocked in system settings.');
}

/// Discovery could not run.
/// Final so the data layer can construct it with a cause, while the set of
/// failure categories stays closed and exhaustively switchable.
final class DiscoveryFailure extends Failure {
  const DiscoveryFailure({
    super.cause,
    super.context,
    this.userMessage = 'Discovery failed on the local network.',
  });

  @override
  final String userMessage;

  /// The platform refuses to send or receive multicast traffic. Not
  /// retryable: no code change or wait fixes a disabled network interface.
  static const multicastUnavailable = _DiscoveryMulticastFailure();

  /// The transport backing discovery failed. Retryable while the network is
  /// moving, matching the retry semantics of `NetworkFailure.unreachable`.
  static const transportFailed = _DiscoveryTransportFailure();
}

final class _DiscoveryMulticastFailure extends DiscoveryFailure {
  const _DiscoveryMulticastFailure()
    : super(userMessage: 'Local network discovery is unavailable.');
}

final class _DiscoveryTransportFailure extends DiscoveryFailure {
  const _DiscoveryTransportFailure()
    : super(userMessage: 'Discovery failed on the local network.');
}

/// Pairing could not be completed.
/// Final so the data layer can construct it with a cause, while the set of
/// failure categories stays closed and exhaustively switchable.
final class PairingFailure extends Failure {
  const PairingFailure({
    super.cause,
    super.context,
    this.userMessage = 'Pairing did not complete.',
  });

  @override
  final String userMessage;

  /// The QR payload did not match the agreed contract. Not retryable: the
  /// same code would produce the same rejection. The user needs a new code.
  static const invalidPayload = _PairingInvalidPayloadFailure();

  /// The pairing window elapsed before the scan completed. Retryable.
  static const timedOut = _PairingTimedOutFailure();

  /// The presented token was not accepted. Not retryable, and must not be
  /// attempted again without a new QR code.
  static const rejected = _PairingRejectedFailure();
}

final class _PairingInvalidPayloadFailure extends PairingFailure {
  const _PairingInvalidPayloadFailure()
    : super(userMessage: 'That code is not valid for Partilha.');
}

final class _PairingTimedOutFailure extends PairingFailure {
  const _PairingTimedOutFailure()
    : super(userMessage: 'The code expired before it was scanned.');
}

final class _PairingRejectedFailure extends PairingFailure {
  const _PairingRejectedFailure()
    : super(userMessage: 'The other device rejected this pairing.');
}

/// A transfer could not complete.
/// Final so the data layer can construct it with a cause, while the set of
/// failure categories stays closed and exhaustively switchable.
final class TransferFailure extends Failure {
  const TransferFailure({
    super.cause,
    super.context,
    this.userMessage = 'The transfer could not be completed.',
  });

  @override
  final String userMessage;

  /// The user cancelled. Not a failure to retry: retrying would contradict
  /// the explicit intent that stopped it (`AGENTS.md` §28).
  static const cancelled = _TransferCancelledFailure();

  /// The sender refused the request. Retrying the identical offer would be
  /// refused again.
  static const remoteRejected = _TransferRemoteRejectedFailure();

  /// The connection dropped during streaming. Retryable, and the main reason
  /// the bounded retry budget exists (`AGENTS.md` §27).
  static const connectionLost = _TransferConnectionLostFailure();

  /// The peer sent something that violates the wire contract. Not
  /// retryable: retrying malformed traffic reproduces the violation.
  static const protocolViolation = _TransferProtocolViolationFailure();
}

final class _TransferCancelledFailure extends TransferFailure {
  const _TransferCancelledFailure() : super(userMessage: 'Transfer cancelled.');
}

final class _TransferRemoteRejectedFailure extends TransferFailure {
  const _TransferRemoteRejectedFailure()
    : super(userMessage: 'The other device refused the transfer.');
}

final class _TransferConnectionLostFailure extends TransferFailure {
  const _TransferConnectionLostFailure()
    : super(userMessage: 'The transfer was interrupted.');
}

final class _TransferProtocolViolationFailure extends TransferFailure {
  const _TransferProtocolViolationFailure()
    : super(userMessage: 'The transfer could not be understood.');
}

/// Input failed validation before reaching a subsystem.
/// Final so the data layer can construct it with a cause, while the set of
/// failure categories stays closed and exhaustively switchable.
final class ValidationFailure extends Failure {
  const ValidationFailure({
    super.cause,
    super.context,
    this.userMessage = 'That value is not valid.',
  });

  @override
  final String userMessage;

  /// A required field was left empty. Never retryable.
  ///
  /// Generic rather than a per-feature constant because "required but empty" is a
  /// shape every form in the app shares, and a per-feature subclass cannot be
  /// added here: this class is final by design, so the message belongs in the
  /// shared vocabulary instead.
  static const empty = _ValidationEmptyFailure();

  /// A field is longer than the contract allows. Never retryable.
  static const tooLong = _ValidationTooLongFailure();

  /// A field does not match its expected format. Never retryable.
  static const malformed = _ValidationMalformedFailure();

  /// A path escapes its permitted root, or contains traversal segments.
  ///
  /// Never retryable, and always worth surfacing rather than silently
  /// sanitising: silently rewriting a requested path hides an attempted
  /// traversal.
  static const unsafePath = _ValidationUnsafePathFailure();
}

final class _ValidationEmptyFailure extends ValidationFailure {
  const _ValidationEmptyFailure() : super(userMessage: 'This is required.');
}

final class _ValidationTooLongFailure extends ValidationFailure {
  const _ValidationTooLongFailure()
    : super(userMessage: 'A value is longer than allowed.');
}

final class _ValidationMalformedFailure extends ValidationFailure {
  const _ValidationMalformedFailure()
    : super(userMessage: 'A value has an invalid format.');
}

final class _ValidationUnsafePathFailure extends ValidationFailure {
  const _ValidationUnsafePathFailure()
    : super(userMessage: 'That location is not allowed.');
}

/// A failure that did not fit any other category.
///
/// Deliberately non-retryable, see [FailureRetryability]. When something
/// escapes the known categories, the honest response is to surface it rather
/// than guess that trying again is safe (`AGENTS.md` §82).
final class UnknownFailure extends Failure {
  const UnknownFailure({
    this.userMessage = 'Something went wrong.',
    super.cause,
    super.context,
  });

  @override
  final String userMessage;
}

/// Whether re-running the exact same operation could plausibly succeed.
///
/// Retry logic must consult this instead of retrying blindly
/// (`AGENTS.md` §82). Retrying a failure that cannot succeed wastes the user's
/// battery and hides the real problem; not retrying a transient one turns a
/// blip into a dead end.
///
/// The whole table lives in one switch so it can be asserted by a single test
/// rather than trusting every subclass to agree with its own name. The switch
/// is exhaustive over the sealed hierarchy, so adding a failure category is a
/// compile error until its retry semantics are classified.
extension FailureRetryability on Failure {
  bool get isRetryable => switch (this) {
    // Transient by nature: the peer may be asleep, the network may be moving.
    NetworkFailure() => true,

    // Insufficient space, a read-only volume and a failing write path all
    // fail identically on retry until the user changes something
    // (`AGENTS.md` §24, §82).
    StorageFailure() => false,

    // Re-prompting a user who already declined is hostile (`AGENTS.md` §40).
    PermissionFailure() => false,

    // A disabled multicast interface never fixes itself.
    DiscoveryFailure.multicastUnavailable => false,
    DiscoveryFailure() => true,

    // Only an expired window is transient. A rejected or malformed payload
    // would be refused again identically.
    PairingFailure.timedOut => true,
    PairingFailure() => false,

    // An interrupted transfer is exactly what the retry budget exists for
    // (`AGENTS.md` §27). A user cancellation must not be overridden.
    TransferFailure.connectionLost => true,
    TransferFailure() => false,

    // Invalid input is invalid on the next attempt too.
    ValidationFailure() => false,

    // Unknown: refuse to guess.
    UnknownFailure() => false,
  };
}
