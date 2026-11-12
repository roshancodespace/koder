import 'package:flutter_test/flutter_test.dart';
import 'package:companion_app/features/project/services/tree_parser_service.dart';

void main() {
  group('TreeParserService Unit Tests', () {
    late TreeParserService parser;

    setUp(() {
      parser = TreeParserService();
    });

    test('parsePaths creates intermediate directories and parent links', () {
      final paths = [
        'src/components/button/button.tsx',
        'src/utils/helpers.ts',
        'README.md',
      ];

      final nodes = parser.parsePaths('proj-test', paths);
      final pathsList = nodes.map((n) => n.path).toList();

      expect(pathsList, contains('README.md'));
      expect(pathsList, contains('src'));
      expect(pathsList, contains('src/components'));
      expect(pathsList, contains('src/components/button'));
      expect(pathsList, contains('src/components/button/button.tsx'));
      expect(pathsList, contains('src/utils'));
      expect(pathsList, contains('src/utils/helpers.ts'));

      final buttonFile =
          nodes.firstWhere((n) => n.path == 'src/components/button/button.tsx');
      final buttonDir =
          nodes.firstWhere((n) => n.path == 'src/components/button');
      expect(buttonFile.parentId, buttonDir.id);
      expect(buttonFile.isDirectory, isFalse);
      expect(buttonDir.isDirectory, isTrue);
    });

    test('default ignore patterns (.git, node_modules) are marked excluded',
        () {
      final paths = [
        '.git/config',
        'node_modules/react/index.js',
        'src/index.ts',
      ];

      final nodes = parser.parsePaths('proj-test', paths);
      final gitDir = nodes.firstWhere((n) => n.name == '.git');
      final nodeModulesDir = nodes.firstWhere((n) => n.name == 'node_modules');
      final srcDir = nodes.firstWhere((n) => n.name == 'src');

      expect(gitDir.isExcluded, isTrue);
      expect(nodeModulesDir.isExcluded, isTrue);
      expect(srcDir.isExcluded, isFalse);
    });

    test('computeEffectiveExclusions recursively marks descendants as excluded',
        () {
      final paths = [
        'build/outputs/apk/app-debug.apk',
        'src/main.dart',
      ];

      final nodes = parser.parsePaths('proj-test', paths);
      final effective = parser.computeEffectiveExclusions(nodes);

      final buildDir = nodes.firstWhere((n) => n.path == 'build');
      final apkFile =
          nodes.firstWhere((n) => n.path == 'build/outputs/apk/app-debug.apk');
      final mainFile = nodes.firstWhere((n) => n.path == 'src/main.dart');

      expect(effective[buildDir.id], isTrue);
      expect(effective[apkFile.id], isTrue); // Inherited from parent 'build'
      expect(effective[mainFile.id], isFalse);
    });
  });
}
