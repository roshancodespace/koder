import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../bluetooth_hid/bluetooth_hid_service.dart';
import '../../bluetooth_hid/models/hid_state.dart';
import '../../foreground_service/foreground_service_manager.dart';
import '../../network/models/connection_state.dart';
import '../../network/providers/websocket_provider.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  bool _isBatteryOptimizationIgnored = true;
  bool _isLoadingDevices = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshDashboard();
    });
  }

  Future<void> _refreshDashboard() async {
    setState(() => _isLoadingDevices = true);
    final hidNotifier = ref.read(bluetoothHidServiceProvider.notifier);
    final serviceNotifier = ref.read(foregroundServiceStateProvider.notifier);

    await hidNotifier.checkCapability();
    await hidNotifier.getBondedDevices();
    final batteryIgnored = await serviceNotifier.isBatteryOptimizationIgnored();

    if (mounted) {
      setState(() {
        _isBatteryOptimizationIgnored = batteryIgnored;
        _isLoadingDevices = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hidState = ref.watch(bluetoothHidServiceProvider);
    final serviceState = ref.watch(foregroundServiceStateProvider);
    final networkState = ref.watch(companionNetworkStateProvider);

    final isBluetoothEnabled = hidState.capability.isEnabled;
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
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Status',
            onPressed: _refreshDashboard,
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refreshDashboard,
          child: ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              // 1. Connection Status Chips
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
                          : (isBluetoothEnabled
                              ? Icons.bluetooth
                              : Icons.bluetooth_disabled),
                      color: isHidConnected ? Colors.blue : null,
                      size: 18,
                    ),
                    label: Text(
                      'HID: ${isHidConnected ? 'Connected' : 'Disconnected'}',
                    ),
                    selected: isHidConnected,
                    onSelected: (_) {
                      final notifier =
                          ref.read(bluetoothHidServiceProvider.notifier);
                      if (!isBluetoothEnabled) {
                        notifier.openBluetoothSettings();
                      } else if (!isHidConnected) {
                        notifier.registerApp();
                      } else {
                        notifier.disconnect();
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
                      isServiceRunning
                          ? Icons.security
                          : Icons.security_outlined,
                      color: isServiceRunning ? Colors.orange : null,
                      size: 18,
                    ),
                    label: Text(
                        'Service: ${isServiceRunning ? 'Active' : 'Idle'}'),
                    selected: isServiceRunning,
                    onSelected: (_) {
                      final manager =
                          ref.read(foregroundServiceStateProvider.notifier);
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

              // 2. Active Editor Context
              Text(
                'Active Editor Context',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              M3ExpressiveCard(
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
              const SizedBox(height: 24),

              // 3. Quick Connect Controls
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
              const SizedBox(height: 8),
              FilledButton.tonalIcon(
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text('Quick Connect with URL / QR Payload'),
                onPressed: () => _showQuickConnectDialog(context, ref),
              ),
              const SizedBox(height: 24),

              // 4. System Alerts & Warnings
              if (!isBluetoothEnabled) ...[
                Card(
                  color: theme.colorScheme.errorContainer,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.bluetooth_disabled,
                                color: theme.colorScheme.error, size: 28),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Bluetooth is Turned OFF',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: theme.colorScheme.onErrorContainer,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Bluetooth HID keyboard emulation requires Bluetooth to be enabled to send hardware keystrokes.',
                          style: TextStyle(
                              color: theme.colorScheme.onErrorContainer),
                        ),
                        const SizedBox(height: 12),
                        FilledButton.tonalIcon(
                          icon: const Icon(Icons.settings_bluetooth),
                          label: const Text('Open Bluetooth Settings'),
                          onPressed: () {
                            ref
                                .read(bluetoothHidServiceProvider.notifier)
                                .openBluetoothSettings();
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              if (!_isBatteryOptimizationIgnored) ...[
                Card(
                  color: theme.colorScheme.tertiaryContainer,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.battery_alert,
                                color: theme.colorScheme.onTertiaryContainer,
                                size: 28),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Background Battery Optimization',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: theme.colorScheme.onTertiaryContainer,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Android will freeze companion services when the screen locks. Allow running in background for uninterrupted connection.',
                          style: TextStyle(
                              color: theme.colorScheme.onTertiaryContainer),
                        ),
                        const SizedBox(height: 12),
                        FilledButton.tonal(
                          onPressed: () async {
                            await ref
                                .read(foregroundServiceStateProvider.notifier)
                                .requestIgnoreBatteryOptimizations();
                            _refreshDashboard();
                          },
                          child: const Text('Disable Battery Optimization'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              if (networkState.lastError != null && !isWsConnected) ...[
                Card(
                  color: theme.colorScheme.errorContainer,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.wifi_off,
                            color: theme.colorScheme.error, size: 24),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'WebSocket Connection Error',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  color: theme.colorScheme.onErrorContainer,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                networkState.lastError!,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onErrorContainer,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.refresh),
                          onPressed: () {
                            ref
                                .read(companionNetworkStateProvider.notifier)
                                .connectWithConfig(networkState.config);
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // 5. Bluetooth Paired Workstations Card
              Text(
                'Bluetooth Paired Workstations',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Card(
                elevation: 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.devices, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                'Paired Devices (${hidState.bondedDevices.length})',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          TextButton.icon(
                            icon: const Icon(Icons.refresh, size: 16),
                            label: const Text('Refresh'),
                            onPressed: () {
                              ref
                                  .read(bluetoothHidServiceProvider.notifier)
                                  .getBondedDevices();
                            },
                          ),
                        ],
                      ),
                      if (hidState.bondedDevices.isEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          _isLoadingDevices
                              ? 'Scanning for paired devices...'
                              : 'No paired Bluetooth devices found. Pair your computer with your phone in Bluetooth Settings first.',
                          style: theme.textTheme.bodySmall,
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.bluetooth_searching),
                          label: const Text('Open Bluetooth Settings to Pair'),
                          onPressed: () {
                            ref
                                .read(bluetoothHidServiceProvider.notifier)
                                .openBluetoothSettings();
                          },
                        ),
                      ] else ...[
                        const SizedBox(height: 8),
                        ...hidState.bondedDevices.map((device) {
                          final isTargetConnected = isHidConnected &&
                              hidState.connectedDeviceAddress == device.address;
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(
                              Icons.computer,
                              color: isTargetConnected
                                  ? Colors.blue
                                  : theme.colorScheme.onSurfaceVariant,
                            ),
                            title: Text(
                              device.name,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            subtitle: Text(device.address),
                            trailing: isTargetConnected
                                ? FilledButton.tonal(
                                    onPressed: () {
                                      ref
                                          .read(bluetoothHidServiceProvider
                                              .notifier)
                                          .disconnect();
                                    },
                                    child: const Text('Disconnect'),
                                  )
                                : ElevatedButton(
                                    onPressed: () {
                                      ref
                                          .read(bluetoothHidServiceProvider
                                              .notifier)
                                          .connect(device.address);
                                    },
                                    child: const Text('Connect'),
                                  ),
                          );
                        }),
                      ],
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

  void _showQuickConnectDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Quick Connect from VS Code'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Paste the WebSocket URL or QR Code text shown in VS Code:',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: 'ws://192.168.1.15:38848?token=XYZ',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              icon: const Icon(Icons.paste, size: 16),
              label: const Text('Paste from Clipboard'),
              onPressed: () async {
                final data = await Clipboard.getData(Clipboard.kTextPlain);
                if (data?.text != null) {
                  controller.text = data!.text!.trim();
                }
              },
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
              final parsed = CompanionConnectionConfig.parseUriOrJson(
                  controller.text.trim());
              if (parsed != null) {
                ref
                    .read(companionNetworkStateProvider.notifier)
                    .connectWithConfig(parsed);
                Navigator.pop(ctx);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Invalid WebSocket URL or QR format'),
                  ),
                );
              }
            },
            child: const Text('Connect'),
          ),
        ],
      ),
    );
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

class M3ExpressiveCard extends StatelessWidget {
  final Widget child;
  final Color? color;
  final EdgeInsetsGeometry padding;

  const M3ExpressiveCard({
    super.key,
    required this.child,
    this.color,
    this.padding = const EdgeInsets.all(16.0),
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 1,
      color: color ?? theme.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Padding(
        padding: padding,
        child: child,
      ),
    );
  }
}
