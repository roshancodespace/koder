import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/connection_state.dart';
import '../models/protocol_envelope.dart';

typedef WebSocketChannelFactory = WebSocketChannel Function(Uri uri);

class WebSocketClientService {
  final WebSocketChannelFactory _channelFactory;

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  Timer? _reconnectTimer;
  Timer? _heartbeatTimer;
  Timer? _pongTimeoutTimer;

  CompanionConnectionConfig? _currentConfig;
  CompanionConnectionStatus _status = CompanionConnectionStatus.disconnected;
  bool _explicitlyDisconnected = false;
  int _reconnectAttempts = 0;
  DateTime? _lastHeartbeat;

  final _statusController = StreamController<CompanionConnectionStatus>.broadcast();
  final _messageController = StreamController<ProtocolEnvelope>.broadcast();
  final _editorStateController = StreamController<Map<String, dynamic>>.broadcast();

  // Pending requests awaiting response by correlation ID
  final _pendingRequests = <String, Completer<ProtocolEnvelope>>{};

  WebSocketClientService({
    WebSocketChannelFactory? channelFactory,
  }) : _channelFactory = channelFactory ?? ((uri) => WebSocketChannel.connect(uri));

  CompanionConnectionStatus get status => _status;
  CompanionConnectionConfig? get currentConfig => _currentConfig;
  DateTime? get lastHeartbeat => _lastHeartbeat;
  bool get isConnected => _status == CompanionConnectionStatus.connected;

  Stream<CompanionConnectionStatus> get onStatusChanged => _statusController.stream;
  Stream<ProtocolEnvelope> get onMessageReceived => _messageController.stream;
  Stream<Map<String, dynamic>> get onEditorStateChanged => _editorStateController.stream;

  void _updateStatus(CompanionConnectionStatus newStatus) {
    if (_status != newStatus) {
      _status = newStatus;
      _statusController.add(newStatus);
    }
  }

  /// Connects to the host configured in [config].
  Future<void> connect(CompanionConnectionConfig config) async {
    _explicitlyDisconnected = false;
    _currentConfig = config;
    _cancelReconnectTimer();
    _updateStatus(CompanionConnectionStatus.connecting);

    try {
      final uri = config.targetUri;
      _channel = _channelFactory(uri);

      // Listen to incoming messages
      _subscription = _channel!.stream.listen(
        _handleRawMessage,
        onDone: _handleConnectionDone,
        onError: _handleConnectionError,
        cancelOnError: true,
      );

      _reconnectAttempts = 0;
      _lastHeartbeat = DateTime.now();
      _updateStatus(CompanionConnectionStatus.connected);
      _startHeartbeatTimer();
    } catch (e) {
      _scheduleReconnect(e.toString());
    }
  }

  void _handleRawMessage(dynamic raw) {
    try {
      final String text;
      if (raw is String) {
        text = raw;
      } else if (raw is List<int>) {
        text = utf8.decode(raw);
      } else {
        return;
      }

      final dynamic decoded = jsonDecode(text);
      if (decoded is! Map<String, dynamic>) {
        return;
      }

      final envelope = ProtocolEnvelope.fromJson(decoded);
      _lastHeartbeat = DateTime.now();
      _cancelPongTimeout();
      _messageController.add(envelope);

      // Check if it matches a pending request
      if (envelope.type == 'response' && _pendingRequests.containsKey(envelope.id)) {
        final completer = _pendingRequests.remove(envelope.id);
        completer?.complete(envelope);
      }

      // Handle ping/pong protocol events
      if (envelope.name == 'system.ping') {
        final pong = ProtocolEnvelope.createPong(envelope.id);
        send(pong);
      } else if (envelope.name == 'editor.stateChanged') {
        _editorStateController.add(envelope.payload);
      }
    } catch (_) {
      // Discard malformed packets cleanly
    }
  }

