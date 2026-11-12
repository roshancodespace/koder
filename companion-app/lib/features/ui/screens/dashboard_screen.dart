import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../bluetooth_hid/bluetooth_hid_service.dart';
import '../../bluetooth_hid/models/hid_state.dart';
import '../../foreground_service/foreground_service_manager.dart';
import '../../network/models/connection_state.dart';
import '../../network/providers/websocket_provider.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final hidState = ref.watch(bluetoothHidServiceProvider);
    final serviceState = ref.watch(foregroundServiceStateProvider);
    final networkState = ref.watch(companionNetworkStateProvider);

    final isHidConnected = hidState.status == HidConnectionStatus.connected;
    final isServiceRunning =
        serviceState.status == ForegroundServiceStatus.running;
    final isWsConnected = networkState.isConnected;

    final editorState = networkState.activeEditorState;
    final activeFile = (editorState?['relativePath'] as String?) ??
        (editorState?['activeFileUri'] as String?) ??
        'No active file';
    final languageId = (editorState?['languageId'] as String?) ?? '';
    final diagnostics = editorState?['diagnostics'] as Map<String, dynamic>?;
    final errorCount = (diagnostics?['errorCount'] as int?) ?? 0;
    final warningCount = (diagnostics?['warningCount'] as int?) ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        elevation: 0,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16.0),
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
                FilterChip(
                  avatar: Icon(
                    isHidConnected
                        ? Icons.bluetooth_connected
                        : Icons.bluetooth,
                    color: isHidConnected ? Colors.blue : null,
                    size: 18,
                  ),
                  label: Text(
                      'HID: ${isHidConnected ? 'Connected' : 'Disconnected'}'),
                  selected: isHidConnected,
                  onSelected: (_) {
                    final notifier =
                        ref.read(bluetoothHidServiceProvider.notifier);
                    if (!isHidConnected) {
                      notifier.registerApp();
                    }
                  },
                ),
                FilterChip(
                  avatar: Icon(
                    isWsConnected ? Icons.wifi : Icons.wifi_off,
                    color: isWsConnected ? Colors.green : null,
                    size: 18,
                  ),
                  label: Text(
                    'WebSocket: ${_getWsStatusLabel(networkState.status)}',
                  ),
                  selected: isWsConnected,
                  onSelected: (_) {
                    final notifier =
                        ref.read(companionNetworkStateProvider.notifier);
                    if (isWsConnected) {
                      notifier.disconnect();
                    } else {
                      notifier.connectLoopback();
                    }
                  },
                ),
                FilterChip(
                  avatar: Icon(
                    isServiceRunning ? Icons.security : Icons.security_outlined,
                    color: isServiceRunning ? Colors.orange : null,
                    size: 18,
                  ),
                  label:
                      Text('Service: ${isServiceRunning ? 'Active' : 'Idle'}'),
                  selected: isServiceRunning,
                  onSelected: (_) {
                    final manager = ref.read(foregroundServiceStateProvider.notifier);
                    if (isServiceRunning) {
                      manager.stopSession();
                    } else {
                      manager.startSession();
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              'Active Editor Context',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            activeFile,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (languageId.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              languageId.toUpperCase(),
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onPrimaryContainer,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const Divider(height: 24),
                    Row(
                      children: [
                        _DiagnosticBadge(
                          icon: Icons.error,
                          count: errorCount,
                          color: Colors.redAccent,
                          label: 'Errors',
                        ),
                        const SizedBox(width: 16),
                        _DiagnosticBadge(
                          icon: Icons.warning,
                          count: warningCount,
                          color: Colors.amber,
                          label: 'Warnings',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Quick Connect Controls',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.usb),
                    label: const Text('USB Loopback'),
                    onPressed: () {
                      ref
                          .read(companionNetworkStateProvider.notifier)
                          .connectLoopback(port: 38848);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.lan),
                    label: const Text('LAN Connect'),
                    onPressed: () => _showLanConnectDialog(context, ref),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _getWsStatusLabel(CompanionConnectionStatus status) {
    switch (status) {
      case CompanionConnectionStatus.connected:
        return 'Connected';
      case CompanionConnectionStatus.connecting:
        return 'Connecting';
      case CompanionConnectionStatus.reconnecting:
        return 'Reconnecting';
      case CompanionConnectionStatus.error:
        return 'Error';
      case CompanionConnectionStatus.disconnected:
        return 'Disconnected';
    }
  }

  void _showLanConnectDialog(BuildContext context, WidgetRef ref) {
    final hostController = TextEditingController(text: '192.168.1.');
    final portController = TextEditingController(text: '38848');
    final tokenController = TextEditingController();

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Connect over LAN Wi-Fi'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: hostController,
              decoration: const InputDecoration(labelText: 'Host IP Address'),
            ),
            TextField(
              controller: portController,
              decoration:
                  const InputDecoration(labelText: 'Port (default 38848)'),
              keyboardType: TextInputType.number,
            ),
            TextField(
              controller: tokenController,
              decoration: const InputDecoration(
                labelText: 'Pairing Token (from VS Code)',
                hintText: '6-character token',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final host = hostController.text.trim();
              final port = int.tryParse(portController.text.trim()) ?? 38848;
              final token = tokenController.text.trim();
              ref.read(companionNetworkStateProvider.notifier).connectLan(
                    host,
                    port,
                    token: token.isNotEmpty ? token : null,
                  );
              Navigator.pop(ctx);
            },
            child: const Text('Connect'),
          ),
        ],
      ),
    );
  }
}

class _DiagnosticBadge extends StatelessWidget {
  final IconData icon;
  final int count;
  final Color color;
  final String label;

  const _DiagnosticBadge({
    required this.icon,
    required this.count,
    required this.color,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 6),
        Text(
          '$count $label',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}
