import 'package:freezed_annotation/freezed_annotation.dart';

part 'wire_transfer_id.freezed.dart';
part 'wire_transfer_id.g.dart';

@freezed
sealed class WireTransferId with _$WireTransferId {
  const factory WireTransferId(String value) = _WireTransferId;

  factory WireTransferId.fromJson(String value) => WireTransferId(value);

  static WireTransferId generate() => WireTransferId(
    '${DateTime.now().microsecondsSinceEpoch}_${DateTime.now().millisecond % 10000}',
  );
}
