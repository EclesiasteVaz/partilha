class FileTransferProgress {
  const FileTransferProgress({
    required this.transferId,
    required this.bytesTransferred,
    required this.totalBytes,
    this.fileName,
  });

  final String transferId;
  final int bytesTransferred;
  final int totalBytes;
  final String? fileName;

  double get fraction => totalBytes <= 0 ? 0 : bytesTransferred / totalBytes;
}
