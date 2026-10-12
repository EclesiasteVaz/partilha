/// Typed DTO payloads for protocol messages approved in PROTOCOL_IMPLEMENTATION_PLAN.md.
library;

/// S->R: Handshake payload containing sender's identity and pairing token.
final class PairRequestPayload {
  const PairRequestPayload({
    required this.deviceId,
    required this.deviceName,
    required this.token,
  });

  factory PairRequestPayload.fromJson(Map<String, dynamic> json) {
    final deviceId = json['deviceId'];
    final deviceName = json['deviceName'];
    final token = json['token'];
    if (deviceId is! String || deviceId.isEmpty) {
      throw const FormatException('Missing or invalid "deviceId"');
    }
    if (deviceName is! String || deviceName.isEmpty) {
      throw const FormatException('Missing or invalid "deviceName"');
    }
    if (token is! String || token.isEmpty) {
      throw const FormatException('Missing or invalid "token"');
    }
    return PairRequestPayload(
      deviceId: deviceId,
      deviceName: deviceName,
      token: token,
    );
  }

  final String deviceId;
  final String deviceName;
  final String token;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'deviceId': deviceId,
    'deviceName': deviceName,
    'token': token,
  };
}

/// R->S: Response indicating whether pairing request was accepted.
final class PairResponsePayload {
  const PairResponsePayload({required this.accepted, this.reason});

  factory PairResponsePayload.fromJson(Map<String, dynamic> json) {
    final accepted = json['accepted'];
    if (accepted is! bool) {
      throw const FormatException('Missing or invalid "accepted"');
    }
    final reason = json['reason'];
    return PairResponsePayload(
      accepted: accepted,
      reason: reason is String ? reason : null,
    );
  }

  final bool accepted;
  final String? reason;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'accepted': accepted,
    if (reason != null) 'reason': reason,
  };
}

/// S->R: Offer describing a file proposed for transfer.
final class TransferOfferPayload {
  const TransferOfferPayload({
    required this.wireTransferId,
    required this.fileName,
    required this.size,
    this.mimeType,
  });

  factory TransferOfferPayload.fromJson(Map<String, dynamic> json) {
    final wireTransferId = json['wireTransferId'];
    final fileName = json['fileName'];
    final size = json['size'];
    final mimeType = json['mimeType'];

    if (wireTransferId is! String || wireTransferId.isEmpty) {
      throw const FormatException('Missing or invalid "wireTransferId"');
    }
    if (fileName is! String || fileName.isEmpty) {
      throw const FormatException('Missing or invalid "fileName"');
    }
    if (size is! int || size < 0) {
      throw const FormatException('Missing or invalid "size"');
    }

    return TransferOfferPayload(
      wireTransferId: wireTransferId,
      fileName: fileName,
      size: size,
      mimeType: mimeType is String ? mimeType : null,
    );
  }

  final String wireTransferId;
  final String fileName;
  final int size;
  final String? mimeType;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'wireTransferId': wireTransferId,
    'fileName': fileName,
    'size': size,
    if (mimeType != null) 'mimeType': mimeType,
  };
}

/// R->S: Receiver accepts the transfer offer and is ready for binary frames.
final class TransferAcceptPayload {
  const TransferAcceptPayload({required this.wireTransferId});

  factory TransferAcceptPayload.fromJson(Map<String, dynamic> json) {
    final wireTransferId = json['wireTransferId'];
    if (wireTransferId is! String || wireTransferId.isEmpty) {
      throw const FormatException('Missing or invalid "wireTransferId"');
    }
    return TransferAcceptPayload(wireTransferId: wireTransferId);
  }

  final String wireTransferId;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'wireTransferId': wireTransferId,
  };
}

/// R->S: Receiver rejects the proposed transfer offer.
final class TransferRejectPayload {
  const TransferRejectPayload({required this.wireTransferId, this.reason});

  factory TransferRejectPayload.fromJson(Map<String, dynamic> json) {
    final wireTransferId = json['wireTransferId'];
    if (wireTransferId is! String || wireTransferId.isEmpty) {
      throw const FormatException('Missing or invalid "wireTransferId"');
    }
    final reason = json['reason'];
    return TransferRejectPayload(
      wireTransferId: wireTransferId,
      reason: reason is String ? reason : null,
    );
  }

  final String wireTransferId;
  final String? reason;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'wireTransferId': wireTransferId,
    if (reason != null) 'reason': reason,
  };
}

/// S<->R: Cancels an active or offered transfer.
final class TransferCancelPayload {
  const TransferCancelPayload({required this.wireTransferId});

  factory TransferCancelPayload.fromJson(Map<String, dynamic> json) {
    final wireTransferId = json['wireTransferId'];
    if (wireTransferId is! String || wireTransferId.isEmpty) {
      throw const FormatException('Missing or invalid "wireTransferId"');
    }
    return TransferCancelPayload(wireTransferId: wireTransferId);
  }

  final String wireTransferId;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'wireTransferId': wireTransferId,
  };
}

/// R->S: Receiver confirms that all bytes were written and verified.
final class TransferCompletePayload {
  const TransferCompletePayload({required this.wireTransferId});

  factory TransferCompletePayload.fromJson(Map<String, dynamic> json) {
    final wireTransferId = json['wireTransferId'];
    if (wireTransferId is! String || wireTransferId.isEmpty) {
      throw const FormatException('Missing or invalid "wireTransferId"');
    }
    return TransferCompletePayload(wireTransferId: wireTransferId);
  }

  final String wireTransferId;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'wireTransferId': wireTransferId,
  };
}

/// S<->R: Notifies about an error condition on the wire.
final class TransferErrorPayload {
  const TransferErrorPayload({required this.code, this.message});

  factory TransferErrorPayload.fromJson(Map<String, dynamic> json) {
    final code = json['code'];
    if (code is! String || code.isEmpty) {
      throw const FormatException('Missing or invalid "code"');
    }
    final message = json['message'];
    return TransferErrorPayload(
      code: code,
      message: message is String ? message : null,
    );
  }

  final String code;
  final String? message;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'code': code,
    if (message != null) 'message': message,
  };
}

/// R->S (opt): Optional progress update from receiver.
final class TransferProgressPayload {
  const TransferProgressPayload({
    required this.wireTransferId,
    required this.bytesReceived,
  });

  factory TransferProgressPayload.fromJson(Map<String, dynamic> json) {
    final wireTransferId = json['wireTransferId'];
    final bytesReceived = json['bytesReceived'];
    if (wireTransferId is! String || wireTransferId.isEmpty) {
      throw const FormatException('Missing or invalid "wireTransferId"');
    }
    if (bytesReceived is! int || bytesReceived < 0) {
      throw const FormatException('Missing or invalid "bytesReceived"');
    }
    return TransferProgressPayload(
      wireTransferId: wireTransferId,
      bytesReceived: bytesReceived,
    );
  }

  final String wireTransferId;
  final int bytesReceived;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'wireTransferId': wireTransferId,
    'bytesReceived': bytesReceived,
  };
}
