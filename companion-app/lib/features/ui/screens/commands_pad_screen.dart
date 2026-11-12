import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../bluetooth_hid/bluetooth_hid_service.dart';

class CommandAction {
  final String title;
  final String shortcutLabel;
  final IconData icon;
  final int modifier;
  final int keyCode;
  final Color color;

  const CommandAction({
    required this.title,
    required this.shortcutLabel,
    required this.icon,
    required this.modifier,
    required this.keyCode,
    required this.color,
  });
}

class CommandsPadScreen extends ConsumerWidget {
  const CommandsPadScreen({super.key});

  static const List<CommandAction> actions = [
    CommandAction(
      title: 'Create File',
      shortcutLabel: 'Ctrl + Alt + N',
      icon: Icons.note_add,
      modifier: 0x05, // Ctrl + Alt
      keyCode: 0x11, // 'N'
      color: Colors.blueAccent,
    ),
    CommandAction(
      title: 'Save Document',
      shortcutLabel: 'Ctrl + S',
      icon: Icons.save,
      modifier: 0x01, // Ctrl
      keyCode: 0x16, // 'S'
      color: Colors.teal,
    ),
    CommandAction(
      title: 'Format Code',
      shortcutLabel: 'Shift + Alt + F',
      icon: Icons.format_align_left,
      modifier: 0x06, // Shift + Alt
      keyCode: 0x09, // 'F'
      color: Colors.purpleAccent,
    ),
    CommandAction(
      title: 'Command Palette',
      shortcutLabel: 'Ctrl + Shift + P',
      icon: Icons.terminal,
      modifier: 0x03, // Ctrl + Shift
      keyCode: 0x13, // 'P'
      color: Colors.deepOrangeAccent,
    ),
    CommandAction(
      title: 'Quick Open',
      shortcutLabel: 'Ctrl + P',
      icon: Icons.search,
      modifier: 0x01, // Ctrl
      keyCode: 0x13, // 'P'
      color: Colors.indigoAccent,
    ),
    CommandAction(
      title: 'Find in Files',
      shortcutLabel: 'Ctrl + Shift + F',
      icon: Icons.manage_search,
      modifier: 0x03, // Ctrl + Shift
      keyCode: 0x09, // 'F'
      color: Colors.pinkAccent,
    ),
    CommandAction(
      title: 'Toggle Terminal',
      shortcutLabel: 'Ctrl + `',
      icon: Icons.code,
      modifier: 0x01, // Ctrl
      keyCode: 0x35, // Grave Accent
      color: Colors.green,
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Commands Pad'),
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Bluetooth HID Shortcuts',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Tap an action to send low-latency keystrokes to your workstation.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.3,
                  ),
                  itemCount: actions.length,
                  itemBuilder: (context, index) {
                    final action = actions[index];
                    return _CommandCard(
                      action: action,
                      onTap: () async {
                        final hid =
                            ref.read(bluetoothHidServiceProvider.notifier);
                        final success = await hid.sendShortcut(
                            action.modifier, action.keyCode);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).hideCurrentSnackBar();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                success
                                    ? 'Sent ${action.title} (${action.shortcutLabel})'
                                    : 'Failed to send ${action.title} - check Bluetooth HID status',
                              ),
                              duration: const Duration(seconds: 1),
                            ),
                          );
                        }
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CommandCard extends StatelessWidget {
  final CommandAction action;
  final VoidCallback onTap;

  const _CommandCard({
    required this.action,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              CircleAvatar(
                backgroundColor: action.color.withAlpha(40),
                foregroundColor: action.color,
                radius: 18,
                child: Icon(action.icon, size: 20),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    action.title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    action.shortcutLabel,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
