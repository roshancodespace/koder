import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// ignore: implementation_imports
import 'package:m3e_core/src/card/m3e_card.dart';
// ignore: implementation_imports
import 'package:m3e_core/src/progress_indicator/m3e_linear_progress_indicator.dart';
import '../../automation/models/humanization_config.dart';
import '../../automation/services/humanized_typer_service.dart';
import '../../automation/services/language_indentation_helper.dart';
import '../../bluetooth_hid/bluetooth_hid_service.dart';
import '../../bluetooth_hid/models/hid_state.dart';
import '../../network/models/connection_state.dart';
import '../../network/providers/websocket_provider.dart';
import '../../project/models/project_models.dart';
import '../../project/providers/project_provider.dart';

class _TreeNodeItem {
  final FileNodeEntity node;
  final int depth;
  final bool isExpanded;

  const _TreeNodeItem({
    required this.node,
    required this.depth,
    required this.isExpanded,
  });
}

class ProjectExplorerScreen extends ConsumerStatefulWidget {
  const ProjectExplorerScreen({super.key});

  @override
  ConsumerState<ProjectExplorerScreen> createState() =>
      _ProjectExplorerScreenState();
}

class _ProjectExplorerScreenState extends ConsumerState<ProjectExplorerScreen> {
  final TextEditingController _searchController = TextEditingController();
  HumanizationConfig _humanizationConfig = const HumanizationConfig();
  AutomationCheckpointEntity? _savedCheckpoint;
  String? _lastCheckedProjectId;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCheckpointForProject(String? projectId) async {
    if (projectId == null || projectId.isEmpty) {
      if (_savedCheckpoint != null) setState(() => _savedCheckpoint = null);
      _lastCheckedProjectId = null;
      return;
    }
    _lastCheckedProjectId = projectId;
    final cp = await ref
        .read(projectExplorerStateProvider.notifier)
        .getCheckpoint(projectId);
    if (mounted) {
      setState(() {
        _savedCheckpoint = cp;
      });
    }
  }

