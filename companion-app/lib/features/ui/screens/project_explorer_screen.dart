import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// ignore: implementation_imports
import 'package:m3e_core/src/card/m3e_card.dart';
import '../../automation/models/humanization_config.dart';
import '../../automation/services/humanized_typer_service.dart';
import '../../bluetooth_hid/bluetooth_hid_service.dart';
import '../../bluetooth_hid/models/hid_state.dart';
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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
                        'Select Local ZIP File',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: const Text('Pick a .zip archive from your device'),
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

                    // Option 2: Remote ZIP URL
                    ListTile(
                      leading: CircleAvatar(
                        backgroundColor: theme.colorScheme.secondaryContainer,
                        child: Icon(Icons.link,
                            color: theme.colorScheme.secondary),
                      ),
                      title: const Text(
                        'Download from ZIP URL',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: const Text('Enter direct URL to a remote .zip archive'),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () {
                        Navigator.pop(sheetContext);
                        _showRemoteZipDialog(context);
                      },
                    ),

                    // Option 3: GitHub Repo
                    ListTile(
                      leading: CircleAvatar(
                        backgroundColor: theme.colorScheme.tertiaryContainer,
                        child: Icon(Icons.code,
                            color: theme.colorScheme.tertiary),
                      ),
                      title: const Text(
                        'Import from GitHub',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: const Text('Enter GitHub repo URL (e.g. owner/repo)'),
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
              if (name.isNotEmpty && uri != null && uri.scheme.startsWith('http')) {
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
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.tune, color: theme.colorScheme.primary),
                        const SizedBox(width: 10),
                        Text(
                          'Humanized Typer Settings',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Configure typing speed variations and realistic typo corrections:',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // WPM Speed Range
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
                      max: 90,
                      divisions: 15,
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
                    const SizedBox(height: 12),

                    // Typo Simulation Rate
                    Text(
                      'Typo Frequency: ${_humanizationConfig.errorRatePercent.toStringAsFixed(1)}% '
                      '(${_humanizationConfig.errorRatePercent == 0 ? 'No Mistakes' : 'Mistypes key, pauses, backspaces & fixes'})',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Slider(
                      value: _humanizationConfig.errorRatePercent,
                      min: 0.0,
                      max: 10.0,
                      divisions: 20,
                      label: '${_humanizationConfig.errorRatePercent.toStringAsFixed(1)}%',
                      onChanged: (val) {
                        setModalState(() {
                          _humanizationConfig = _humanizationConfig.copyWith(
                            errorRatePercent: val,
                          );
                        });
                        setState(() {});
                      },
                    ),
                    const SizedBox(height: 12),

                    // Thinking Pauses
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Natural Thinking Pauses'),
                      subtitle: const Text(
                        'Brief pauses after newlines, semicolons, and code blocks',
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
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () => Navigator.pop(modalCtx),
                        child: const Text('Apply Settings'),
                      ),
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

  Future<void> _startAutomationWithWarning(BuildContext context) async {
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
            content: Text('No files selected for automation. Check at least one file.'),
          ),
        );
      }
      return;
    }

    if (!context.mounted) return;

    // MANDATORY FOCUS WARNING MODAL
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.warning_amber_rounded, size: 48, color: Colors.amber),
        title: const Text('Focus VS Code First!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Before starting humanized auto-typing:\n\n'
              '1. Open VS Code on your computer.\n'
              '2. Make sure the correct workspace folder is open.\n'
              '3. Click inside the VS Code window so it is active and focused.\n\n'
              'The phone will begin sending physical keyboard keystrokes to your workstation.',
              style: TextStyle(fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.amber.withAlpha(40),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Will type ${filesToAutomate.length} files with ${_humanizationConfig.minWpm}-${_humanizationConfig.maxWpm} WPM and ${_humanizationConfig.errorRatePercent.toStringAsFixed(1)}% typos.',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
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
            label: const Text('VS Code is Focused — Start Typing'),
            onPressed: () {
              Navigator.pop(ctx);
              _showActiveAutomationModal(context, filesToAutomate);
            },
          ),
        ],
      ),
    );
  }

  void _showActiveAutomationModal(
    BuildContext context,
    List<FileToType> filesToAutomate,
  ) {
    ref
        .read(humanizedTyperProvider.notifier)
        .startAutomation(filesToAutomate, config: _humanizationConfig);

    showModalBottomSheet<void>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Consumer(
          builder: (modalCtx, modalRef, child) {
            final progress = modalRef.watch(humanizedTyperProvider);
            final typerNotifier = modalRef.read(humanizedTyperProvider.notifier);
            final theme = Theme.of(modalCtx);

            final isPaused = progress.status == AutomationStatus.paused;
            final isCompleted = progress.status == AutomationStatus.completed;

            final percent = progress.totalCharacters > 0
                ? (progress.charactersTyped / progress.totalCharacters)
                    .clamp(0.0, 1.0)
                : 0.0;

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              isCompleted
                                  ? Icons.check_circle
                                  : (isPaused
                                      ? Icons.pause_circle_outline
                                      : Icons.keyboard),
                              color: isCompleted
                                  ? Colors.green
                                  : (isPaused
                                      ? Colors.orange
                                      : theme.colorScheme.primary),
                              size: 28,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              isCompleted
                                  ? 'Automation Completed!'
                                  : (isPaused
                                      ? 'Automation Paused'
                                      : 'Auto-Typing in Progress...'),
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        if (isCompleted)
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.pop(modalCtx),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Progress indicators
                    LinearProgressIndicator(value: percent, minHeight: 8),
                    const SizedBox(height: 12),
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
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Active File: ${progress.activeFileName}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Live Stats Card
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Column(
                            children: [
                              Text('${progress.currentWpm} WPM',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16)),
                              const Text('Typing Speed',
                                  style: TextStyle(fontSize: 11)),
                            ],
                          ),
                          Container(
                              height: 28,
                              width: 1,
                              color: theme.colorScheme.outlineVariant),
                          Column(
                            children: [
                              Text('${progress.typosCorrected}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: Colors.orange)),
                              const Text('Typos Corrected',
                                  style: TextStyle(fontSize: 11)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Control Buttons
                    Row(
                      children: [
                        if (!isCompleted) ...[
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: Icon(isPaused ? Icons.play_arrow : Icons.pause),
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
                                  foregroundColor: Colors.red.shade900),
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

    final visibleNodes = _buildVisibleTree(state.visibleNodes, state.expandedNodeIds);
    final totalFilesCount = state.nodes.where((n) => !n.isDirectory).length;
    final includedFilesCount = state.nodes.where((n) => !n.isDirectory && !n.isExcluded).length;

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
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
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
                              style: TextStyle(color: Colors.blue, fontSize: 12)),
                        ),
                        const SizedBox(width: 12),
                        InkWell(
                          onTap: () => notifier.selectAllNodes(true),
                          child: const Text('None',
                              style: TextStyle(color: Colors.blue, fontSize: 12)),
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
                    Expanded(
                      child: FilledButton.icon(
                        icon: const Icon(Icons.play_arrow),
                        label: Text('Auto-Type ($includedFilesCount Files)'),
                        onPressed: () => _startAutomationWithWarning(context),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
