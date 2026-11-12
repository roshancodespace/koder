import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'features/bluetooth_hid/bluetooth_hid_service.dart';
import 'features/bluetooth_hid/models/hid_state.dart';
import 'features/foreground_service/foreground_service_manager.dart';

void main() {
  runApp(const CompanionApp());
}

class CompanionApp extends StatelessWidget {
  const CompanionApp({super.key});

  static const Color seedColor = Colors.indigo;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      child: MaterialApp(
        title: 'VS Code Companion',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: seedColor,
            brightness: Brightness.light,
          ),
        ),
        darkTheme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: seedColor,
            brightness: Brightness.dark,
          ),
        ),
        themeMode: ThemeMode.system,
        home: const HomeScreen(),
      ),
    );
  }
}

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final hidState = ref.watch(bluetoothHidServiceProvider);
    final serviceState = ref.watch(foregroundServiceStateProvider);

    final isHidConnected = hidState.status == HidConnectionStatus.connected;
    final isServiceRunning = serviceState.status == ForegroundServiceStatus.running;

    return Scaffold(
      appBar: AppBar(
        title: const Text('VS Code Companion'),
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Connection Status',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8.0,
                runSpacing: 8.0,
                children: [
                  Chip(
                    avatar: Icon(
                      isHidConnected ? Icons.bluetooth_connected : Icons.bluetooth,
                      size: 18,
                    ),
                    label: Text(
                      'Bluetooth HID: ${isHidConnected ? 'Connected' : 'Disconnected'}',
                    ),
                  ),
                  const Chip(
                    avatar: Icon(Icons.wifi, size: 18),
                    label: Text('WebSocket: Disconnected'),
                  ),
                  Chip(
                    avatar: Icon(
                      isServiceRunning ? Icons.security : Icons.security_outlined,
                      size: 18,
                    ),
                    label: Text(
                      'Foreground: ${isServiceRunning ? 'Active' : 'Idle'}',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                'Diagnostics',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Card(
                elevation: 1,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isHidConnected ? 'Companion Active' : 'System Ready',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        hidState.lastError != null
                            ? 'Error: ${hidState.lastError}'
                            : (hidState.capability.errorMessage.isNotEmpty
                                ? 'Capability: ${hidState.capability.errorMessage}'
                                : 'Bluetooth HID and Android foreground service initialized.'),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
