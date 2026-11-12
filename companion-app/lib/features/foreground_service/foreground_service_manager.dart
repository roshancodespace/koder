import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../bluetooth_hid/bluetooth_hid_service.dart';
import '../bluetooth_hid/models/hid_state.dart';

enum ForegroundServiceStatus {
  idle,
  running,
  error,
}

class ForegroundServiceState {
  final ForegroundServiceStatus status;
  final String? errorMessage;

  const ForegroundServiceState({
    this.status = ForegroundServiceStatus.idle,
    this.errorMessage,
  });

  ForegroundServiceState copyWith({
    ForegroundServiceStatus? status,
    String? errorMessage,
  }) {
    return ForegroundServiceState(
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

class ForegroundServiceNotifier extends StateNotifier<ForegroundServiceState> {
  final MethodChannel _channel;

  ForegroundServiceNotifier({MethodChannel? channel})
      : _channel =
            channel ?? const MethodChannel('com.companion.koder/service'),
        super(const ForegroundServiceState());

  Future<bool> startSession() async {
    try {
      final success = await _channel.invokeMethod<bool>('startService');
      if (success == true) {
        state = state.copyWith(
            status: ForegroundServiceStatus.running, errorMessage: null);
      }
      return success ?? false;
    } catch (e) {
      state = state.copyWith(
        status: ForegroundServiceStatus.error,
        errorMessage: e.toString(),
      );
      return false;
    }
  }

  Future<bool> stopSession() async {
    try {
      final success = await _channel.invokeMethod<bool>('stopService');
      if (success == true) {
        state = state.copyWith(
            status: ForegroundServiceStatus.idle, errorMessage: null);
      }
      return success ?? false;
    } catch (e) {
      state = state.copyWith(
        status: ForegroundServiceStatus.error,
        errorMessage: e.toString(),
      );
      return false;
    }
  }
}

final foregroundServiceStateProvider =
    StateNotifierProvider<ForegroundServiceNotifier, ForegroundServiceState>(
        (ref) {
  final notifier = ForegroundServiceNotifier();

  // Synchronize with HID connection state transitions
  ref.listen<HidState>(bluetoothHidServiceProvider, (previous, next) {
    if (next.status == HidConnectionStatus.connected &&
        previous?.status != HidConnectionStatus.connected) {
      notifier.startSession();
    } else if (next.status == HidConnectionStatus.disconnected &&
        previous?.status == HidConnectionStatus.connected) {
      notifier.stopSession();
    }
  });

  return notifier;
});
