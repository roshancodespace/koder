enum CompanionConnectionStatus {
  disconnected,
  connecting,
  connected,
  reconnecting,
  error,
}

enum NetworkConnectionMode {
  loopbackUsb,
  lanWifi,
}

class CompanionConnectionConfig {
  final String host;
  final int port;
  final NetworkConnectionMode mode;
  final String? pairingToken;

  const CompanionConnectionConfig({
    this.host = '127.0.0.1',
    this.port = 38848,
    this.mode = NetworkConnectionMode.loopbackUsb,
    this.pairingToken,
  });

  CompanionConnectionConfig copyWith({
    String? host,
    int? port,
    NetworkConnectionMode? mode,
    String? pairingToken,
  }) {
    return CompanionConnectionConfig(
      host: host ?? this.host,
      port: port ?? this.port,
      mode: mode ?? this.mode,
      pairingToken: pairingToken ?? this.pairingToken,
    );
  }

  Uri get targetUri {
    final query = (pairingToken != null && pairingToken!.isNotEmpty)
        ? {'token': pairingToken!}
        : null;
    return Uri(
      scheme: 'ws',
      host: host,
      port: port,
      queryParameters: query,
    );
  }

  @override
  String toString() =>
      'CompanionConnectionConfig(host: $host, port: $port, mode: $mode, hasToken: ${pairingToken != null})';
}

class CompanionNetworkState {
  final CompanionConnectionStatus status;
  final CompanionConnectionConfig config;
  final Map<String, dynamic>? activeEditorState;
  final String? lastError;
  final DateTime? lastHeartbeat;

  const CompanionNetworkState({
    this.status = CompanionConnectionStatus.disconnected,
    this.config = const CompanionConnectionConfig(),
    this.activeEditorState,
    this.lastError,
    this.lastHeartbeat,
  });

  bool get isConnected => status == CompanionConnectionStatus.connected;
  bool get isConnecting =>
      status == CompanionConnectionStatus.connecting ||
      status == CompanionConnectionStatus.reconnecting;

  CompanionNetworkState copyWith({
    CompanionConnectionStatus? status,
    CompanionConnectionConfig? config,
    Map<String, dynamic>? activeEditorState,
    String? lastError,
    DateTime? lastHeartbeat,
  }) {
    return CompanionNetworkState(
      status: status ?? this.status,
      config: config ?? this.config,
      activeEditorState: activeEditorState ?? this.activeEditorState,
      lastError: lastError ?? this.lastError,
      lastHeartbeat: lastHeartbeat ?? this.lastHeartbeat,
    );
  }

  @override
  String toString() =>
      'CompanionNetworkState(status: $status, editorState: ${activeEditorState != null}, lastError: $lastError)';
}
