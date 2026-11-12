import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'models/hid_state.dart';

class BluetoothHidNotifier extends StateNotifier<HidState> {
  final MethodChannel _methodChannel;
  final EventChannel _eventChannel;
  StreamSubscription<dynamic>? _eventSubscription;

  BluetoothHidNotifier({
    MethodChannel? methodChannel,
    EventChannel? eventChannel,
  })  : _methodChannel =
            methodChannel ?? const MethodChannel('com.companion.koder/hid'),
        _eventChannel = eventChannel ??
            const EventChannel('com.companion.koder/hid_events'),
        super(const HidState()) {
    _initEventListener();
  }

  void _initEventListener() {
    _eventSubscription = _eventChannel.receiveBroadcastStream().listen(
      (dynamic event) {
        if (event is Map) {
          final statusString = event['status'] as String?;
          _handleStatusUpdate(statusString);
        }
      },
      onError: (dynamic error) {
        state = state.copyWith(
          status: HidConnectionStatus.error,
          lastError: error.toString(),
        );
      },
    );
  }

  void _handleStatusUpdate(String? status) {
    switch (status) {
      case 'CONNECTED':
        state = state.copyWith(
            status: HidConnectionStatus.connected, lastError: null);
        break;
      case 'CONNECTING':
        state = state.copyWith(
            status: HidConnectionStatus.connecting, lastError: null);
        break;
      case 'DISCONNECTING':
        state = state.copyWith(
            status: HidConnectionStatus.disconnecting, lastError: null);
        break;
      case 'DISCONNECTED':
      case 'UNREGISTERED':
        state = state.copyWith(
            status: HidConnectionStatus.disconnected, lastError: null);
        break;
      case 'REGISTERED':
        state = state.copyWith(
            status: HidConnectionStatus.disconnected, lastError: null);
        break;
      default:
        break;
    }
  }

  Future<HidCapability> checkCapability() async {
    try {
      final result = await _methodChannel
          .invokeMethod<Map<dynamic, dynamic>>('checkCapability');
      final capability = HidCapability.fromMap(result);
      state = state.copyWith(capability: capability);
      return capability;
    } catch (e) {
      final errorCapability = HidCapability(
        isSupported: false,
        isEnabled: false,
        hasProfileProxy: false,
        errorMessage: e.toString(),
      );
      state = state.copyWith(capability: errorCapability);
      return errorCapability;
    }
  }

  Future<bool> registerApp() async {
    try {
      final registered = await _methodChannel.invokeMethod<bool>('registerApp');
      return registered ?? false;
    } catch (e) {
      state = state.copyWith(lastError: e.toString());
      return false;
    }
  }

  Future<bool> unregisterApp() async {
    try {
      final unregistered =
          await _methodChannel.invokeMethod<bool>('unregisterApp');
      return unregistered ?? false;
    } catch (e) {
      state = state.copyWith(lastError: e.toString());
      return false;
    }
  }

  Future<List<BluetoothDeviceInfo>> getBondedDevices() async {
    try {
      final rawList = await _methodChannel
          .invokeListMethod<Map<dynamic, dynamic>>('getBondedDevices');
      final devices = (rawList ?? [])
          .map((item) => BluetoothDeviceInfo.fromMap(item))
          .toList();
      state = state.copyWith(bondedDevices: devices);
      return devices;
    } catch (e) {
      state = state.copyWith(lastError: e.toString());
      return [];
    }
  }

  Future<void> openBluetoothSettings() async {
    try {
      await _methodChannel.invokeMethod<bool>('openBluetoothSettings');
    } catch (_) {}
  }

  Future<bool> connect(String macAddress) async {
    try {
      state = state.copyWith(
        status: HidConnectionStatus.connecting,
        connectedDeviceAddress: macAddress,
      );
      final connected = await _methodChannel
          .invokeMethod<bool>('connect', {'macAddress': macAddress});
      return connected ?? false;
    } catch (e) {
      state = state.copyWith(
        status: HidConnectionStatus.error,
        lastError: e.toString(),
      );
      return false;
    }
  }

  Future<bool> disconnect() async {
    try {
      state = state.copyWith(status: HidConnectionStatus.disconnecting);
      final disconnected =
          await _methodChannel.invokeMethod<bool>('disconnect');
      if (disconnected == true) {
        state = state.copyWith(
          status: HidConnectionStatus.disconnected,
          connectedDeviceAddress: null,
        );
      }
      return disconnected ?? false;
    } catch (e) {
      state = state.copyWith(
        status: HidConnectionStatus.error,
        lastError: e.toString(),
      );
      return false;
    }
  }

  Future<bool> sendShortcut(int modifier, int keyCode) async {
    try {
      final sent = await _methodChannel.invokeMethod<bool>('sendKeyPress', {
        'modifier': modifier,
        'keyCode': keyCode,
      });
      return sent ?? false;
    } catch (e) {
      state = state.copyWith(lastError: e.toString());
      return false;
    }
  }

  @override
  void dispose() {
    _eventSubscription?.cancel();
    super.dispose();
  }
}

final bluetoothHidServiceProvider =
    StateNotifierProvider<BluetoothHidNotifier, HidState>((ref) {
  return BluetoothHidNotifier();
});
