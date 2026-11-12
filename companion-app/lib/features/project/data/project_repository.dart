import 'package:sqflite/sqflite.dart';
import '../models/project_models.dart';
import 'database_helper.dart';

abstract interface class ProjectRepository {
  Future<void> insertProject(ProjectEntity project);
  Future<List<ProjectEntity>> getProjects();
  Future<ProjectEntity?> getProjectById(String id);
  Future<void> deleteProject(String id);
  Future<void> insertFileNodes(List<FileNodeEntity> nodes);
  Future<List<FileNodeEntity>> getFileNodesByProject(String projectId);
  Future<void> updateNodeExclusion(String nodeId, bool isExcluded);
  Future<void> insertExclusionRule(ExclusionRuleEntity rule);
  Future<List<ExclusionRuleEntity>> getExclusionRules(String projectId);
  Future<void> deleteExclusionRule(String id);
  Future<void> logSessionEvent(SessionLogEntity log);
  Future<List<SessionLogEntity>> getSessionLogs({int limit = 100});
}

class ProjectRepositoryImpl implements ProjectRepository {
  final Future<Database> Function() _dbProvider;

  ProjectRepositoryImpl([Future<Database> Function()? dbProvider])
      : _dbProvider = dbProvider ?? (() => DatabaseHelper.instance.database);

  @override
  Future<void> insertProject(ProjectEntity project) async {
    final db = await _dbProvider();
    await db.insert(
      'projects',
      project.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<List<ProjectEntity>> getProjects() async {
    final db = await _dbProvider();
    final rows = await db.query(
      'projects',
      orderBy: 'last_accessed_at DESC',
    );
    return rows.map(ProjectEntity.fromMap).toList();
  }

  @override
  Future<ProjectEntity?> getProjectById(String id) async {
    final db = await _dbProvider();
    final rows = await db.query(
      'projects',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return ProjectEntity.fromMap(rows.first);
  }

  @override
  Future<void> deleteProject(String id) async {
    final db = await _dbProvider();
    await db.delete(
      'projects',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<void> insertFileNodes(List<FileNodeEntity> nodes) async {
    final db = await _dbProvider();
    await db.transaction((txn) async {
      final batch = txn.batch();
      for (final node in nodes) {
        batch.insert(
          'file_nodes',
          node.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
    });
  }

  @override
  Future<List<FileNodeEntity>> getFileNodesByProject(String projectId) async {
    final db = await _dbProvider();
    final rows = await db.query(
      'file_nodes',
      where: 'project_id = ?',
      whereArgs: [projectId],
      orderBy: 'path ASC',
    );
    return rows.map(FileNodeEntity.fromMap).toList();
  }

  @override
  Future<void> updateNodeExclusion(String nodeId, bool isExcluded) async {
    final db = await _dbProvider();
    await db.update(
      'file_nodes',
      {'is_excluded': isExcluded ? 1 : 0},
      where: 'id = ?',
      whereArgs: [nodeId],
    );
  }

  @override
  Future<void> insertExclusionRule(ExclusionRuleEntity rule) async {
    final db = await _dbProvider();
    await db.insert(
      'exclusion_rules',
      rule.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<List<ExclusionRuleEntity>> getExclusionRules(String projectId) async {
    final db = await _dbProvider();
    final rows = await db.query(
      'exclusion_rules',
      where: 'project_id = ?',
      whereArgs: [projectId],
      orderBy: 'created_at ASC',
    );
    return rows.map(ExclusionRuleEntity.fromMap).toList();
  }

  @override
  Future<void> deleteExclusionRule(String id) async {
    final db = await _dbProvider();
    await db.delete(
      'exclusion_rules',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<void> logSessionEvent(SessionLogEntity log) async {
    final db = await _dbProvider();
    await db.insert(
      'session_history',
      log.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<List<SessionLogEntity>> getSessionLogs({int limit = 100}) async {
    final db = await _dbProvider();
    final rows = await db.query(
      'session_history',
      orderBy: 'timestamp DESC',
      limit: limit,
    );
    return rows.map(SessionLogEntity.fromMap).toList();
  }
}

/// In-memory repository implementation for unit testing and offline preview
class InMemoryProjectRepository implements ProjectRepository {
  final Map<String, ProjectEntity> _projects = {};
  final Map<String, FileNodeEntity> _nodes = {};
  final Map<String, ExclusionRuleEntity> _rules = {};
  final List<SessionLogEntity> _logs = [];

  @override
  Future<void> insertProject(ProjectEntity project) async {
    _projects[project.id] = project;
  }

  @override
  Future<List<ProjectEntity>> getProjects() async {
    final list = _projects.values.toList();
    list.sort((a, b) => b.lastAccessedAt.compareTo(a.lastAccessedAt));
    return list;
  }

  @override
  Future<ProjectEntity?> getProjectById(String id) async {
    return _projects[id];
  }

  @override
  Future<void> deleteProject(String id) async {
    _projects.remove(id);
    _nodes.removeWhere((_, node) => node.projectId == id);
    _rules.removeWhere((_, rule) => rule.projectId == id);
  }

  @override
  Future<void> insertFileNodes(List<FileNodeEntity> nodes) async {
    for (final node in nodes) {
      _nodes[node.id] = node;
    }
  }

  @override
  Future<List<FileNodeEntity>> getFileNodesByProject(String projectId) async {
    final list = _nodes.values.where((n) => n.projectId == projectId).toList();
    list.sort((a, b) => a.path.compareTo(b.path));
    return list;
  }

  @override
  Future<void> updateNodeExclusion(String nodeId, bool isExcluded) async {
    final node = _nodes[nodeId];
    if (node != null) {
      _nodes[nodeId] = node.copyWith(isExcluded: isExcluded);
    }
  }

  @override
  Future<void> insertExclusionRule(ExclusionRuleEntity rule) async {
    _rules[rule.id] = rule;
  }

  @override
  Future<List<ExclusionRuleEntity>> getExclusionRules(String projectId) async {
    final list = _rules.values.where((r) => r.projectId == projectId).toList();
    list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return list;
  }

  @override
  Future<void> deleteExclusionRule(String id) async {
    _rules.remove(id);
  }

  @override
  Future<void> logSessionEvent(SessionLogEntity log) async {
    _logs.add(log);
  }

  @override
  Future<List<SessionLogEntity>> getSessionLogs({int limit = 100}) async {
    final list = List<SessionLogEntity>.from(_logs);
    list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return list.take(limit).toList();
  }
}
