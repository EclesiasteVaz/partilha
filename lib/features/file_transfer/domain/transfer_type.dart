enum TransferType { file }

class TransferRequest {
  const TransferRequest({
    required this.id,
    required this.name,
    required this.sizeInBytes,
    this.type = TransferType.file,
  });

  final String id;
  final String name;
  final int? sizeInBytes;
  final TransferType type;
}
