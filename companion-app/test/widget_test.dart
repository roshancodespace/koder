import 'package:flutter_test/flutter_test.dart';
import 'package:companion_app/main.dart';

void main() {
  testWidgets('CompanionApp smoke test renders title and connection chips',
      (WidgetTester tester) async {
    await tester.pumpWidget(const CompanionApp());

    expect(find.text('VS Code Companion'), findsOneWidget);
    expect(find.text('Bluetooth HID: Disconnected'), findsOneWidget);
    expect(find.text('WebSocket: Disconnected'), findsOneWidget);
  });
}
