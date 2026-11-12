import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:companion_app/features/foreground_service/foreground_service_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel serviceChannel =
      MethodChannel('com.companion.koder/service');

  group('ForegroundServiceState Models', () {
    test('default values are initialized correctly', () {
      const state = ForegroundServiceState();
      expect(state.status, equals(ForegroundServiceStatus.idle));
      expect(state.errorMessage, isNull);
    });

    test('copyWith updates status and error correctly', () {
      const state = ForegroundServiceState();
      final updated = state.copyWith(
        status: ForegroundServiceStatus.running,
        errorMessage: 'Test error',
      );
      expect(updated.status, equals(ForegroundServiceStatus.running));
      expect(updated.errorMessage, equals('Test error'));
    });
  });

  group('ForegroundServiceNotifier Unit Tests', () {
    late ForegroundServiceNotifier notifier;
    final List<MethodCall> methodCalls = [];

    setUp(() {
      methodCalls.clear();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(serviceChannel, (MethodCall call) async {
        methodCalls.add(call);
        switch (call.method) {
          case 'startService':
            return true;
          case 'stopService':
            return true;
          default:
            return null;
        }
      });

      notifier = ForegroundServiceNotifier();
    });

    tearDown(() {
      notifier.dispose();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(serviceChannel, null);
    });

    test('startSession calls startService and transitions to running',
        () async {
      final success = await notifier.startSession();
      expect(success, isTrue);
      expect(notifier.state.status, equals(ForegroundServiceStatus.running));
      expect(methodCalls.map((c) => c.method), contains('startService'));
    });

    test('stopSession calls stopService and transitions to idle', () async {
      await notifier.startSession();
      final success = await notifier.stopSession();
      expect(success, isTrue);
      expect(notifier.state.status, equals(ForegroundServiceStatus.idle));
      expect(methodCalls.map((c) => c.method), contains('stopService'));
    });
  });
}
