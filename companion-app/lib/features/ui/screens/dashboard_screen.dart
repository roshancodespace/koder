import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../bluetooth_hid/bluetooth_hid_service.dart';
import '../../bluetooth_hid/models/hid_state.dart';
import '../../foreground_service/foreground_service_manager.dart';
import '../../network/models/connection_state.dart';
import '../../network/providers/websocket_provider.dart';
import '../../network/screens/qr_scanner_screen.dart';
import '../../updater/update_checker_service.dart';

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
    ref.read(updateCheckerProvider.notifier).checkForUpdates();

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

    final updateState = ref.watch(updateCheckerProvider);
    final updateInfo = updateState.valueOrNull;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.system_update_alt),
            tooltip: 'Check for Updates',
            onPressed: () async {
              final info = await ref
                  .read(updateCheckerProvider.notifier)
                  .checkForUpdates();
              if (!info.hasUpdate && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Koder is up to date! (v0.2.0)'),
                  ),
                );
              }
            },
          ),
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
              // In-App Update Banner
              if (updateInfo != null && updateInfo.hasUpdate) ...[
                Card(
                  color: Colors.green.shade900,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        const Icon(Icons.system_update,
                            color: Colors.white, size: 28),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Update Available: v${updateInfo.latestVersion}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Current: v${updateInfo.currentVersion} • Tap to view & install',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        FilledButton.tonal(
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xFF0D3315),
                          ),
                          onPressed: () =>
                              _showUpdateDialog(context, updateInfo),
                          child: const Text('Update'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
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
                label: const Text('Scan QR Code with Camera'),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const QrScannerScreen(),
                    ),
                  );
                },
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

              // 4b. Bluetooth Connection Error / Instruction Alert (M3 Expressive)
              if (hidState.lastError != null) ...[
                AnimatedSize(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOut,
                  child: Card(
                    elevation: 0,
                    color: theme.colorScheme.surfaceContainerHigh,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(
                        color: theme.colorScheme.error.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.error
                                      .withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  Icons.bluetooth_searching_rounded,
                                  color: theme.colorScheme.error,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Bluetooth Pairing Notice',
                                      style: theme.textTheme.titleSmall
                                          ?.copyWith(
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.1,
                                      ),
                                    ),
                                    Text(
                                      'Host connection required',
                                      style: theme.textTheme.labelSmall
                                          ?.copyWith(
                                        color: theme
                                            .colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close_rounded, size: 20),
                                tooltip: 'Dismiss',
                                visualDensity: VisualDensity.compact,
                                onPressed: () => ref
                                    .read(
                                        bluetoothHidServiceProvider.notifier)
                                    .clearError(),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _formatHidErrorMessage(
                              hidState.lastError!,
                              hidState.activeSpoof.deviceName,
                            ),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              height: 1.35,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              FilledButton.tonalIcon(
                                icon: const Icon(Icons.sensors_rounded,
                                    size: 18),
                                label: Text(
                                  'Expose as ${hidState.activeSpoof.deviceName}',
                                ),
                                onPressed: () => _exposeDevice(
                                  context,
                                  ref,
                                  hidState.activeSpoof,
                                ),
                              ),
                              OutlinedButton.icon(
                                icon: const Icon(
                                    Icons.settings_bluetooth_rounded,
                                    size: 18),
                                label: const Text('Open Settings'),
                                onPressed: () => ref
                                    .read(
                                        bluetoothHidServiceProvider.notifier)
                                    .openBluetoothSettings(),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // 5. Keyboard Hardware Spoofer & Expose Card
              Text(
                'Keyboard Hardware Spoofer & Expose',
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
                        children: [
                          Icon(Icons.keyboard,
                              color: theme.colorScheme.primary, size: 24),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Spoofed as: ${hidState.activeSpoof.displayName}',
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  'Advertised: "${hidState.activeSpoof.deviceName}" (${hidState.activeSpoof.provider})',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.tune, size: 18),
                              label: const Text('Change Spoofer'),
                              onPressed: () => _showSpooferDialog(
                                context,
                                ref,
                                hidState.activeSpoof,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: FilledButton.icon(
                              icon: const Icon(Icons.sensors, size: 18),
                              label: const Text('Expose Device'),
                              onPressed: () => _exposeDevice(
                                context,
                                ref,
                                hidState.activeSpoof,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // 6. Bluetooth Paired Workstations Card
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
                          final isConnecting = hidState.status ==
                                  HidConnectionStatus.connecting &&
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
                            trailing: isConnecting
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : (isTargetConnected
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
                                        onPressed: () async {
                                          final success = await ref
                                              .read(bluetoothHidServiceProvider
                                                  .notifier)
                                              .connect(device.address);
                                          if (!success && context.mounted) {
                                            _showConnectTroubleshootingDialog(
                                              context,
                                              ref,
                                              device,
                                              hidState.activeSpoof,
                                            );
                                          }
                                        },
                                        child: const Text('Connect'),
                                      )),
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

  void _showUpdateDialog(BuildContext context, UpdateInfo updateInfo) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.system_update, size: 36, color: Colors.green),
        title: Text('New Version v${updateInfo.latestVersion} Available'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Current version: v${updateInfo.currentVersion}\nLatest version: v${updateInfo.latestVersion}',
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 12),
              const Text(
                'Release Notes:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 4),
              Text(
                updateInfo.releaseNotes.isNotEmpty
                    ? updateInfo.releaseNotes
                    : 'Bug fixes and performance improvements.',
                style: const TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 16),
              if (updateInfo.downloadUrl.isNotEmpty) ...[
                const Text(
                  'Download Link:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 4),
                SelectableText(
                  updateInfo.downloadUrl,
                  style: const TextStyle(fontSize: 11, color: Colors.blue),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Dismiss'),
          ),
          if (updateInfo.downloadUrl.isNotEmpty)
            FilledButton.icon(
              icon: const Icon(Icons.download),
              label: const Text('Download APK'),
              onPressed: () async {
                Navigator.pop(ctx);
                final uri = Uri.parse(updateInfo.downloadUrl);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    duration: const Duration(seconds: 8),
                    content: Text('Downloading update from ${uri.host}...'),
                    action: SnackBarAction(
                      label: 'Copy URL',
                      onPressed: () {
                        Clipboard.setData(
                            ClipboardData(text: updateInfo.downloadUrl));
                      },
                    ),
                  ),
                );
              },
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

  void _showSpooferDialog(
    BuildContext context,
    WidgetRef ref,
    KeyboardSpoofPreset currentPreset,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final theme = Theme.of(context);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.keyboard, size: 24),
                    const SizedBox(width: 12),
                    Text(
                      'Choose Spoofed Keyboard',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Select which physical hardware keyboard this device advertises as over Bluetooth:',
                  style: TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 16),
                ...KeyboardSpoofPreset.presets.map((preset) {
                  final isSelected = preset.id == currentPreset.id;
                  return Card(
                    elevation: isSelected ? 2 : 0,
                    color: isSelected
                        ? theme.colorScheme.primaryContainer
                        : theme.colorScheme.surfaceContainerLow,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: isSelected
                          ? BorderSide(
                              color: theme.colorScheme.primary,
                              width: 1.5,
                            )
                          : BorderSide.none,
                    ),
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: Icon(
                        isSelected
                            ? Icons.check_circle
                            : Icons.keyboard_outlined,
                        color: isSelected ? theme.colorScheme.primary : null,
                      ),
                      title: Text(
                        preset.displayName,
                        style: TextStyle(
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        'Advertised: ${preset.deviceName} (${preset.provider})',
                        style: const TextStyle(fontSize: 12),
                      ),
                      trailing: isSelected
                          ? const Chip(
                              label: Text('Active',
                                  style: TextStyle(fontSize: 11)),
                              visualDensity: VisualDensity.compact,
                            )
                          : null,
                      onTap: () {
                        ref
                            .read(bluetoothHidServiceProvider.notifier)
                            .setSpoofPreset(preset);
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Hardware identity updated to ${preset.deviceName}',
                            ),
                          ),
                        );
                      },
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showConnectTroubleshootingDialog(
    BuildContext context,
    WidgetRef ref,
    BluetoothDeviceInfo device,
    KeyboardSpoofPreset activeSpoof,
  ) {
    final theme = Theme.of(context);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.bluetooth_searching,
            size: 36, color: Colors.orange),
        title: Text('Could Not Connect to ${device.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Computers (Windows, Mac, Linux) manage Bluetooth keyboard connections as the host. If direct connection from the phone was rejected:',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            Text(
              'Options:\n1. If already paired: Open your computer\'s Bluetooth Settings and click "Connect" on "${activeSpoof.deviceName}".\n2. If not paired or re-pairing: Tap "Expose Phone" below and pair with "${activeSpoof.deviceName}".',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Dismiss'),
          ),
          FilledButton.icon(
            icon: const Icon(Icons.sensors),
            label: Text('Expose as ${activeSpoof.deviceName}'),
            onPressed: () {
              Navigator.pop(ctx);
              _exposeDevice(context, ref, activeSpoof);
            },
          ),
        ],
      ),
    );
  }

  String _formatHidErrorMessage(String error, String deviceName) {
    if (error.contains('rejected') || error.contains('did not accept')) {
      return 'Keyboards are host-initiated. If connecting from the phone was rejected, connect to "$deviceName" from your computer\'s Bluetooth settings, or tap Expose below.';
    }
    return error;
  }

  void _exposeDevice(
    BuildContext context,
    WidgetRef ref,
    KeyboardSpoofPreset activeSpoof,
  ) {
    ref
        .read(bluetoothHidServiceProvider.notifier)
        .makeDiscoverable(durationSeconds: 300);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 6),
        content: Text(
          'Phone is discoverable as "${activeSpoof.deviceName}" for 5 minutes. In PC Bluetooth Settings, connect to "${activeSpoof.deviceName}".',
        ),
        action: SnackBarAction(
          label: 'OK',
          onPressed: () {},
        ),
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
