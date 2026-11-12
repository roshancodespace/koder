import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:archive/archive.dart';
import 'package:companion_app/features/project/data/project_repository.dart';
import 'package:companion_app/features/project/services/project_importer_service.dart';
import 'package:companion_app/features/project/services/tree_parser_service.dart';

void main() {
  group('ProjectImporterService Unit Tests', () {
    late InMemoryProjectRepository repository;
    late ProjectImporterService importer;

    setUp(() {
      repository = InMemoryProjectRepository();
      importer = ProjectImporterService(
        repository: repository,
        treeParser: TreeParserService(),
      );
    });

    test(
        'importFromZipBytes extracts archive and persists project and tree nodes',
        () async {
      // Create a test ZIP archive in memory
      final archive = Archive();
      archive
          .addFile(ArchiveFile('README.md', 12, utf8.encode('# Test Project')));
      archive.addFile(
          ArchiveFile('lib/main.dart', 20, utf8.encode('void main() {}')));
      archive.addFile(ArchiveFile(
          'lib/utils/helper.dart', 18, utf8.encode('class Helper {}')));
      archive.addFile(
          ArchiveFile('test/widget_test.dart', 10, utf8.encode('test()')));

      final zipEncoder = ZipEncoder();
      final zipBytes = zipEncoder.encode(archive);

      final project = await importer.importFromZipBytes('Test App', zipBytes);
      expect(project.name, 'Test App');
      expect(project.source, 'local_zip');

      // Verify repository persistence
      final savedProject = await repository.getProjectById(project.id);
      expect(savedProject, isNotNull);

      final nodes = await repository.getFileNodesByProject(project.id);
      final paths = nodes.map((n) => n.path).toList();
      expect(paths, contains('README.md'));
      expect(paths, contains('lib'));
      expect(paths, contains('lib/main.dart'));
      expect(paths, contains('lib/utils'));
      expect(paths, contains('lib/utils/helper.dart'));
      expect(paths, contains('test/widget_test.dart'));
    });

    test('importFromZipBytes neutralizes path traversal attempts', () async {
      final archive = Archive();
      archive.addFile(
          ArchiveFile('../../etc/passwd', 10, utf8.encode('malicious')));
      archive.addFile(ArchiveFile('safe/index.ts', 10, utf8.encode('safe')));

      final zipEncoder = ZipEncoder();
      final zipBytes = zipEncoder.encode(archive);

      final project = await importer.importFromZipBytes('Secure App', zipBytes);
      final nodes = await repository.getFileNodesByProject(project.id);
      final paths = nodes.map((n) => n.path).toList();

      expect(paths.any((p) => p.contains('passwd')), isFalse);
      expect(paths, contains('safe/index.ts'));
    });
  });
}
