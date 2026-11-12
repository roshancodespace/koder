import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dashboard_screen.dart';
import 'commands_pad_screen.dart';
import 'project_explorer_screen.dart';
import '../../bluetooth_hid/bluetooth_hid_service.dart';
import '../../foreground_service/foreground_service_manager.dart';
import '../../network/providers/websocket_provider.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  static const List<Widget> _screens = [
    DashboardScreen(),
    CommandsPadScreen(),
    ProjectExplorerScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (int index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.keyboard_outlined),
            selectedIcon: Icon(Icons.keyboard),
            label: 'Commands',
          ),
          NavigationDestination(
            icon: Icon(Icons.folder_outlined),
            selectedIcon: Icon(Icons.folder),
            label: 'Explorer',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final hidState = ref.watch(bluetoothHidServiceProvider);
    final serviceState = ref.watch(foregroundServiceStateProvider);
    final netState = ref.watch(companionNetworkStateProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        elevation: 0,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            Text(
              'System Diagnostics',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.bluetooth),
                    title: const Text('Bluetooth HID Profile'),
                    subtitle: Text(
                      'Status: ${hidState.status.name} | Supported: ${hidState.capability.isSupported}',
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.security),
                    title: const Text('Foreground Service'),
                    subtitle: Text(
                      'Status: ${serviceState.status.name}${serviceState.errorMessage != null ? " (${serviceState.errorMessage})" : ""}',
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.wifi),
                    title: const Text('WebSocket Server Link'),
                    subtitle: Text(
                      'Host: ${netState.config.host}:${netState.config.port} | Mode: ${netState.config.mode.name} | Status: ${netState.status.name}',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Connection Guide',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'USB Loopback Mode (Recommended)',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Run "adb reverse tcp:38848 tcp:38848" on your workstation, then connect via Dashboard. Zero network exposure and ultra-low latency.',
                      style: TextStyle(fontSize: 13),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Wi-Fi / LAN Mode',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Enable LAN binding in VS Code extension settings. Enter host IP and 6-character pairing token shown in the VS Code status bar.',
                      style: TextStyle(fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'About',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Card(
              child: ListTile(
                leading: Icon(Icons.info_outline),
                title: Text('VS Code Companion'),
                subtitle: Text('Version 0.1.0 (Android Companion App)'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
