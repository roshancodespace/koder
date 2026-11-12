import 'dart:convert';

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

  static CompanionConnectionConfig? parseUriOrJson(String input) {
    final text = input.trim();
    if (text.isEmpty) return null;

    if (text.startsWith('{') && text.endsWith('}')) {
      try {
        final Map<String, dynamic> data =
            jsonDecode(text) as Map<String, dynamic>;
        final host = data['host'] as String? ?? '127.0.0.1';
        final port = data['port'] is int
            ? data['port'] as int
            : int.tryParse(data['port']?.toString() ?? '') ?? 38848;
        final token = data['token'] as String?;
        return CompanionConnectionConfig(
          host: host,
          port: port,
          mode: host == '127.0.0.1'
              ? NetworkConnectionMode.loopbackUsb
              : NetworkConnectionMode.lanWifi,
          pairingToken: token,
        );
      } catch (_) {}
    }

    try {
      String uriString = text;
      if (!uriString.startsWith('ws://') &&
          !uriString.startsWith('http://') &&
          !uriString.startsWith('wss://')) {
        uriString = 'ws://$uriString';
      }
      final uri = Uri.parse(uriString);
      final host = uri.host.isNotEmpty ? uri.host : '127.0.0.1';
      final port = uri.port > 0 ? uri.port : 38848;
      final token = uri.queryParameters['token'];
      return CompanionConnectionConfig(
        host: host,
        port: port,
        mode: host == '127.0.0.1'
            ? NetworkConnectionMode.loopbackUsb
            : NetworkConnectionMode.lanWifi,
        pairingToken: token,
      );
    } catch (_) {
      return null;
    }
  }

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
