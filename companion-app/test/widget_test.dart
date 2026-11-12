import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:companion_app/features/project/data/project_repository.dart';
import 'package:companion_app/features/project/models/project_models.dart';
import 'package:companion_app/features/project/providers/project_provider.dart';
import 'package:companion_app/features/ui/screens/commands_pad_screen.dart';
import 'package:companion_app/features/ui/screens/dashboard_screen.dart';
import 'package:companion_app/features/ui/screens/main_navigation_screen.dart';
import 'package:companion_app/features/ui/screens/project_explorer_screen.dart';

Widget createTestableWidget({
  required Widget child,
  ProjectRepository? repository,
}) {
  final inMemoryRepo = repository ?? InMemoryProjectRepository();
  return ProviderScope(
    overrides: [
      projectRepositoryProvider.overrideWithValue(inMemoryRepo),
    ],
    child: MaterialApp(
      theme: ThemeData(useMaterial3: true),
      home: child,
    ),
  );
}

void main() {
  group('MainNavigationScreen & Tabs Widget Tests', () {
    testWidgets(
      'MainNavigationScreen renders NavigationBar with 4 destinations',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          createTestableWidget(child: const MainNavigationScreen()),
        );
        await tester.pumpAndSettle();

        expect(find.byType(NavigationBar), findsOneWidget);
        expect(find.text('Dashboard'), findsWidgets);
        expect(find.text('Commands'), findsOneWidget);
        expect(find.text('Explorer'), findsOneWidget);
        expect(find.text('Settings'), findsOneWidget);
      },
    );

    testWidgets(
      'Switching tabs updates visible screen content',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          createTestableWidget(child: const MainNavigationScreen()),
        );
        await tester.pumpAndSettle();

        // Initially on Dashboard
        expect(find.text('Connection Status'), findsOneWidget);

        // Tap Commands tab
        await tester.tap(find.text('Commands'));
        await tester.pumpAndSettle();
        expect(find.text('Commands Pad'), findsOneWidget);
        expect(find.text('Create File'), findsOneWidget);

        // Tap Explorer tab
        await tester.tap(find.text('Explorer'));
        await tester.pumpAndSettle();
        expect(find.text('Project Explorer'), findsOneWidget);

        // Tap Settings tab
        await tester.tap(find.text('Settings'));
        await tester.pumpAndSettle();
        expect(find.text('System Diagnostics'), findsOneWidget);
        expect(find.text('Connection Guide'), findsOneWidget);

        // Tap Dashboard tab again
        await tester.tap(find.text('Dashboard').last);
        await tester.pumpAndSettle();
        expect(find.text('Connection Status'), findsOneWidget);
      },
    );

    testWidgets(
      'Dashboard displays connection chips and active editor telemetry card',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          createTestableWidget(child: const DashboardScreen()),
        );
        await tester.pumpAndSettle();

        expect(find.text('Dashboard'), findsOneWidget);
        expect(find.text('Connection Status'), findsOneWidget);
        expect(find.text('HID: Disconnected'), findsOneWidget);
        expect(find.text('WebSocket: Disconnected'), findsOneWidget);
        expect(find.text('Service: Idle'), findsOneWidget);

        expect(find.text('Active Editor Context'), findsOneWidget);
        expect(find.text('No active file'), findsOneWidget);
        expect(find.text('0 Errors'), findsOneWidget);
        expect(find.text('0 Warnings'), findsOneWidget);

        expect(find.text('Quick Connect Controls'), findsOneWidget);
        expect(find.text('USB Loopback'), findsOneWidget);
        expect(find.text('LAN Connect'), findsOneWidget);
      },
    );

    testWidgets(
      'CommandsPadScreen renders quick action cards and triggers feedback',
      (WidgetTester tester) async {
        const MethodChannel hidChannel = MethodChannel('com.companion.koder/hid');
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(hidChannel, (MethodCall call) async {
          if (call.method == 'sendKeyPress') {
            return true;
          }
          return null;
        });
        addTearDown(() {
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
              .setMockMethodCallHandler(hidChannel, null);
        });

        tester.view.physicalSize = const Size(1080, 1920);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          createTestableWidget(child: const CommandsPadScreen()),
        );
        await tester.pumpAndSettle();

        expect(find.text('Commands Pad'), findsOneWidget);
        expect(find.text('Bluetooth HID Shortcuts'), findsOneWidget);
        expect(find.text('Create File'), findsOneWidget);
        expect(find.text('Ctrl + Alt + N'), findsOneWidget);
        expect(find.text('Save Document'), findsOneWidget);
        expect(find.text('Ctrl + S'), findsOneWidget);
        expect(find.text('Format Code'), findsOneWidget);
        expect(find.text('Shift + Alt + F'), findsOneWidget);
        expect(find.text('Command Palette'), findsOneWidget);
        expect(find.text('Quick Open'), findsOneWidget);
        expect(find.text('Find in Files'), findsOneWidget);
        expect(find.text('Toggle Terminal'), findsOneWidget);

        // Tap a command card
        await tester.tap(find.text('Create File'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(
          find.text('Sent Create File (Ctrl + Alt + N)'),
          findsOneWidget,
        );

        // Allow snackbar to dismiss before test finishes
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'ProjectExplorerScreen renders empty state and search bar',
      (WidgetTester tester) async {
        final inMemoryRepo = InMemoryProjectRepository();
        await tester.pumpWidget(
          createTestableWidget(
            child: const ProjectExplorerScreen(),
            repository: inMemoryRepo,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Project Explorer'), findsOneWidget);
        expect(find.byType(TextField), findsOneWidget);
        expect(find.text('No projects imported yet'), findsOneWidget);
      },
    );

    testWidgets(
      'ProjectExplorerScreen displays project hierarchy and exclusion toggles',
      (WidgetTester tester) async {
        final inMemoryRepo = InMemoryProjectRepository();
        final now = DateTime.now().millisecondsSinceEpoch;
        final project = ProjectEntity(
          id: 'proj_test',
          name: 'Test Project',
          source: 'local_dir',
          rootPath: '/test',
          createdAt: now,
          lastAccessedAt: now,
        );
        await inMemoryRepo.insertProject(project);

        const dirNode = FileNodeEntity(
          id: 'node_lib',
          projectId: 'proj_test',
          path: 'lib',
          name: 'lib',
          isDirectory: true,
          parentId: null,
          isExcluded: false,
        );
        const fileNode = FileNodeEntity(
          id: 'node_main',
          projectId: 'proj_test',
          path: 'lib/main.dart',
          name: 'main.dart',
          isDirectory: false,
          parentId: 'node_lib',
          isExcluded: false,
        );
        await inMemoryRepo.insertFileNodes([dirNode, fileNode]);

        await tester.pumpWidget(
          createTestableWidget(
            child: const ProjectExplorerScreen(),
            repository: inMemoryRepo,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Test Project'), findsOneWidget);
        expect(find.text('lib'), findsOneWidget);

        // Initially node_main is not visible because 'lib' is collapsed
        expect(find.text('main.dart'), findsNothing);

        // Tap chevron to expand 'lib'
        await tester.tap(find.byIcon(Icons.chevron_right));
        await tester.pumpAndSettle();

        // Now 'main.dart' should be visible
        expect(find.text('main.dart'), findsOneWidget);

        // Verify checkbox exists for toggling exclusion
        expect(find.byType(Checkbox), findsNWidgets(2));
      },
    );
  });
}
