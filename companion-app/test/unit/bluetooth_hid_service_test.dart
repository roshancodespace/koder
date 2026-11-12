import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:companion_app/features/bluetooth_hid/models/hid_state.dart';
import 'package:companion_app/features/bluetooth_hid/bluetooth_hid_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel methodChannel = MethodChannel('com.companion.koder/hid');

  group('HidState & HidCapability Models', () {
    test('default values are initialized correctly', () {
      const capability = HidCapability();
      expect(capability.isSupported, isFalse);
      expect(capability.isEnabled, isFalse);
      expect(capability.hasProfileProxy, isFalse);
      expect(capability.errorMessage, isEmpty);

      const state = HidState();
      expect(state.status, equals(HidConnectionStatus.disconnected));
      expect(state.connectedDeviceAddress, isNull);
      expect(state.lastError, isNull);
    });

    test('fromMap correctly deserializes capability', () {
      final map = {
        'isSupported': true,
        'isEnabled': true,
        'hasProfileProxy': true,
        'errorMessage': '',
      };
      final capability = HidCapability.fromMap(map);
      expect(capability.isSupported, isTrue);
      expect(capability.isEnabled, isTrue);
      expect(capability.hasProfileProxy, isTrue);
      expect(capability.errorMessage, isEmpty);
    });

    test('copyWith updates fields as expected', () {
      const state = HidState();
      final updated = state.copyWith(
        status: HidConnectionStatus.connected,
        connectedDeviceAddress: 'AA:BB:CC:DD:EE:FF',
      );
      expect(updated.status, equals(HidConnectionStatus.connected));
      expect(updated.connectedDeviceAddress, equals('AA:BB:CC:DD:EE:FF'));
    });
  });

  group('BluetoothHidNotifier Unit Tests', () {
    late BluetoothHidNotifier notifier;
    final List<MethodCall> methodCalls = [];

    setUp(() {
      methodCalls.clear();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(methodChannel, (MethodCall call) async {
        methodCalls.add(call);
        switch (call.method) {
          case 'checkCapability':
            return {
              'isSupported': true,
              'isEnabled': true,
              'hasProfileProxy': true,
              'errorMessage': '',
            };
          case 'registerApp':
            return true;
          case 'unregisterApp':
            return true;
          case 'connect':
            return true;
          case 'disconnect':
            return true;
          case 'sendKeyPress':
            return true;
          case 'setDeviceSpoof':
            return true;
          case 'makeDiscoverable':
            return true;
          case 'getSpoofProfile':
            return {
              'presetId': 'logitech_mx_keys',
              'deviceName': 'Logitech MX Keys',
              'provider': 'Logitech',
              'description': 'Logitech MX Keys Advanced Wireless Keyboard',
            };
          default:
            return null;
        }
      });

      notifier = BluetoothHidNotifier();
    });

    tearDown(() {
      notifier.dispose();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(methodChannel, null);
    });

    test('checkCapability calls channel and updates state', () async {
      final cap = await notifier.checkCapability();
      expect(cap.isSupported, isTrue);
      expect(notifier.state.capability.isSupported, isTrue);
      expect(methodCalls.map((c) => c.method), contains('checkCapability'));
    });

    test('registerApp calls channel', () async {
      final result = await notifier.registerApp();
      expect(result, isTrue);
      expect(methodCalls.map((c) => c.method), contains('registerApp'));
    });

    test('connect calls channel with mac address', () async {
      final result = await notifier.connect('11:22:33:44:55:66');
      expect(result, isTrue);
      expect(notifier.state.status, equals(HidConnectionStatus.connecting));
      expect(
          notifier.state.connectedDeviceAddress, equals('11:22:33:44:55:66'));
      expect(methodCalls.map((c) => c.method), contains('connect'));
      final connectCall = methodCalls.firstWhere((c) => c.method == 'connect');
      expect(connectCall.arguments['macAddress'], equals('11:22:33:44:55:66'));
    });

    test('sendShortcut calls channel with modifier and keycode', () async {
      final result = await notifier.sendShortcut(0x01, 0x04);
      expect(result, isTrue);
      expect(methodCalls.map((c) => c.method), contains('sendKeyPress'));
      final sendCall =
          methodCalls.firstWhere((c) => c.method == 'sendKeyPress');
      expect(sendCall.arguments['modifier'], equals(0x01));
      expect(sendCall.arguments['keyCode'], equals(0x04));
    });

    test('setSpoofPreset updates activeSpoof and invokes setDeviceSpoof',
        () async {
      final applePreset =
          KeyboardSpoofPreset.presets.firstWhere((p) => p.id == 'apple_magic');
      final result = await notifier.setSpoofPreset(applePreset);
      expect(result, isTrue);
      expect(notifier.state.activeSpoof, equals(applePreset));
      expect(methodCalls.map((c) => c.method), contains('setDeviceSpoof'));
      final spoofCall =
          methodCalls.firstWhere((c) => c.method == 'setDeviceSpoof');
      expect(spoofCall.arguments['presetId'], equals(applePreset.id));
      expect(spoofCall.arguments['deviceName'], equals(applePreset.deviceName));
      expect(spoofCall.arguments['provider'], equals(applePreset.provider));
    });

    test('clearError resets lastError in state to null', () {
      notifier.state =
          notifier.state.copyWith(lastError: 'Simulated connection failure');
      expect(notifier.state.lastError, equals('Simulated connection failure'));

      notifier.clearError();
      expect(notifier.state.lastError, isNull);
    });

    test('makeDiscoverable calls channel and updates state', () async {
      final result = await notifier.makeDiscoverable(durationSeconds: 300);
      expect(result, isTrue);
      expect(notifier.state.isDiscoverable, isTrue);
      expect(methodCalls.map((c) => c.method), contains('makeDiscoverable'));
      final discCall =
          methodCalls.firstWhere((c) => c.method == 'makeDiscoverable');
      expect(discCall.arguments['duration'], equals(300));
    });
  });
}
