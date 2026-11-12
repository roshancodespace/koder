import 'package:flutter_test/flutter_test.dart';
import 'package:companion_app/features/network/models/protocol_envelope.dart';
import 'package:companion_app/features/network/models/connection_state.dart';

void main() {
  group('ProtocolEnvelope & ProtocolError Unit Tests', () {
    test('ProtocolEnvelope round-trip JSON serialization', () {
      const original = ProtocolEnvelope(
        id: 'msg-12345',
        type: 'event',
        name: 'editor.stateChanged',
        payload: {
          'activeFile': 'src/main.ts',
          'cursor': {'line': 10, 'character': 5},
          'diagnostics': {'errorCount': 1, 'warningCount': 0},
        },
        timestamp: 1731405000000,
      );

      final jsonMap = original.toJson();
      expect(jsonMap['version'], '1.0');
      expect(jsonMap['id'], 'msg-12345');
      expect(jsonMap['type'], 'event');
      expect(jsonMap['name'], 'editor.stateChanged');
      expect(jsonMap['timestamp'], 1731405000000);
      expect(jsonMap.containsKey('error'), isFalse);

      final deserialized = ProtocolEnvelope.fromJson(jsonMap);
      expect(deserialized.version, '1.0');
      expect(deserialized.id, original.id);
      expect(deserialized.type, original.type);
      expect(deserialized.name, original.name);
      expect(deserialized.payload['activeFile'], 'src/main.ts');
      expect(deserialized.error, isNull);
    });

    test(
        'ProtocolEnvelope with ProtocolError serializes and deserializes correctly',
        () {
      final errorEnvelope = ProtocolEnvelope.createError(
        'req-999',
        'workspace.createFile',
        'FILE_ALREADY_EXISTS',
        'File cannot be overwritten implicitly',
        details: {'path': 'src/index.ts'},
      );

      final jsonMap = errorEnvelope.toJson();
      expect(jsonMap['error'], isNotNull);
      expect(jsonMap['error']['code'], 'FILE_ALREADY_EXISTS');
      expect(
          jsonMap['error']['message'], 'File cannot be overwritten implicitly');
      expect(jsonMap['error']['details']['path'], 'src/index.ts');

      final parsed = ProtocolEnvelope.fromJson(jsonMap);
      expect(parsed.id, 'req-999');
      expect(parsed.error, isNotNull);
      expect(parsed.error!.code, 'FILE_ALREADY_EXISTS');
      expect(parsed.error!.message, 'File cannot be overwritten implicitly');
    });

    test('Factory constructors produce valid envelopes', () {
      final event =
          ProtocolEnvelope.createEvent('system.alert', {'level': 'info'});
      expect(event.type, 'event');
      expect(event.name, 'system.alert');
      expect(event.id.startsWith('evt-'), isTrue);

      final request = ProtocolEnvelope.createRequest('editor.getState', {});
      expect(request.type, 'request');
      expect(request.name, 'editor.getState');
      expect(request.id.startsWith('req-'), isTrue);

      final ping = ProtocolEnvelope.createPing();
      expect(ping.name, 'system.ping');
      expect(ping.type, 'request');

      final pong = ProtocolEnvelope.createPong(ping.id);
      expect(pong.name, 'system.pong');
      expect(pong.type, 'response');
      expect(pong.id, ping.id);
    });
  });

  group('CompanionConnectionConfig & CompanionNetworkState Unit Tests', () {
    test('targetUri formats correct loopback and LAN URLs', () {
      const loopbackConfig = CompanionConnectionConfig(
        host: '127.0.0.1',
        port: 38848,
        mode: NetworkConnectionMode.loopbackUsb,
      );
      expect(loopbackConfig.targetUri.toString(), 'ws://127.0.0.1:38848');

      const lanConfig = CompanionConnectionConfig(
        host: '192.168.1.150',
        port: 38849,
        mode: NetworkConnectionMode.lanWifi,
        pairingToken: 'ABC123',
      );
      expect(lanConfig.targetUri.toString(),
          'ws://192.168.1.150:38849?token=ABC123');
    });

    test('CompanionNetworkState copyWith updates fields correctly', () {
      const state = CompanionNetworkState();
      expect(state.status, CompanionConnectionStatus.disconnected);
      expect(state.isConnected, isFalse);

      final connectingState =
          state.copyWith(status: CompanionConnectionStatus.connecting);
      expect(connectingState.isConnecting, isTrue);
      expect(connectingState.isConnected, isFalse);

      final connectedState = connectingState.copyWith(
        status: CompanionConnectionStatus.connected,
        activeEditorState: {'file': 'lib/main.dart'},
      );
      expect(connectedState.isConnected, isTrue);
      expect(connectedState.activeEditorState!['file'], 'lib/main.dart');
    });
  });
}