  List<_TreeNodeItem> _buildVisibleTree(
    List<FileNodeEntity> allNodes,
    Set<String> expandedIds,
  ) {
    final Map<String?, List<FileNodeEntity>> childrenByParent = {};
    for (final node in allNodes) {
      childrenByParent.putIfAbsent(node.parentId, () => []).add(node);
    }

    for (final list in childrenByParent.values) {
      list.sort((a, b) {
        if (a.isDirectory && !b.isDirectory) return -1;
        if (!a.isDirectory && b.isDirectory) return 1;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
    }

    final List<_TreeNodeItem> result = [];

    void traverse(String? parentId, int depth) {
      final children = childrenByParent[parentId] ?? [];
      for (final child in children) {
        final isExpanded = expandedIds.contains(child.id);
        result.add(_TreeNodeItem(
          node: child,
          depth: depth,
          isExpanded: isExpanded,
        ));
        if (child.isDirectory && isExpanded) {
          traverse(child.id, depth + 1);
        }
      }
    }

    traverse(null, 0);
    return result;
  }

  void _showImportSourceCodeSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        final theme = Theme.of(context);
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 16,
              top: 20,
              left: 20,
              right: 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.drive_folder_upload,
                        color: theme.colorScheme.primary, size: 28),
                    const SizedBox(width: 12),
                    Text(
                      'Import Source Code',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Import a project archive to auto-type files directly into VS Code:',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 20),
                M3ECardColumn(
                  color: theme.colorScheme.surfaceContainerLow,
                  children: [
                    // Option 1: Local ZIP
                    ListTile(
                      leading: CircleAvatar(
                        backgroundColor: theme.colorScheme.primaryContainer,
                        child: Icon(Icons.folder_zip,
                            color: theme.colorScheme.primary),
                      ),
                      title: const Text(
                        'Select ZIP Archive',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle:
                          const Text('Pick a .zip archive from your device'),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () async {
                        Navigator.pop(sheetContext);
                        final files = await FilePicker.pickFiles(
                          type: FileType.custom,
                          allowedExtensions: ['zip'],
                        );
                        if (files.isNotEmpty && files.first.path != null) {
                          final file = files.first;
                          final name = file.name.replaceAll('.zip', '');
                          ref
                              .read(projectExplorerStateProvider.notifier)
                              .importProjectFromZipFile(name, file.path!);
                        }
                      },
                    ),

                    // Option 2: Single Code File
                    ListTile(
                      leading: CircleAvatar(
                        backgroundColor: theme.colorScheme.secondaryContainer,
                        child: Icon(Icons.description,
                            color: theme.colorScheme.secondary),
                      ),
                      title: const Text(
                        'Select Single Code File',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: const Text(
                          'Import a standalone script, model, or source file'),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () async {
                        Navigator.pop(sheetContext);
                        final files = await FilePicker.pickFiles(
                          type: FileType.any,
                        );
                        if (files.isNotEmpty && files.first.path != null) {
                          final file = files.first;
                          final filePath = file.path!;
                          final fileName = file.name;
                          if (fileName.endsWith('.zip')) {
                            ref
                                .read(projectExplorerStateProvider.notifier)
                                .importProjectFromZipFile(
                                  fileName.replaceAll('.zip', ''),
                                  filePath,
                                );
                          } else {
                            final bytes = await File(filePath).readAsBytes();
                            ref
                                .read(projectExplorerStateProvider.notifier)
                                .importProjectFromSingleFile(
                                  fileName,
                                  bytes,
                                );
                          }
                        }
                      },
                    ),

                    // Option 3: Paste from Clipboard
                    ListTile(
                      leading: CircleAvatar(
                        backgroundColor: theme.colorScheme.tertiaryContainer,
                        child: Icon(Icons.content_paste,
                            color: theme.colorScheme.tertiary),
                      ),
                      title: const Text(
                        'Paste Code from Clipboard',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: const Text(
                          'Paste source code directly without creating a file'),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () {
                        Navigator.pop(sheetContext);
                        _showPasteCodeDialog(context);
                      },
                    ),

                    // Option 4: Remote ZIP URL
                    ListTile(
                      leading: CircleAvatar(
                        backgroundColor: theme.colorScheme.primaryContainer,
                        child:
                            Icon(Icons.link, color: theme.colorScheme.primary),
                      ),
                      title: const Text(
                        'Download from ZIP URL',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: const Text(
                          'Enter direct URL to a remote .zip archive'),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () {
                        Navigator.pop(sheetContext);
                        _showRemoteZipDialog(context);
                      },
                    ),

                    // Option 5: GitHub Repo
                    ListTile(
                      leading: CircleAvatar(
                        backgroundColor: theme.colorScheme.secondaryContainer,
                        child: Icon(Icons.code,
                            color: theme.colorScheme.secondary),
                      ),
                      title: const Text(
                        'Import from GitHub',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle:
                          const Text('Enter GitHub repo URL (e.g. owner/repo)'),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () {
                        Navigator.pop(sheetContext);
                        _showGitHubImportDialog(context);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showPasteCodeDialog(BuildContext context) {
    final nameController = TextEditingController(text: 'main.ts');
    final codeController = TextEditingController();

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Paste Code Directly'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'File Name',
                    hintText: 'e.g. index.ts, main.dart, script.py',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Text('Code Content:',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const Spacer(),
                    TextButton.icon(
                      icon: const Icon(Icons.paste, size: 16),
                      label: const Text('Paste Clipboard'),
                      onPressed: () async {
                        final data =
                            await Clipboard.getData(Clipboard.kTextPlain);
                        if (data?.text != null) {
                          codeController.text = data!.text!;
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: codeController,
                  maxLines: 8,
                  decoration: const InputDecoration(
                    hintText: 'Paste or type source code here...',
                    border: OutlineInputBorder(),
                  ),
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            icon: const Icon(Icons.check),
            label: const Text('Import Code'),
            onPressed: () {
              final fileName = nameController.text.trim();
              final code = codeController.text;
              if (fileName.isNotEmpty && code.isNotEmpty) {
                Navigator.pop(ctx);
                final projectName = fileName.split('.').first;
                ref
                    .read(projectExplorerStateProvider.notifier)
                    .importProjectFromPastedCode(projectName, fileName, code);
              }
            },
          ),
        ],
      ),
    );
  }

  void _showRemoteZipDialog(BuildContext context) {
    final nameController = TextEditingController();
    final urlController = TextEditingController();

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Import from ZIP URL'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Project Name',
                hintText: 'e.g. my-app',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: urlController,
              decoration: const InputDecoration(
                labelText: 'Direct ZIP URL',
                hintText: 'https://example.com/project.zip',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final name = nameController.text.trim();
              final urlStr = urlController.text.trim();
              final uri = Uri.tryParse(urlStr);
              if (name.isNotEmpty &&
                  uri != null &&
                  uri.scheme.startsWith('http')) {
                Navigator.pop(ctx);
                ref
                    .read(projectExplorerStateProvider.notifier)
                    .importProjectFromRemoteZipUrl(name, uri);
              }
            },
            child: const Text('Download & Import'),
          ),
        ],
      ),
    );
  }

  void _showGitHubImportDialog(BuildContext context) {
    final repoController = TextEditingController();
    final branchController = TextEditingController(text: 'main');

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Import from GitHub'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: repoController,
              decoration: const InputDecoration(
                labelText: 'GitHub Repository',
                hintText: 'owner/repo or https://github.com/owner/repo',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: branchController,
              decoration: const InputDecoration(
                labelText: 'Branch',
                hintText: 'main or master',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              var repoText = repoController.text.trim();
              if (repoText.startsWith('https://github.com/')) {
                repoText = repoText.replaceFirst('https://github.com/', '');
              }
              if (repoText.endsWith('.git')) {
                repoText = repoText.substring(0, repoText.length - 4);
              }
              final parts = repoText.split('/');
              if (parts.length >= 2) {
                final owner = parts[0].trim();
                final repo = parts[1].trim();
                final branch = branchController.text.trim().isNotEmpty
                    ? branchController.text.trim()
                    : 'main';
                Navigator.pop(ctx);
                ref
                    .read(projectExplorerStateProvider.notifier)
                    .importProjectFromGitHub(owner, repo, branch: branch);
              }
            },
            child: const Text('Import Repo'),
          ),
        ],
      ),
    );
  }

  void _showHumanizationSettings(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            final theme = Theme.of(context);
            return DraggableScrollableSheet(
              initialChildSize: 0.85,
              minChildSize: 0.5,
              maxChildSize: 0.95,
              expand: false,
              builder: (scrollCtx, scrollController) {
                return SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.outlineVariant,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          Icon(Icons.tune_rounded,
                              color: theme.colorScheme.primary),
                          const SizedBox(width: 10),
                          Text(
                            'Automation & Humanization Settings',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Configure natural typing speed, session timer, rest breaks, and syntax alignment:',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Section 1: Session Duration Timer
                      Text(
                        'Coding Session Duration',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: [
                          ChoiceChip(
                            label: const Text('Unlimited'),
                            selected:
                                _humanizationConfig.sessionDurationMinutes == 0,
                            onSelected: (sel) {
                              if (sel) {
                                setModalState(() {
                                  _humanizationConfig =
                                      _humanizationConfig.copyWith(
                                    sessionDurationMinutes: 0,
                                  );
                                });
                                setState(() {});
                              }
                            },
                          ),
                          ChoiceChip(
                            label: const Text('25 Mins'),
                            selected:
                                _humanizationConfig.sessionDurationMinutes ==
                                    25,
                            onSelected: (sel) {
                              if (sel) {
                                setModalState(() {
                                  _humanizationConfig =
                                      _humanizationConfig.copyWith(
                                    sessionDurationMinutes: 25,
                                  );
                                });
                                setState(() {});
                              }
                            },
                          ),
                          ChoiceChip(
                            label: const Text('45 Mins'),
                            selected:
                                _humanizationConfig.sessionDurationMinutes ==
                                    45,
                            onSelected: (sel) {
                              if (sel) {
                                setModalState(() {
                                  _humanizationConfig =
                                      _humanizationConfig.copyWith(
                                    sessionDurationMinutes: 45,
                                  );
                                });
                                setState(() {});
                              }
                            },
                          ),
                          ChoiceChip(
                            label: const Text('60 Mins'),
                            selected:
                                _humanizationConfig.sessionDurationMinutes ==
                                    60,
                            onSelected: (sel) {
                              if (sel) {
                                setModalState(() {
                                  _humanizationConfig =
                                      _humanizationConfig.copyWith(
                                    sessionDurationMinutes: 60,
                                  );
                                });
                                setState(() {});
                              }
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Section 2: Deep Work Breaks
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Periodic Deep Work Breaks'),
                        subtitle: const Text(
                          'Pauses automation periodically to rest hands and eyes like a human coder',
                        ),
                        value: _humanizationConfig.enableDeepWorkBreaks,
                        onChanged: (enabled) {
                          setModalState(() {
                            _humanizationConfig = _humanizationConfig.copyWith(
                              enableDeepWorkBreaks: enabled,
                            );
                          });
                          setState(() {});
                        },
                      ),
                      if (_humanizationConfig.enableDeepWorkBreaks) ...[
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          children: [
                            ChoiceChip(
                              label: const Text('Every 25m (5m break)'),
                              selected: _humanizationConfig
                                          .breakIntervalMinutes ==
                                      25 &&
                                  _humanizationConfig.breakDurationMinutes == 5,
                              onSelected: (sel) {
                                if (sel) {
                                  setModalState(() {
                                    _humanizationConfig =
                                        _humanizationConfig.copyWith(
                                      breakIntervalMinutes: 25,
                                      breakDurationMinutes: 5,
                                    );
                                  });
                                  setState(() {});
                                }
                              },
                            ),
                            ChoiceChip(
                              label: const Text('Every 45m (10m break)'),
                              selected: _humanizationConfig
                                          .breakIntervalMinutes ==
                                      45 &&
                                  _humanizationConfig.breakDurationMinutes ==
                                      10,
                              onSelected: (sel) {
                                if (sel) {
                                  setModalState(() {
                                    _humanizationConfig =
                                        _humanizationConfig.copyWith(
                                      breakIntervalMinutes: 45,
                                      breakDurationMinutes: 10,
                                    );
                                  });
                                  setState(() {});
                                }
                              },
                            ),
                            ChoiceChip(
                              label: const Text('Every 15m (3m break)'),
                              selected: _humanizationConfig
                                          .breakIntervalMinutes ==
                                      15 &&
                                  _humanizationConfig.breakDurationMinutes == 3,
                              onSelected: (sel) {
                                if (sel) {
                                  setModalState(() {
                                    _humanizationConfig =
                                        _humanizationConfig.copyWith(
                                      breakIntervalMinutes: 15,
                                      breakDurationMinutes: 3,
                                    );
                                  });
                                  setState(() {});
                                }
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                      ],

                      const Divider(height: 24),

                      // Section 3: Interactive VS Code Shortcuts Navigation
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Interactive Shortcut Navigation'),
                        subtitle: const Text(
                          'Uses Quick Open (Ctrl+P) and Companion shortcut (Ctrl+Alt+N) to open and create files interactively',
                        ),
                        value: _humanizationConfig.useShortcutsForNavigation,
                        onChanged: (enabled) {
                          setModalState(() {
                            _humanizationConfig = _humanizationConfig.copyWith(
                              useShortcutsForNavigation: enabled,
                            );
                          });
                          setState(() {});
                        },
                      ),
                      Row(
                        children: [
                          const Text('Workstation OS: ',
                              style: TextStyle(fontSize: 13)),
                          ChoiceChip(
                            label: const Text('Linux / Windows (Ctrl)'),
                            selected: !_humanizationConfig.isMac,
                            onSelected: (sel) {
                              if (sel) {
                                setModalState(() {
                                  _humanizationConfig = _humanizationConfig
                                      .copyWith(isMac: false);
                                });
                                setState(() {});
                              }
                            },
                          ),
                          const SizedBox(width: 8),
                          ChoiceChip(
                            label: const Text('macOS (Cmd)'),
                            selected: _humanizationConfig.isMac,
                            onSelected: (sel) {
                              if (sel) {
                                setModalState(() {
                                  _humanizationConfig =
                                      _humanizationConfig.copyWith(isMac: true);
                                });
                                setState(() {});
                              }
                            },
                          ),
                        ],
                      ),

                      const Divider(height: 24),

                      // Section 4: Language-Aware Syntax & Indentation Engine
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title:
                            const Text('Language-Aware Indentation & Dedent'),
                        subtitle: const Text(
                          'Aligns with Python block indentation, C-style braces, and dedents cleanly to eliminate staircase cascade',
                        ),
                        value: _humanizationConfig.autoIndentationAware,
                        onChanged: (enabled) {
                          setModalState(() {
                            _humanizationConfig = _humanizationConfig.copyWith(
                              autoIndentationAware: enabled,
                              autoBracketAware: enabled,
                            );
                          });
                          setState(() {});
                        },
                      ),

                      const Divider(height: 24),

                      // Section 5: Speed & Realistic Typos
                      Text(
                        'Typing Speed: ${_humanizationConfig.minWpm} - ${_humanizationConfig.maxWpm} WPM',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      RangeSlider(
                        values: RangeValues(
                          _humanizationConfig.minWpm.toDouble(),
                          _humanizationConfig.maxWpm.toDouble(),
                        ),
                        min: 15,
                        max: 95,
                        divisions: 16,
                        labels: RangeLabels(
                          '${_humanizationConfig.minWpm} WPM',
                          '${_humanizationConfig.maxWpm} WPM',
                        ),
                        onChanged: (vals) {
                          setModalState(() {
                            _humanizationConfig = _humanizationConfig.copyWith(
                              minWpm: vals.start.round(),
                              maxWpm: vals.end.round(),
                            );
                          });
                          setState(() {});
                        },
                      ),
                      const SizedBox(height: 8),

                      Text(
                        'Typo Simulation: ${_humanizationConfig.errorRatePercent.toStringAsFixed(1)}% '
                        '(${_humanizationConfig.errorRatePercent == 0 ? 'No Mistakes' : 'Mistypes adjacent key, pauses, backspaces & corrects'})',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Slider(
                        value: _humanizationConfig.errorRatePercent,
                        min: 0.0,
                        max: 8.0,
                        divisions: 16,
                        label:
                            '${_humanizationConfig.errorRatePercent.toStringAsFixed(1)}%',
                        onChanged: (val) {
                          setModalState(() {
                            _humanizationConfig = _humanizationConfig.copyWith(
                              errorRatePercent: val,
                            );
                          });
                          setState(() {});
                        },
                      ),

                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Natural Thinking Bursts'),
                        subtitle: const Text(
                          'Simulates human pauses at newlines, semicolons, and code block transitions',
                        ),
                        value: _humanizationConfig.enableThinkingPauses,
                        onChanged: (enabled) {
                          setModalState(() {
                            _humanizationConfig = _humanizationConfig.copyWith(
                              enableThinkingPauses: enabled,
                            );
                          });
                          setState(() {});
                        },
                      ),

                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: () => Navigator.pop(modalCtx),
                          child: const Text('Apply Settings'),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Future<void> _startAutomationWithWarning(
    BuildContext context, {
    AutomationCheckpointEntity? resumeCheckpoint,
  }) async {
    final hidState = ref.read(bluetoothHidServiceProvider);
    if (hidState.status != HidConnectionStatus.connected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.orange,
          content: Text(
            'Bluetooth HID is disconnected. Connect to your computer first before starting auto-type.',
          ),
        ),
      );
      return;
    }

    final filesToAutomate = await ref
        .read(projectExplorerStateProvider.notifier)
        .getIncludedFilesForAutomation();

    if (filesToAutomate.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'No files selected for automation. Check at least one file.'),
          ),
        );
      }
      return;
    }

    if (!context.mounted) return;

    final isResuming = resumeCheckpoint != null &&
        (resumeCheckpoint.currentFileIndex > 0 ||
            resumeCheckpoint.characterOffset > 0);

    final networkState = ref.read(companionNetworkStateProvider);
    final isWsConnected =
        networkState.status == CompanionConnectionStatus.connected;

    // MANDATORY FOCUS WARNING MODAL
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        icon: Icon(
          isWsConnected
              ? Icons.auto_awesome_rounded
              : Icons.warning_amber_rounded,
          size: 44,
          color: isWsConnected ? Colors.blue : Colors.amber,
        ),
        title: Text(isResuming
            ? 'Resume Auto-Typing in VS Code'
            : (isWsConnected ? 'Ready to Auto-Type' : 'Focus VS Code Editor')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isResuming
                  ? 'Resuming from File ${resumeCheckpoint.currentFileIndex + 1} (${resumeCheckpoint.activeFileName}) at char offset ${resumeCheckpoint.characterOffset}.\n\n'
                      'Make sure VS Code is active and focused on your screen.'
                  : (isWsConnected
                      ? 'VS Code Companion is connected over WebSocket!\n\n'
                          '1. Keep your VS Code window active and visible.\n'
                          '2. The companion will automatically open and prepare each file in VS Code.\n'
                          '3. Physical keyboard keystrokes will be typed smoothly at natural speed.'
                      : 'Before starting humanized auto-typing:\n\n'
                          '1. Open VS Code on your computer.\n'
                          '2. Open ${filesToAutomate.first.relativePath} and focus the editor.\n'
                          '3. The phone will begin sending physical keyboard keystrokes to your workstation.'),
              style: const TextStyle(fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isWsConnected
                    ? Colors.blue.withAlpha(25)
                    : Colors.amber.withAlpha(35),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isWsConnected
                      ? Colors.blue.withAlpha(60)
                      : Colors.amber.withAlpha(70),
                ),
              ),
              child: Text(
                'Will type ${filesToAutomate.length} files (${_humanizationConfig.minWpm}-${_humanizationConfig.maxWpm} WPM, ${_humanizationConfig.errorRatePercent.toStringAsFixed(1)}% typos)${isWsConnected ? ' with auto-file opening' : ''}.',
                style:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            icon: const Icon(Icons.play_arrow),
            label: Text(isResuming
                ? 'VS Code is Focused — Resume Typing'
                : 'VS Code is Focused — Start Typing'),
            onPressed: () {
              Navigator.pop(ctx);
              _showActiveAutomationModal(
                context,
                filesToAutomate,
                resumeCheckpoint: resumeCheckpoint,
              );
            },
          ),
        ],
      ),
    );
  }

  void _showActiveAutomationModal(
    BuildContext context,
    List<FileToType> filesToAutomate, {
    AutomationCheckpointEntity? resumeCheckpoint,
  }) {
    final state = ref.read(projectExplorerStateProvider);
    final projectId = state.activeProject?.id ?? '';
    final resumeFileIndex = resumeCheckpoint?.currentFileIndex ?? 0;
    final resumeCharOffset = resumeCheckpoint?.characterOffset ?? 0;

    ref.read(humanizedTyperProvider.notifier).startAutomation(
          projectId,
          filesToAutomate,
          config: _humanizationConfig,
          resumeFileIndex: resumeFileIndex,
          resumeCharOffset: resumeCharOffset,
        );

    showModalBottomSheet<void>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return Consumer(
          builder: (modalCtx, modalRef, child) {
            final progress = modalRef.watch(humanizedTyperProvider);
            final typerNotifier =
                modalRef.read(humanizedTyperProvider.notifier);
            final theme = Theme.of(modalCtx);

            final isPaused = progress.status == AutomationStatus.paused;
            final isCompleted = progress.status == AutomationStatus.completed;
            final isResting = progress.status == AutomationStatus.resting;
            final isNavigating = progress.status == AutomationStatus.navigating;

            final percent = progress.totalCharacters > 0
                ? (progress.charactersTyped / progress.totalCharacters)
                    .clamp(0.0, 1.0)
                : 0.0;

            final elapsedMin = (progress.sessionElapsedSeconds ~/ 60)
                .toString()
                .padLeft(2, '0');
            final elapsedSec = (progress.sessionElapsedSeconds % 60)
                .toString()
                .padLeft(2, '0');

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 14),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.outlineVariant,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              isCompleted
                                  ? Icons.check_circle_rounded
                                  : (isResting
                                      ? Icons.coffee_rounded
                                      : (isPaused
                                          ? Icons.pause_circle_outline_rounded
                                          : (isNavigating
                                              ? Icons.explore_rounded
                                              : Icons.keyboard_rounded))),
                              color: isCompleted
                                  ? Colors.green
                                  : (isResting
                                      ? Colors.amber.shade800
                                      : (isPaused
                                          ? Colors.orange
                                          : theme.colorScheme.primary)),
                              size: 26,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              isCompleted
                                  ? 'Automation Completed!'
                                  : (isResting
                                      ? 'Deep Work Rest Break'
                                      : (isPaused
                                          ? 'Automation Paused'
                                          : (isNavigating
                                              ? 'Navigating in VS Code...'
                                              : 'Auto-Typing in Progress...'))),
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        if (isCompleted)
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () {
                              Navigator.pop(modalCtx);
                              _loadCheckpointForProject(projectId);
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Deep Work Break Alert Card
                    if (isResting) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        margin: const EdgeInsets.only(bottom: 14),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.tertiaryContainer,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.self_improvement_rounded,
                                size: 28,
                                color: theme.colorScheme.onTertiaryContainer),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Resting hands & eyes',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color:
                                          theme.colorScheme.onTertiaryContainer,
                                    ),
                                  ),
                                  Text(
                                    'Resumes in ${(progress.breakRemainingSeconds ~/ 60).toString().padLeft(2, '0')}:${(progress.breakRemainingSeconds % 60).toString().padLeft(2, '0')}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: theme
                                          .colorScheme.onTertiaryContainer
                                          .withAlpha(210),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            FilledButton.tonal(
                              style: FilledButton.styleFrom(
                                backgroundColor: theme.colorScheme.surface,
                                foregroundColor: theme.colorScheme.onSurface,
                              ),
                              onPressed: typerNotifier.skipBreak,
                              child: const Text('Skip Break',
                                  style: TextStyle(fontSize: 12)),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // Navigation Banner
                    if (isNavigating) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.secondaryContainer
                              .withAlpha(160),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                progress.statusMessage.isNotEmpty
                                    ? progress.statusMessage
                                    : 'Navigating to file...',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: theme.colorScheme.onSecondaryContainer,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // Material 3 Expressive Progress Indicator
                    M3ELinearProgressIndicator(
                      value: percent,
                      minHeight: 8,
                      color: isResting
                          ? Colors.amber.shade700
                          : theme.colorScheme.primary,
                      backgroundColor:
                          theme.colorScheme.surfaceContainerHighest,
                      strokeCap: StrokeCap.round,
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'File ${progress.currentFileIndex + 1} of ${progress.totalFiles}',
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                        Text(
                          '${(percent * 100).toStringAsFixed(1)}% (${progress.charactersTyped}/${progress.totalCharacters} chars)',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Active: ${progress.activeFileName}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ),
                        if (progress.activeFileName.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              LanguageIndentationHelper.getLanguageDisplayName(
                                LanguageIndentationHelper.detectLanguage(
                                    progress.activeFileName),
                              ).split(' ').first,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onPrimaryContainer,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Live Stats Card
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Column(
                            children: [
                              Text('${progress.currentWpm} WPM',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15)),
                              const Text('Typing Speed',
                                  style: TextStyle(fontSize: 11)),
                            ],
                          ),
                          Container(
                              height: 26,
                              width: 1,
                              color: theme.colorScheme.outlineVariant),
                          Column(
                            children: [
                              Text('$elapsedMin:$elapsedSec',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                      color: Colors.blue)),
                              const Text('Session Time',
                                  style: TextStyle(fontSize: 11)),
                            ],
                          ),
                          Container(
                              height: 26,
                              width: 1,
                              color: theme.colorScheme.outlineVariant),
                          Column(
                            children: [
                              Text('${progress.typosCorrected}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                      color: Colors.orange)),
                              const Text('Typos Fixed',
                                  style: TextStyle(fontSize: 11)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Control Buttons
                    Row(
                      children: [
                        if (!isCompleted) ...[
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: Icon(
                                  isPaused ? Icons.play_arrow : Icons.pause),
                              label: Text(isPaused ? 'Resume' : 'Pause'),
                              onPressed: () {
                                if (isPaused) {
                                  typerNotifier.resume();
                                } else {
                                  typerNotifier.pause();
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.skip_next),
                              label: const Text('Skip File'),
                              onPressed: () => typerNotifier.skipCurrentFile(),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: FilledButton.tonalIcon(
                              style: FilledButton.styleFrom(
                                backgroundColor: Colors.red.shade100,
                                foregroundColor: Colors.red.shade900,
                              ),
                              icon: const Icon(Icons.stop),
                              label: const Text('Stop'),
                              onPressed: () {
                                typerNotifier.cancel();
                                Navigator.pop(modalCtx);
                              },
                            ),
                          ),
                        ] else ...[
                          Expanded(
                            child: FilledButton(
                              onPressed: () => Navigator.pop(modalCtx),
                              child: const Text('Done'),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _confirmDelete(BuildContext context, ProjectEntity project) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete Project'),
          content: Text('Delete "${project.name}" and all file records?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () {
                Navigator.of(dialogContext).pop();
                ref
                    .read(projectExplorerStateProvider.notifier)
                    .deleteProject(project.id);
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = ref.watch(projectExplorerStateProvider);
    final notifier = ref.read(projectExplorerStateProvider.notifier);

    final activeId = state.activeProject?.id;
    if (activeId != _lastCheckedProjectId) {
      _lastCheckedProjectId = activeId;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadCheckpointForProject(activeId);
      });
    }

    final visibleNodes =
        _buildVisibleTree(state.visibleNodes, state.expandedNodeIds);
    final totalFilesCount = state.nodes.where((n) => !n.isDirectory).length;
    final includedFilesCount =
        state.nodes.where((n) => !n.isDirectory && !n.isExcluded).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Project Explorer'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.tune),
            tooltip: 'Humanized Typer Settings',
            onPressed: () => _showHumanizationSettings(context),
          ),
          if (state.activeProject != null)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Delete Project',
              onPressed: () => _confirmDelete(context, state.activeProject!),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (state.isLoading) const LinearProgressIndicator(),
            if (state.errorMessage != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8.0),
                color: theme.colorScheme.errorContainer,
                child: Text(
                  state.errorMessage!,
                  style: TextStyle(
                    color: theme.colorScheme.onErrorContainer,
                    fontSize: 12,
                  ),
                ),
              ),

            // Top Action Bar & Project Selector
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Column(
                children: [
                  Row(
                    children: [
                      if (state.projects.isNotEmpty) ...[
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: state.activeProject?.id,
                            isExpanded: true,
                            items: state.projects
                                .map((p) => DropdownMenuItem(
                                      value: p.id,
                                      child: Text(p.name,
                                          overflow: TextOverflow.ellipsis),
                                    ))
                                .toList(),
                            onChanged: (id) {
                              if (id != null) {
                                notifier.selectProject(id);
                              }
                            },
                            decoration: const InputDecoration(
                              labelText: 'Active Project',
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      FilledButton.icon(
                        icon: const Icon(Icons.add),
                        label: const Text('Import Code'),
                        onPressed: () => _showImportSourceCodeSheet(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Search box
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search files in project...',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      suffixIcon: state.searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                notifier.setSearchQuery('');
                              },
                            )
                          : null,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (val) => notifier.setSearchQuery(val),
                  ),
                  if (state.activeProject != null) ...[
                    const SizedBox(height: 8),
                    // Batch Exclusion Chips
                    Row(
                      children: [
                        Text(
                          '$includedFilesCount / $totalFilesCount included',
                          style: theme.textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        InkWell(
                          onTap: () => notifier.selectAllNodes(false),
                          child: const Text('All',
                              style:
                                  TextStyle(color: Colors.blue, fontSize: 12)),
                        ),
                        const SizedBox(width: 12),
                        InkWell(
                          onTap: () => notifier.selectAllNodes(true),
                          child: const Text('None',
                              style:
                                  TextStyle(color: Colors.blue, fontSize: 12)),
                        ),
                        const SizedBox(width: 12),
                        InkWell(
                          onTap: () => notifier.excludeCommonPatterns(),
                          child: const Text('Exclude Common',
                              style: TextStyle(
                                  color: Colors.orange,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ],
                  if (state.activeProject != null &&
                      _savedCheckpoint != null &&
                      (_savedCheckpoint!.currentFileIndex > 0 ||
                          _savedCheckpoint!.characterOffset > 0)) ...[
                    const SizedBox(height: 8),
                    Card(
                      color: theme.colorScheme.tertiaryContainer,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        child: Row(
                          children: [
                            Icon(Icons.history_toggle_off,
                                color: theme.colorScheme.onTertiaryContainer),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Saved Automation Progress',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color:
                                          theme.colorScheme.onTertiaryContainer,
                                      fontSize: 12,
                                    ),
                                  ),
                                  Text(
                                    'File ${_savedCheckpoint!.currentFileIndex + 1} (${_savedCheckpoint!.activeFileName}) - offset ${_savedCheckpoint!.characterOffset}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: theme
                                          .colorScheme.onTertiaryContainer
                                          .withAlpha(200),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            FilledButton.tonal(
                              onPressed: () => _startAutomationWithWarning(
                                context,
                                resumeCheckpoint: _savedCheckpoint,
                              ),
                              child: const Text('Resume',
                                  style: TextStyle(fontSize: 12)),
                            ),
                            const SizedBox(width: 4),
                            IconButton(
                              icon: const Icon(Icons.close, size: 16),
                              tooltip: 'Discard Checkpoint',
                              onPressed: () async {
                                await notifier
                                    .clearCheckpoint(state.activeProject!.id);
                                setState(() {
                                  _savedCheckpoint = null;
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Divider(height: 1),

            // Main Explorer Tree / Empty State
            Expanded(
              child: state.projects.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.drive_folder_upload,
                              size: 72,
                              color: theme.colorScheme.primary.withAlpha(150),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No projects imported yet',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Import a ZIP archive or GitHub repository to auto-type files directly into VS Code.',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 13),
                            ),
                            const SizedBox(height: 20),
                            FilledButton.icon(
                              icon: const Icon(Icons.add),
                              label: const Text('Import Source Code'),
                              onPressed: () =>
                                  _showImportSourceCodeSheet(context),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: visibleNodes.length,
                      itemBuilder: (context, index) {
                        final item = visibleNodes[index];
                        final node = item.node;
                        final indent = item.depth * 20.0;

                        return Container(
                          padding: EdgeInsets.only(left: 8.0 + indent),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                color: theme.colorScheme.outlineVariant
                                    .withAlpha(50),
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              if (node.isDirectory)
                                IconButton(
                                  icon: Icon(
                                    item.isExpanded
                                        ? Icons.expand_more
                                        : Icons.chevron_right,
                                    size: 20,
                                  ),
                                  onPressed: () =>
                                      notifier.toggleNodeExpansion(node.id),
                                )
                              else
                                const SizedBox(width: 40),
                              Icon(
                                node.isDirectory
                                    ? (item.isExpanded
                                        ? Icons.folder_open
                                        : Icons.folder)
                                    : Icons.insert_drive_file_outlined,
                                color: node.isExcluded
                                    ? theme.colorScheme.outline
                                    : (node.isDirectory
                                        ? Colors.amber.shade700
                                        : theme.colorScheme.primary),
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  node.name,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: node.isExcluded
                                        ? theme.colorScheme.outline
                                        : theme.colorScheme.onSurface,
                                    decoration: node.isExcluded
                                        ? TextDecoration.lineThrough
                                        : TextDecoration.none,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Checkbox(
                                value: !node.isExcluded,
                                onChanged: (val) {
                                  notifier.toggleNodeExclusion(node.id);
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),

            // Bottom Automation Action Bar
            if (state.activeProject != null && state.nodes.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(20),
                      blurRadius: 8,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    OutlinedButton.icon(
                      icon: const Icon(Icons.tune, size: 18),
                      label: const Text('Typer Settings'),
                      onPressed: () => _showHumanizationSettings(context),
                    ),
                    const SizedBox(width: 12),
                    if (_savedCheckpoint != null &&
                        (_savedCheckpoint!.currentFileIndex > 0 ||
                            _savedCheckpoint!.characterOffset > 0)) ...[
                      Expanded(
                        child: FilledButton.icon(
                          icon: const Icon(Icons.play_arrow),
                          label: Text(
                              'Resume (${_savedCheckpoint!.currentFileIndex + 1}/$includedFilesCount)'),
                          onPressed: () => _startAutomationWithWarning(
                            context,
                            resumeCheckpoint: _savedCheckpoint,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      IconButton.filledTonal(
                        icon: const Icon(Icons.refresh, size: 20),
                        tooltip: 'Start from beginning',
                        onPressed: () => _startAutomationWithWarning(context),
                      ),
                    ] else ...[
                      Expanded(
                        child: FilledButton.icon(
                          icon: const Icon(Icons.play_arrow),
                          label: Text('Auto-Type ($includedFilesCount Files)'),
                          onPressed: () => _startAutomationWithWarning(context),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
