/// A stable identifier for a transfer.
///
/// The exact format is deliberately not frozen here; this is the contract type
/// the application depends on, not the encoding.
abstract class TransferId {
  const TransferId();

  String get value;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is TransferId && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}

/// Simple string-based transfer identifier for the MVP.
class StringTransferId extends TransferId {
  const StringTransferId(this.value);

  @override
  final String value;
}
