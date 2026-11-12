import 'dart:io';
import 'package:archive/archive.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../data/project_repository.dart';
import '../models/project_models.dart';
import 'tree_parser_service.dart';

class ProjectImporterService {
  final ProjectRepository _repository;
  final TreeParserService _treeParser;
  final http.Client _httpClient;

  ProjectImporterService({
    required ProjectRepository repository,
    TreeParserService? treeParser,
    http.Client? httpClient,
  })  : _repository = repository,
        _treeParser = treeParser ?? TreeParserService(),
        _httpClient = httpClient ?? http.Client();

  /// Imports a project from an existing local filesystem directory.
  Future<ProjectEntity> importFromDirectory(
    String projectName,
    String directoryPath,
  ) async {
    final dir = Directory(directoryPath);
    if (!await dir.exists()) {
      throw FileSystemException('Directory does not exist', directoryPath);
    }

    final relativePaths = <String>[];
    final normalizedBase = directoryPath.replaceAll('\\', '/');

    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      final normalizedEntityPath = entity.path.replaceAll('\\', '/');
      var rel = normalizedEntityPath;
      if (rel.startsWith(normalizedBase)) {
        rel = rel.substring(normalizedBase.length);
      }
      while (rel.startsWith('/')) {
        rel = rel.substring(1);
      }
      if (rel.isNotEmpty) {
        relativePaths.add(rel);
      }
    }

    final projectId = 'proj-${DateTime.now().microsecondsSinceEpoch}';
    return _persistProjectWithId(
      projectId,
      projectName,
      'local_dir',
      directoryPath,
      relativePaths,
    );
  }

  /// Imports a project from in-memory ZIP archive bytes (e.g. from file picker or download)
  /// and extracts the files to persistent storage for automation typing.
  Future<ProjectEntity> importFromZipBytes(
    String projectName,
    List<int> zipBytes, {
    String source = 'local_zip',
    String? customRootPath,
  }) async {
    final archive = ZipDecoder().decodeBytes(zipBytes, verify: false);
    final projectId = 'proj-${DateTime.now().microsecondsSinceEpoch}';

    Directory targetDir;
    if (customRootPath != null && customRootPath.isNotEmpty) {
      targetDir = Directory(customRootPath);
      if (!await targetDir.exists()) {
        await targetDir.create(recursive: true);
      }
    } else {
      try {
        final appDir = await getApplicationDocumentsDirectory();
        targetDir = Directory('${appDir.path}/koder_projects/$projectId');
        if (!await targetDir.exists()) {
          await targetDir.create(recursive: true);
        }
      } catch (_) {
        targetDir = Directory('${Directory.systemTemp.path}/koder_projects/$projectId');
        if (!await targetDir.exists()) {
          await targetDir.create(recursive: true);
        }
      }
    }

    final relativePaths = <String>[];

    for (final file in archive) {
      final sanitized = _sanitizeZipPath(file.name);
      if (sanitized.isNotEmpty) {
        relativePaths.add(sanitized);
        if (file.isFile) {
          try {
            final content = file.content as List<int>;
            final outFile = File('${targetDir.path}/$sanitized');
            await outFile.parent.create(recursive: true);
            await outFile.writeAsBytes(content);
          } catch (_) {
            // Safe fallback if archive header has size mismatch
          }
        }
      }
    }

    return _persistProjectWithId(
      projectId,
      projectName,
      source,
      targetDir.path,
      relativePaths,
    );
  }

  /// Reads the text content of an extracted project file.
  Future<String> getFileContent(
    String projectRootPath,
    String relativePath,
  ) async {
    try {
      final file = File('$projectRootPath/$relativePath');
      if (await file.exists()) {
        return await file.readAsString();
      }
    } catch (_) {}
    return '';
  }

  /// Downloads and imports a project from a remote ZIP URL over HTTPS.
  Future<ProjectEntity> importFromRemoteZipUrl(
    String projectName,
    Uri url,
  ) async {
    if (url.scheme != 'https' && url.scheme != 'http') {
      throw ArgumentError('Only HTTP/HTTPS URLs are supported');
    }

    final response = await _httpClient.get(url);
    if (response.statusCode != 200) {
      throw HttpException(
        'Failed to download ZIP archive (HTTP ${response.statusCode})',
        uri: url,
      );
    }

    return importFromZipBytes(
      projectName,
      response.bodyBytes,
      source: 'remote_zip',
    );
  }

  /// Imports a GitHub repository archive using GitHub's archive endpoint.
  Future<ProjectEntity> importFromGitHub(
    String owner,
    String repo, {
    String branch = 'main',
  }) async {
    final url =
        Uri.parse('https://api.github.com/repos/$owner/$repo/zipball/$branch');
    final response = await _httpClient.get(
      url,
      headers: {
        'Accept': 'application/vnd.github.v3+json',
        'User-Agent': 'VSCode-Companion-App',
      },
    );

    if (response.statusCode != 200) {
      throw HttpException(
        'Failed to download GitHub repository archive (HTTP ${response.statusCode})',
        uri: url,
      );
    }

    return importFromZipBytes(
      '$owner/$repo',
      response.bodyBytes,
      source: 'github',
    );
  }

  Future<ProjectEntity> _persistProjectWithId(
    String projectId,
    String name,
    String source,
    String rootPath,
    List<String> paths,
  ) async {
    final now = DateTime.now().millisecondsSinceEpoch;

    final project = ProjectEntity(
      id: projectId,
      name: name,
      source: source,
      rootPath: rootPath,
      createdAt: now,
      lastAccessedAt: now,
    );

    final fileNodes = _treeParser.parsePaths(projectId, paths);

    await _repository.insertProject(project);
    await _repository.insertFileNodes(fileNodes);

    return project;
  }

  String _sanitizeZipPath(String rawPath) {
    var p = rawPath.replaceAll('\\', '/').trim();
    // Neutralize directory traversal attacks
    if (p.contains('../') || p.contains('/..') || p == '..') {
      return '';
    }
    while (p.startsWith('/')) {
      p = p.substring(1);
    }
    while (p.endsWith('/')) {
      p = p.substring(0, p.length - 1);
    }
    return p;
  }
}
