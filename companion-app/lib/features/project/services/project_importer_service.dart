import 'dart:io';
import 'package:archive/archive.dart';
import 'package:http/http.dart' as http;
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

    return _persistProject(
        projectName, 'local_dir', directoryPath, relativePaths);
  }

  /// Imports a project from in-memory ZIP archive bytes (e.g. from file picker or download).
  Future<ProjectEntity> importFromZipBytes(
    String projectName,
    List<int> zipBytes, {
    String source = 'local_zip',
    String rootPath = '',
  }) async {
    final archive = ZipDecoder().decodeBytes(zipBytes, verify: false);
    final relativePaths = <String>[];

    for (final file in archive) {
      final sanitized = _sanitizeZipPath(file.name);
      if (sanitized.isNotEmpty) {
        relativePaths.add(sanitized);
      }
    }

    final effectiveRoot = rootPath.isNotEmpty ? rootPath : '/zip/$projectName';
    return _persistProject(projectName, source, effectiveRoot, relativePaths);
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
      rootPath: url.toString(),
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
      rootPath: 'github.com/$owner/$repo',
    );
  }

  Future<ProjectEntity> _persistProject(
    String name,
    String source,
    String rootPath,
    List<String> paths,
  ) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final projectId = 'proj-${DateTime.now().microsecondsSinceEpoch}';

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
