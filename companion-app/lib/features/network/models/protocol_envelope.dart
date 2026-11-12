class ProtocolError {
  final String code;
  final String message;
  final dynamic details;

  const ProtocolError({
    required this.code,
    required this.message,
    this.details,
  });

  factory ProtocolError.fromJson(Map<String, dynamic> json) {
    return ProtocolError(
      code: json['code'] as String? ?? 'UNKNOWN_ERROR',
      message: json['message'] as String? ?? '',
      details: json['details'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'code': code,
      'message': message,
      if (details != null) 'details': details,
    };
  }

  @override
  String toString() => 'ProtocolError(code: $code, message: $message)';
}

class ProtocolEnvelope {
  final String version;
  final String id;
  final String type; // 'event' | 'request' | 'response'
  final String name;
  final Map<String, dynamic> payload;
  final int timestamp;
  final ProtocolError? error;

  const ProtocolEnvelope({
    this.version = '1.0',
    required this.id,
    required this.type,
    required this.name,
    this.payload = const {},
    required this.timestamp,
    this.error,
  });

  factory ProtocolEnvelope.fromJson(Map<String, dynamic> json) {
    return ProtocolEnvelope(
      version: json['version'] as String? ?? '1.0',
      id: json['id'] as String? ?? '',
      type: json['type'] as String? ?? 'event',
      name: json['name'] as String? ?? '',
      payload: (json['payload'] as Map<String, dynamic>?) ?? {},
      timestamp:
          json['timestamp'] as int? ?? DateTime.now().millisecondsSinceEpoch,
      error: json['error'] != null
          ? ProtocolError.fromJson(json['error'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'version': version,
      'id': id,
      'type': type,
      'name': name,
      'payload': payload,
      'timestamp': timestamp,
      if (error != null) 'error': error!.toJson(),
    };
  }

  static int _idCounter = 0;

  static String generateId([String prefix = 'msg']) {
    _idCounter = (_idCounter + 1) % 1000000;
    return '$prefix-${DateTime.now().millisecondsSinceEpoch}-${_idCounter.toString().padLeft(4, '0')}';
  }

  factory ProtocolEnvelope.createEvent(
      String name, Map<String, dynamic> payload) {
    return ProtocolEnvelope(
      id: generateId('evt'),
      type: 'event',
      name: name,
      payload: payload,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );
  }

  factory ProtocolEnvelope.createRequest(
    String name,
    Map<String, dynamic> payload, {
    String? id,
  }) {
    return ProtocolEnvelope(
      id: id ?? generateId('req'),
      type: 'request',
      name: name,
      payload: payload,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );
  }

  factory ProtocolEnvelope.createResponse(
    String requestId,
    String name,
    Map<String, dynamic> payload,
  ) {
    return ProtocolEnvelope(
      id: requestId,
      type: 'response',
      name: name,
      payload: payload,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );
  }

  factory ProtocolEnvelope.createError(
    String requestId,
    String name,
    String code,
    String message, {
    dynamic details,
  }) {
    return ProtocolEnvelope(
      id: requestId,
      type: 'response',
      name: name,
      payload: const {},
      timestamp: DateTime.now().millisecondsSinceEpoch,
      error: ProtocolError(code: code, message: message, details: details),
    );
  }

  factory ProtocolEnvelope.createPing() {
    return ProtocolEnvelope(
      id: generateId('ping'),
      type: 'request',
      name: 'system.ping',
      payload: const {},
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );
  }

  factory ProtocolEnvelope.createPong(String pingId) {
    return ProtocolEnvelope(
      id: pingId,
      type: 'response',
      name: 'system.pong',
      payload: {'timestamp': DateTime.now().millisecondsSinceEpoch},
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );
  }

  @override
  String toString() =>
      'ProtocolEnvelope(id: $id, type: $type, name: $name, error: $error)';
}
