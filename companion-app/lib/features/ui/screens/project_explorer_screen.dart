import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

  void _showImportDialog(BuildContext context) {
    final nameController = TextEditingController();
    final pathController = TextEditingController();

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Import Project'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Project Name',
                    hintText: 'e.g., koder-workspace',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: pathController,
                  decoration: const InputDecoration(
                    labelText: 'Directory Path',
                    hintText: '/home/user/my-project',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final name = nameController.text.trim();
                final path = pathController.text.trim();
                if (name.isNotEmpty && path.isNotEmpty) {
                  Navigator.of(dialogContext).pop();
                  ref
                      .read(projectExplorerStateProvider.notifier)
                      .importProjectFromDirectory(name, path);
                }
              },
              child: const Text('Import'),
            ),
          ],
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Project Explorer'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.create_new_folder_outlined),
            tooltip: 'Import Project',
            onPressed: () => _showImportDialog(context),
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
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Column(
                children: [
                  if (state.projects.isNotEmpty) ...[
                    DropdownButtonFormField<String>(
                      initialValue: state.activeProject?.id,
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
                        labelText: 'Select Project',
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search files...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: state.searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                notifier.setSearchQuery('');
                              },
                            )
                          : null,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (val) => notifier.setSearchQuery(val),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: state.projects.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.folder_off_outlined,
                            size: 64,
                            color: theme.colorScheme.outline,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No projects imported yet',
                            style: theme.textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          FilledButton.icon(
                            onPressed: () => _showImportDialog(context),
                            icon: const Icon(Icons.add),
                            label: const Text('Import Project'),
                          ),
                        ],
                      ),
                    )
                  : state.searchQuery.isNotEmpty
                      ? _buildFilteredList(state, notifier)
                      : _buildTreeView(state, notifier),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilteredList(
    ProjectExplorerState state,
    ProjectNotifier notifier,
  ) {
    final visible = state.visibleNodes;
    if (visible.isEmpty) {
      return const Center(child: Text('No matching files found'));
    }

    return ListView.builder(
      itemCount: visible.length,
      itemBuilder: (context, index) {
        final node = visible[index];
        return ListTile(
          dense: true,
          leading: Icon(
            node.isDirectory ? Icons.folder : Icons.insert_drive_file_outlined,
            size: 20,
            color: node.isDirectory ? Colors.amber[700] : Colors.blueGrey,
          ),
          title: Text(
            node.path,
            style: TextStyle(
              fontSize: 13,
              decoration: node.isExcluded ? TextDecoration.lineThrough : null,
              color: node.isExcluded ? Colors.grey : null,
            ),
          ),
          trailing: Checkbox(
            value: !node.isExcluded,
            onChanged: (_) => notifier.toggleNodeExclusion(node.id),
          ),
        );
      },
    );
  }

  Widget _buildTreeView(
    ProjectExplorerState state,
    ProjectNotifier notifier,
  ) {
    if (state.nodes.isEmpty) {
      return const Center(child: Text('Empty project'));
    }

    final treeItems = _buildVisibleTree(state.nodes, state.expandedNodeIds);

    return ListView.builder(
      itemCount: treeItems.length,
      itemBuilder: (context, index) {
        final item = treeItems[index];
        final node = item.node;
        final depth = item.depth;
        final isExpanded = item.isExpanded;

        return InkWell(
          onTap: node.isDirectory
              ? () => notifier.toggleNodeExpansion(node.id)
              : null,
          child: Padding(
            padding: EdgeInsets.only(
              left: 8.0 + (depth * 20.0),
              right: 8.0,
              top: 2.0,
              bottom: 2.0,
            ),
            child: Row(
              children: [
                if (node.isDirectory)
                  SizedBox(
                    width: 28,
                    height: 28,
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      icon: Icon(
                        isExpanded ? Icons.expand_more : Icons.chevron_right,
                        size: 18,
                      ),
                      onPressed: () => notifier.toggleNodeExpansion(node.id),
                    ),
                  )
                else
                  const SizedBox(width: 28),
                Icon(
                  node.isDirectory
                      ? (isExpanded ? Icons.folder_open : Icons.folder)
                      : Icons.insert_drive_file_outlined,
                  size: 18,
                  color: node.isDirectory ? Colors.amber[700] : Colors.blueGrey,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    node.name,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: node.isDirectory
                          ? FontWeight.w600
                          : FontWeight.normal,
                      decoration:
                          node.isExcluded ? TextDecoration.lineThrough : null,
                      color: node.isExcluded ? Colors.grey : null,
                    ),
                  ),
                ),
                Checkbox(
                  value: !node.isExcluded,
                  onChanged: (_) => notifier.toggleNodeExclusion(node.id),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
