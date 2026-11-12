import 'package:flutter_test/flutter_test.dart';
import 'package:companion_app/features/project/models/project_models.dart';
import 'package:companion_app/features/project/data/project_repository.dart';

void main() {
  group('Project Models Unit Tests', () {
    test('ProjectEntity toMap and fromMap round-trip', () {
      const project = ProjectEntity(
        id: 'proj-1',
        name: 'My Flutter App',
        source: 'local_dir',
        rootPath: '/home/user/dev/app',
        createdAt: 1731400000000,
        lastAccessedAt: 1731405000000,
      );

      final map = project.toMap();
      expect(map['id'], 'proj-1');
      expect(map['name'], 'My Flutter App');
      expect(map['source'], 'local_dir');
      expect(map['root_path'], '/home/user/dev/app');

      final deserialized = ProjectEntity.fromMap(map);
      expect(deserialized.id, project.id);
      expect(deserialized.name, project.name);
      expect(deserialized.source, project.source);
      expect(deserialized.rootPath, project.rootPath);
      expect(deserialized.createdAt, project.createdAt);
      expect(deserialized.lastAccessedAt, project.lastAccessedAt);
    });

    test('FileNodeEntity toMap and fromMap round-trip with booleans', () {
      const node = FileNodeEntity(
        id: 'node-1',
        projectId: 'proj-1',
        path: 'lib/main.dart',
        name: 'main.dart',
        isDirectory: false,
        parentId: 'dir-lib',
        isExcluded: true,
        size: 1024,
      );

      final map = node.toMap();
      expect(map['is_directory'], 0);
      expect(map['is_excluded'], 1);
      expect(map['parent_id'], 'dir-lib');

      final deserialized = FileNodeEntity.fromMap(map);
      expect(deserialized.id, node.id);
      expect(deserialized.isDirectory, isFalse);
      expect(deserialized.isExcluded, isTrue);
      expect(deserialized.parentId, 'dir-lib');
      expect(deserialized.size, 1024);
    });

    test('ExclusionRuleEntity and SessionLogEntity serialization', () {
      const rule = ExclusionRuleEntity(
        id: 'rule-1',
        projectId: 'proj-1',
        pattern: '*.log',
        isRegex: false,
        createdAt: 1731400000000,
      );
      final ruleMap = rule.toMap();
      final parsedRule = ExclusionRuleEntity.fromMap(ruleMap);
      expect(parsedRule.pattern, '*.log');
      expect(parsedRule.isRegex, isFalse);

      const log = SessionLogEntity(
        id: 'log-1',
        timestamp: 1731405000000,
        eventType: 'HID_SHORTCUT',
        message: 'Sent Ctrl+Alt+N',
      );
      final logMap = log.toMap();
      final parsedLog = SessionLogEntity.fromMap(logMap);
      expect(parsedLog.eventType, 'HID_SHORTCUT');
      expect(parsedLog.message, 'Sent Ctrl+Alt+N');
    });
  });

  group('ProjectRepository CRUD Unit Tests', () {
    late ProjectRepository repository;

    setUp(() {
      repository = InMemoryProjectRepository();
    });

    test('insertProject, getProjects, and getProjectById', () async {
      const project1 = ProjectEntity(
        id: 'p1',
        name: 'Project One',
        source: 'local_dir',
        rootPath: '/path/1',
        createdAt: 1000,
        lastAccessedAt: 2000,
      );
      const project2 = ProjectEntity(
        id: 'p2',
        name: 'Project Two',
        source: 'remote_zip',
        rootPath: '/path/2',
        createdAt: 1000,
        lastAccessedAt: 3000,
      );

      await repository.insertProject(project1);
      await repository.insertProject(project2);

      final projects = await repository.getProjects();
      expect(projects.length, 2);
      expect(projects.first.id, 'p2'); // Ordered by lastAccessedAt DESC

      final fetchedP1 = await repository.getProjectById('p1');
      expect(fetchedP1, isNotNull);
      expect(fetchedP1!.name, 'Project One');

      final notFound = await repository.getProjectById('missing');
      expect(notFound, isNull);
    });

    test('insertFileNodes, getFileNodesByProject, and updateNodeExclusion',
        () async {
      final nodes = [
        const FileNodeEntity(
          id: 'n1',
          projectId: 'p1',
          path: 'lib',
          name: 'lib',
          isDirectory: true,
        ),
        const FileNodeEntity(
          id: 'n2',
          projectId: 'p1',
          path: 'lib/main.dart',
          name: 'main.dart',
          isDirectory: false,
          parentId: 'n1',
        ),
      ];

      await repository.insertFileNodes(nodes);
      final fetchedNodes = await repository.getFileNodesByProject('p1');
      expect(fetchedNodes.length, 2);
      expect(fetchedNodes.first.name, 'lib');
      expect(fetchedNodes.last.isExcluded, isFalse);

      await repository.updateNodeExclusion('n2', true);
      final updatedNodes = await repository.getFileNodesByProject('p1');
      expect(updatedNodes.last.isExcluded, isTrue);
    });

    test('deleteProject cascades deletion to file nodes and rules', () async {
      const project = ProjectEntity(
        id: 'p-del',
        name: 'To Delete',
        source: 'github',
        rootPath: '/repo',
        createdAt: 100,
        lastAccessedAt: 100,
      );
      await repository.insertProject(project);

      await repository.insertFileNodes([
        const FileNodeEntity(
          id: 'node-del',
          projectId: 'p-del',
          path: 'README.md',
          name: 'README.md',
          isDirectory: false,
        ),
      ]);

      await repository.insertExclusionRule(
        const ExclusionRuleEntity(
          id: 'rule-del',
          projectId: 'p-del',
          pattern: '.git',
          createdAt: 100,
        ),
      );

      expect((await repository.getFileNodesByProject('p-del')).length, 1);
      expect((await repository.getExclusionRules('p-del')).length, 1);

      await repository.deleteProject('p-del');
      expect(await repository.getProjectById('p-del'), isNull);
      expect((await repository.getFileNodesByProject('p-del')).isEmpty, isTrue);
      expect((await repository.getExclusionRules('p-del')).isEmpty, isTrue);
    });

    test('logSessionEvent and getSessionLogs', () async {
      await repository.logSessionEvent(
        const SessionLogEntity(
          id: 'l1',
          timestamp: 100,
          eventType: 'CONNECT',
          message: 'Connected to loopback',
        ),
      );
      await repository.logSessionEvent(
        const SessionLogEntity(
          id: 'l2',
          timestamp: 200,
          eventType: 'DISCONNECT',
          message: 'Disconnected',
        ),
      );

      final logs = await repository.getSessionLogs(limit: 10);
      expect(logs.length, 2);
      expect(logs.first.id, 'l2'); // Most recent first
    });
  });
}