  void _handleConnectionDone() {
    _cleanupChannel();
    if (!_explicitlyDisconnected) {
      _scheduleReconnect('Connection closed by remote host');
    } else {
      _updateStatus(CompanionConnectionStatus.disconnected);
    }
  }

  void _handleConnectionError(dynamic error) {
    _cleanupChannel();
    if (!_explicitlyDisconnected) {
      _scheduleReconnect(error.toString());
    } else {
      _updateStatus(CompanionConnectionStatus.error);
    }
  }

  void _scheduleReconnect(String reason) {
    if (_explicitlyDisconnected || _currentConfig == null) {
      _updateStatus(CompanionConnectionStatus.disconnected);
      return;
    }

    _updateStatus(CompanionConnectionStatus.reconnecting);

    // Exponential backoff: min 1s, max 15s (2^attempts seconds capped at 15s)
    final delaySeconds = min(15, pow(2, min(_reconnectAttempts, 4)).toInt());
    _reconnectAttempts++;

    _cancelReconnectTimer();
    _reconnectTimer = Timer(Duration(seconds: delaySeconds), () {
      if (!_explicitlyDisconnected && _currentConfig != null) {
        connect(_currentConfig!);
      }
    });
  }

  void _startHeartbeatTimer() {
    _cancelHeartbeatTimer();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      if (isConnected) {
        final ping = ProtocolEnvelope.createPing();
        send(ping);

        // Schedule timeout: if no activity within 10s after ping, drop socket
        _pongTimeoutTimer = Timer(const Duration(seconds: 10), () {
          if (isConnected) {
            _cleanupChannel();
            _scheduleReconnect('Heartbeat pong timed out');
          }
        });
      }
    });
  }

  void _cancelPongTimeout() {
    _pongTimeoutTimer?.cancel();
    _pongTimeoutTimer = null;
  }

  void _cancelHeartbeatTimer() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _cancelPongTimeout();
  }

  void _cancelReconnectTimer() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
  }

  void _cleanupChannel() {
    _cancelHeartbeatTimer();
    _subscription?.cancel();
    _subscription = null;
    try {
      _channel?.sink.close();
    } catch (_) {}
    _channel = null;

    // Fail any remaining pending requests
    for (final completer in _pendingRequests.values) {
      if (!completer.isCompleted) {
        completer.completeError(
          Exception('Connection closed before response was received'),
        );
      }
    }
    _pendingRequests.clear();
  }

  /// Sends a protocol envelope over the active WebSocket channel.
  bool send(ProtocolEnvelope envelope) {
    if (!isConnected || _channel == null) {
      return false;
    }
    try {
      final jsonStr = jsonEncode(envelope.toJson());
      _channel!.sink.add(jsonStr);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Sends a request and waits for correlated response envelope.
  Future<ProtocolEnvelope> sendRequest(
    String name,
    Map<String, dynamic> payload, {
    Duration timeout = const Duration(seconds: 10),
  }) {
    if (!isConnected) {
      return Future.error(Exception('WebSocket is not connected'));
    }

    final request = ProtocolEnvelope.createRequest(name, payload);
    final completer = Completer<ProtocolEnvelope>();
    _pendingRequests[request.id] = completer;

    final sent = send(request);
    if (!sent) {
      _pendingRequests.remove(request.id);
      return Future.error(Exception('Failed to send request envelope'));
    }

    return completer.future.timeout(
      timeout,
      onTimeout: () {
        _pendingRequests.remove(request.id);
        throw TimeoutException('Request timed out after ${timeout.inSeconds}s', timeout);
      },
    );
  }

  /// Explicitly disconnects and halts reconnection.
  void disconnect() {
    _explicitlyDisconnected = true;
    _cancelReconnectTimer();
    _cleanupChannel();
    _updateStatus(CompanionConnectionStatus.disconnected);
  }

  void dispose() {
    disconnect();
    _statusController.close();
    _messageController.close();
    _editorStateController.close();
  }
}
