import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/project_repository.dart';
import '../models/project_models.dart';
import '../services/project_importer_service.dart';
import '../services/tree_parser_service.dart';

final projectRepositoryProvider = Provider<ProjectRepository>((ref) {
  return ProjectRepositoryImpl();
});

final treeParserServiceProvider = Provider<TreeParserService>((ref) {
  return TreeParserService();
});

final projectImporterServiceProvider = Provider<ProjectImporterService>((ref) {
  final repository = ref.watch(projectRepositoryProvider);
  final treeParser = ref.watch(treeParserServiceProvider);
  return ProjectImporterService(
    repository: repository,
    treeParser: treeParser,
  );
});

class ProjectExplorerState {
  final List<ProjectEntity> projects;
  final ProjectEntity? activeProject;
  final List<FileNodeEntity> nodes;
  final Set<String> expandedNodeIds;
  final String searchQuery;
  final bool isLoading;
  final String? errorMessage;

  const ProjectExplorerState({
    this.projects = const [],
    this.activeProject,
    this.nodes = const [],
    this.expandedNodeIds = const {},
    this.searchQuery = '',
    this.isLoading = false,
    this.errorMessage,
  });

  ProjectExplorerState copyWith({
    List<ProjectEntity>? projects,
    ProjectEntity? activeProject,
    bool clearActiveProject = false,
    List<FileNodeEntity>? nodes,
    Set<String>? expandedNodeIds,
    String? searchQuery,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return ProjectExplorerState(
      projects: projects ?? this.projects,
      activeProject:
          clearActiveProject ? null : (activeProject ?? this.activeProject),
      nodes: nodes ?? this.nodes,
      expandedNodeIds: expandedNodeIds ?? this.expandedNodeIds,
      searchQuery: searchQuery ?? this.searchQuery,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  /// Returns filtered nodes matching the search query and root level / expanded view.
  List<FileNodeEntity> get visibleNodes {
    if (searchQuery.isNotEmpty) {
      final query = searchQuery.toLowerCase();
      return nodes.where((n) => n.name.toLowerCase().contains(query)).toList();
    }
    // Return all nodes; UI handles nested indentation and expansion
    return nodes;
  }
}

class ProjectNotifier extends StateNotifier<ProjectExplorerState> {
  final ProjectRepository _repository;
  final ProjectImporterService _importer;
  final TreeParserService _treeParser;

  ProjectNotifier({
    required ProjectRepository repository,
    required ProjectImporterService importer,
    required TreeParserService treeParser,
  })  : _repository = repository,
        _importer = importer,
        _treeParser = treeParser,
        super(const ProjectExplorerState()) {
    loadProjects();
  }

  Future<void> loadProjects() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final projects = await _repository.getProjects();
      state = state.copyWith(
        projects: projects,
        isLoading: false,
      );
      if (state.activeProject == null && projects.isNotEmpty) {
        await selectProject(projects.first.id);
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> selectProject(String projectId) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final project = await _repository.getProjectById(projectId);
      if (project != null) {
        final nodes = await _repository.getFileNodesByProject(projectId);
        state = state.copyWith(
          activeProject: project,
          nodes: nodes,
          expandedNodeIds: {},
          isLoading: false,
        );
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
    }
  }

  void toggleNodeExpansion(String nodeId) {
    final expanded = Set<String>.from(state.expandedNodeIds);
    if (expanded.contains(nodeId)) {
      expanded.remove(nodeId);
    } else {
      expanded.add(nodeId);
    }
    state = state.copyWith(expandedNodeIds: expanded);
  }

  Future<void> toggleNodeExclusion(String nodeId) async {
    final nodeIndex = state.nodes.indexWhere((n) => n.id == nodeId);
    if (nodeIndex == -1) return;

    final node = state.nodes[nodeIndex];
    final newExclusion = !node.isExcluded;

    await _repository.updateNodeExclusion(nodeId, newExclusion);

    // Update in local state
    final updatedNodes = List<FileNodeEntity>.from(state.nodes);
    updatedNodes[nodeIndex] = node.copyWith(isExcluded: newExclusion);

    state = state.copyWith(nodes: updatedNodes);
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query.trim());
  }

  Future<void> importProjectFromZip(String name, List<int> zipBytes) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final project = await _importer.importFromZipBytes(name, zipBytes);
      await loadProjects();
      await selectProject(project.id);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> importProjectFromDirectory(String name, String path) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final project = await _importer.importFromDirectory(name, path);
      await loadProjects();
      await selectProject(project.id);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> deleteProject(String projectId) async {
    state = state.copyWith(isLoading: true);
    try {
      await _repository.deleteProject(projectId);
      if (state.activeProject?.id == projectId) {
        state = state.copyWith(clearActiveProject: true, nodes: []);
      }
      await loadProjects();
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
    }
  }

  Map<String, bool> getEffectiveExclusions() {
    return _treeParser.computeEffectiveExclusions(state.nodes);
  }
}

final projectExplorerStateProvider =
    StateNotifierProvider<ProjectNotifier, ProjectExplorerState>((ref) {
  final repository = ref.watch(projectRepositoryProvider);
  final importer = ref.watch(projectImporterServiceProvider);
  final treeParser = ref.watch(treeParserServiceProvider);

  return ProjectNotifier(
    repository: repository,
    importer: importer,
    treeParser: treeParser,
  );
});
