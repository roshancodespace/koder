import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:companion_app/features/network/models/connection_state.dart';
import 'package:companion_app/features/network/models/protocol_envelope.dart';
import 'package:companion_app/features/network/services/websocket_client_service.dart';
import 'package:companion_app/features/network/providers/websocket_provider.dart';

class FakeWebSocketSink implements WebSocketSink {
  final List<dynamic> sentMessages = [];
  final Completer<void> _doneCompleter = Completer<void>();

  @override
  void add(dynamic data) {
    sentMessages.add(data);
  }

  @override
  void addError(Object error, [StackTrace? stackTrace]) {}

  @override
  Future<void> addStream(Stream<dynamic> stream) async {
    await for (final data in stream) {
      sentMessages.add(data);
    }
  }

  @override
  Future<void> close([int? closeCode, String? closeReason]) async {
    if (!_doneCompleter.isCompleted) {
      _doneCompleter.complete();
    }
  }

  @override
  Future<void> get done => _doneCompleter.future;
}

class FakeWebSocketChannel
    with StreamChannelMixin<dynamic>
    implements WebSocketChannel {
  final StreamController<dynamic> incomingController =
      StreamController<dynamic>();
  final FakeWebSocketSink outgoingSink = FakeWebSocketSink();

  @override
  Stream<dynamic> get stream => incomingController.stream;

  @override
  WebSocketSink get sink => outgoingSink;

  @override
  String? get protocol => null;

  @override
  int? get closeCode => null;

  @override
  String? get closeReason => null;

  @override
  Future<void> get ready => Future.value();
}

void main() {
  group('WebSocketClientService Unit Tests', () {
    late FakeWebSocketChannel fakeChannel;
    late WebSocketClientService service;

    setUp(() {
      fakeChannel = FakeWebSocketChannel();
      service = WebSocketClientService(
        channelFactory: (uri) => fakeChannel,
      );
    });

    tearDown(() {
      service.dispose();
      fakeChannel.incomingController.close();
    });

    test(
        'connect transitions status to connected and receives incoming messages',
        () async {
      final statuses = <CompanionConnectionStatus>[];
      service.onStatusChanged.listen(statuses.add);

      const config = CompanionConnectionConfig(
        host: '127.0.0.1',
        port: 38848,
        mode: NetworkConnectionMode.loopbackUsb,
      );

      await service.connect(config);
      expect(service.status, CompanionConnectionStatus.connected);
      expect(service.isConnected, isTrue);

      // Verify incoming editor state event dispatch
      final editorStates = <Map<String, dynamic>>[];
      service.onEditorStateChanged.listen(editorStates.add);

      final event = ProtocolEnvelope.createEvent('editor.stateChanged', {
        'relativePath': 'lib/main.dart',
        'diagnostics': {'errorCount': 0, 'warningCount': 0},
      });

      fakeChannel.incomingController.add(jsonEncode(event.toJson()));
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(editorStates.length, 1);
      expect(editorStates.first['relativePath'], 'lib/main.dart');
    });

    test('automatic ping receives automatic pong response', () async {
      await service.connect(const CompanionConnectionConfig());

      final ping = ProtocolEnvelope.createPing();
      fakeChannel.incomingController.add(jsonEncode(ping.toJson()));
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(fakeChannel.outgoingSink.sentMessages.length, 1);
      final replyJson =
          jsonDecode(fakeChannel.outgoingSink.sentMessages.first as String)
              as Map<String, dynamic>;
      final replyEnvelope = ProtocolEnvelope.fromJson(replyJson);

      expect(replyEnvelope.type, 'response');
      expect(replyEnvelope.name, 'system.pong');
      expect(replyEnvelope.id, ping.id);
    });

    test('sendRequest dispatches request and resolves matching response',
        () async {
      await service.connect(const CompanionConnectionConfig());

      final requestFuture = service.sendRequest('workspace.createFile', {
        'path': 'test.txt',
      });

      // Verify request was sent to channel
      expect(fakeChannel.outgoingSink.sentMessages.length, 1);
      final sentJson =
          jsonDecode(fakeChannel.outgoingSink.sentMessages.first as String)
              as Map<String, dynamic>;
      final sentEnvelope = ProtocolEnvelope.fromJson(sentJson);
      expect(sentEnvelope.name, 'workspace.createFile');

      // Simulate host response
      final response = ProtocolEnvelope.createResponse(
        sentEnvelope.id,
        'workspace.createFile',
        {'uri': 'file:///workspace/test.txt'},
      );
      fakeChannel.incomingController.add(jsonEncode(response.toJson()));

      final result = await requestFuture;
      expect(result.id, sentEnvelope.id);
      expect(result.payload['uri'], 'file:///workspace/test.txt');
    });

    test('disconnect halts service cleanly', () async {
      await service.connect(const CompanionConnectionConfig());
      expect(service.isConnected, isTrue);

      service.disconnect();
      expect(service.status, CompanionConnectionStatus.disconnected);
      expect(service.isConnected, isFalse);
    });
  });

  group('CompanionNetworkNotifier & Riverpod Unit Tests', () {
    late FakeWebSocketChannel fakeChannel;
    late WebSocketClientService service;
    late ProviderContainer container;

    setUp(() {
      fakeChannel = FakeWebSocketChannel();
      service = WebSocketClientService(
        channelFactory: (uri) => fakeChannel,
      );
      container = ProviderContainer(
        overrides: [
          websocketClientServiceProvider.overrideWithValue(service),
        ],
      );
    });

    tearDown(() {
      container.dispose();
      service.dispose();
    });

    test('connectLoopback updates state and connects to 127.0.0.1:38848',
        () async {
      final notifier = container.read(companionNetworkStateProvider.notifier);
      await notifier.connectLoopback(port: 38848);

      final state = container.read(companionNetworkStateProvider);
      expect(state.config.host, '127.0.0.1');
      expect(state.config.port, 38848);
      expect(state.config.mode, NetworkConnectionMode.loopbackUsb);
      expect(state.status, CompanionConnectionStatus.connected);
    });

    test('connectLan sets LAN configuration with pairing token', () async {
      final notifier = container.read(companionNetworkStateProvider.notifier);
      await notifier.connectLan('192.168.0.50', 38850, token: 'XYZ789');

      final state = container.read(companionNetworkStateProvider);
      expect(state.config.host, '192.168.0.50');
      expect(state.config.port, 38850);
      expect(state.config.pairingToken, 'XYZ789');
      expect(state.config.mode, NetworkConnectionMode.lanWifi);
      expect(state.status, CompanionConnectionStatus.connected);
    });

    test('editor state events update Riverpod activeEditorState', () async {
      final notifier = container.read(companionNetworkStateProvider.notifier);
      await notifier.connectLoopback();

      final event = ProtocolEnvelope.createEvent('editor.stateChanged', {
        'languageId': 'dart',
        'diagnostics': {'errorCount': 2, 'warningCount': 1},
      });

      fakeChannel.incomingController.add(jsonEncode(event.toJson()));
      await Future<void>.delayed(const Duration(milliseconds: 10));

      final state = container.read(companionNetworkStateProvider);
      expect(state.activeEditorState, isNotNull);
      expect(state.activeEditorState!['languageId'], 'dart');
    });
  });
}
