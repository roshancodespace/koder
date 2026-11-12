import '../models/project_models.dart';

class TreeParserService {
  static const List<String> defaultExclusionPatterns = [
    '.git',
    'node_modules',
    '.dart_tool',
    'build',
    '.idea',
    '.vscode',
    '.DS_Store',
    '.gradle',
    'out',
    'dist',
  ];

  /// Parses a list of relative file/directory paths into a list of [FileNodeEntity]
  /// with resolved parent-child relationships and default exclusion states.
  List<FileNodeEntity> parsePaths(String projectId, List<String> rawPaths) {
    final nodesMap = <String, FileNodeEntity>{};
    final directoriesSet = <String>{};

    // First pass: collect directories and normalize paths
    for (final rawPath in rawPaths) {
      final normalized = _normalizePath(rawPath);
      if (normalized.isEmpty) continue;

      final parts = normalized.split('/');
      // Register all parent directory paths
      String currentDirPath = '';
      for (int i = 0; i < parts.length - 1; i++) {
        currentDirPath =
            currentDirPath.isEmpty ? parts[i] : '$currentDirPath/${parts[i]}';
        directoriesSet.add(currentDirPath);
      }
    }

    // Create directory nodes
    for (final dirPath in directoriesSet) {
      final parts = dirPath.split('/');
      final name = parts.last;
      final parentPath = parts.length > 1
          ? parts.sublist(0, parts.length - 1).join('/')
          : null;
      final id = _generateNodeId(projectId, dirPath);
      final parentId =
          parentPath != null ? _generateNodeId(projectId, parentPath) : null;
      final isDefaultExcluded = _isDefaultExcluded(name);

      nodesMap[dirPath] = FileNodeEntity(
        id: id,
        projectId: projectId,
        path: dirPath,
        name: name,
        isDirectory: true,
        parentId: parentId,
        isExcluded: isDefaultExcluded,
      );
    }

    // Create file nodes
    for (final rawPath in rawPaths) {
      final normalized = _normalizePath(rawPath);
      if (normalized.isEmpty || directoriesSet.contains(normalized)) continue;

      final parts = normalized.split('/');
      final name = parts.last;
      final parentPath = parts.length > 1
          ? parts.sublist(0, parts.length - 1).join('/')
          : null;
      final id = _generateNodeId(projectId, normalized);
      final parentId =
          parentPath != null ? _generateNodeId(projectId, parentPath) : null;

      final isDefaultExcluded = _isDefaultExcluded(name);

      nodesMap[normalized] = FileNodeEntity(
        id: id,
        projectId: projectId,
        path: normalized,
        name: name,
        isDirectory: false,
        parentId: parentId,
        isExcluded: isDefaultExcluded,
      );
    }

    final nodes = nodesMap.values.toList();
    nodes.sort((a, b) => a.path.compareTo(b.path));
    return nodes;
  }

  /// Computes effective exclusion for all nodes taking into account recursive
  /// inheritance from parent directory exclusions.
  Map<String, bool> computeEffectiveExclusions(List<FileNodeEntity> nodes) {
    final effective = <String, bool>{};
    final idToNode = {for (final n in nodes) n.id: n};

    for (final node in nodes) {
      effective[node.id] = _isNodeOrAncestorExcluded(node, idToNode);
    }

    return effective;
  }

  bool _isNodeOrAncestorExcluded(
    FileNodeEntity node,
    Map<String, FileNodeEntity> idToNode,
  ) {
    if (node.isExcluded) {
      return true;
    }
    if (node.parentId == null) {
      return false;
    }
    final parent = idToNode[node.parentId];
    if (parent == null) {
      return false;
    }
    return _isNodeOrAncestorExcluded(parent, idToNode);
  }

  String _normalizePath(String path) {
    var p = path.replaceAll('\\', '/').trim();
    while (p.startsWith('/')) {
      p = p.substring(1);
    }
    while (p.endsWith('/')) {
      p = p.substring(0, p.length - 1);
    }
    return p;
  }

  bool _isDefaultExcluded(String name) {
    for (final pattern in defaultExclusionPatterns) {
      if (name == pattern || name.startsWith('$pattern/')) {
        return true;
      }
    }
    return false;
  }

  String _generateNodeId(String projectId, String path) {
    return '$projectId:${path.hashCode.abs()}';
  }
}
