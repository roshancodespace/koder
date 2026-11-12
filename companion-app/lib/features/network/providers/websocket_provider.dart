import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/connection_state.dart';
import '../models/protocol_envelope.dart';
import '../services/websocket_client_service.dart';

final websocketClientServiceProvider = Provider<WebSocketClientService>((ref) {
  final service = WebSocketClientService();
  ref.onDispose(() {
    service.dispose();
  });
  return service;
});

final companionNetworkStateProvider =
    StateNotifierProvider<CompanionNetworkNotifier, CompanionNetworkState>(
        (ref) {
  final service = ref.watch(websocketClientServiceProvider);
  return CompanionNetworkNotifier(service);
});

class CompanionNetworkNotifier extends StateNotifier<CompanionNetworkState> {
  final WebSocketClientService _service;
  StreamSubscription<CompanionConnectionStatus>? _statusSubscription;
  StreamSubscription<Map<String, dynamic>>? _editorStateSubscription;

  CompanionNetworkNotifier(this._service)
      : super(const CompanionNetworkState()) {
    _statusSubscription = _service.onStatusChanged.listen((status) {
      state = state.copyWith(
        status: status,
        lastHeartbeat: _service.lastHeartbeat,
      );
    });

    _editorStateSubscription =
        _service.onEditorStateChanged.listen((editorState) {
      state = state.copyWith(activeEditorState: editorState);
    });
  }

  Future<void> connectLoopback({int port = 38848}) async {
    final config = CompanionConnectionConfig(
      host: '127.0.0.1',
      port: port,
      mode: NetworkConnectionMode.loopbackUsb,
    );
    state = state.copyWith(
      config: config,
      status: CompanionConnectionStatus.connecting,
      lastError: null,
    );
    await _service.connect(config);
    state = state.copyWith(
      status: _service.status,
      lastHeartbeat: _service.lastHeartbeat,
    );
  }

  Future<void> connectLan(String host, int port, {String? token}) async {
    final config = CompanionConnectionConfig(
      host: host,
      port: port,
      mode: NetworkConnectionMode.lanWifi,
      pairingToken: token,
    );
    state = state.copyWith(
      config: config,
      status: CompanionConnectionStatus.connecting,
      lastError: null,
    );
    await _service.connect(config);
    state = state.copyWith(
      status: _service.status,
      lastHeartbeat: _service.lastHeartbeat,
    );
  }

  void disconnect() {
    _service.disconnect();
    state = state.copyWith(status: CompanionConnectionStatus.disconnected);
  }

  bool sendEnvelope(ProtocolEnvelope envelope) {
    return _service.send(envelope);
  }

  Future<ProtocolEnvelope> sendRequest(
    String name,
    Map<String, dynamic> payload, {
    Duration timeout = const Duration(seconds: 10),
  }) {
    return _service.sendRequest(name, payload, timeout: timeout);
  }

  @override
  void dispose() {
    _statusSubscription?.cancel();
    _editorStateSubscription?.cancel();
    super.dispose();
  }
}
