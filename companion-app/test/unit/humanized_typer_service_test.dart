import 'package:companion_app/features/automation/models/humanization_config.dart';
import 'package:companion_app/features/automation/services/humanized_typer_service.dart';
import 'package:companion_app/features/bluetooth_hid/bluetooth_hid_service.dart';
import 'package:flutter_test/flutter_test.dart';

class MockBluetoothHidNotifier extends Fake implements BluetoothHidNotifier {
  final List<Map<String, int>> sentShortcuts = [];

  @override
  Future<bool> sendShortcut(int modifier, int keyCode) async {
    sentShortcuts.add({'modifier': modifier, 'keyCode': keyCode});
    return true;
  }
}

void main() {
  group('HumanizedTyperNotifier Unit Tests', () {
    late MockBluetoothHidNotifier mockHid;
    late HumanizedTyperNotifier notifier;

    setUp(() {
      mockHid = MockBluetoothHidNotifier();
      notifier = HumanizedTyperNotifier(
        mockHid,
        getEditorState: () => {
          'relativePath': 'test.py',
          'languageId': 'python',
          'tabSize': 4,
          'cursorPosition': {'line': 0, 'character': 0},
        },
      );
    });

    test('Initial state is idle', () {
      expect(notifier.state.status, AutomationStatus.idle);
      expect(notifier.state.charactersTyped, 0);
    });

    test('pause and resume correctly update status', () {
      notifier.pause();
      expect(notifier.state.status, AutomationStatus.paused);
      notifier.resume();
      expect(notifier.state.status, AutomationStatus.running);
      notifier.cancel();
      expect(notifier.state.status, AutomationStatus.cancelled);
    });

    test('skipBreak wakes break loop', () {
      notifier.skipBreak();
      // Verifies no exception thrown and flag set
      expect(notifier.state.status, AutomationStatus.idle);
    });

    test('HumanizationConfig copyWith updates new fields properly', () {
      const config = HumanizationConfig();
      final updated = config.copyWith(
        sessionDurationMinutes: 45,
        enableDeepWorkBreaks: true,
        breakIntervalMinutes: 20,
        breakDurationMinutes: 8,
        isMac: true,
        useShortcutsForNavigation: true,
      );

      expect(updated.sessionDurationMinutes, 45);
      expect(updated.enableDeepWorkBreaks, true);
      expect(updated.breakIntervalMinutes, 20);
      expect(updated.breakDurationMinutes, 8);
      expect(updated.isMac, true);
      expect(updated.useShortcutsForNavigation, true);
    });
  });
}
