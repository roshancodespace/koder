class ProjectEntity {
  final String id;
  final String name;
  final String source; // 'local_dir' | 'local_zip' | 'remote_zip' | 'github'
  final String rootPath;
  final int createdAt;
  final int lastAccessedAt;

  const ProjectEntity({
    required this.id,
    required this.name,
    required this.source,
    required this.rootPath,
    required this.createdAt,
    required this.lastAccessedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'source': source,
      'root_path': rootPath,
      'created_at': createdAt,
      'last_accessed_at': lastAccessedAt,
    };
  }

  factory ProjectEntity.fromMap(Map<String, dynamic> map) {
    return ProjectEntity(
      id: map['id'] as String,
      name: map['name'] as String,
      source: map['source'] as String,
      rootPath: map['root_path'] as String,
      createdAt: map['created_at'] as int,
      lastAccessedAt: map['last_accessed_at'] as int,
    );
  }

  ProjectEntity copyWith({
    String? id,
    String? name,
    String? source,
    String? rootPath,
    int? createdAt,
    int? lastAccessedAt,
  }) {
    return ProjectEntity(
      id: id ?? this.id,
      name: name ?? this.name,
      source: source ?? this.source,
      rootPath: rootPath ?? this.rootPath,
      createdAt: createdAt ?? this.createdAt,
      lastAccessedAt: lastAccessedAt ?? this.lastAccessedAt,
    );
  }
}

class FileNodeEntity {
  final String id;
  final String projectId;
  final String path;
  final String name;
  final bool isDirectory;
  final String? parentId;
  final bool isExcluded;
  final int size;

  const FileNodeEntity({
    required this.id,
    required this.projectId,
    required this.path,
    required this.name,
    required this.isDirectory,
    this.parentId,
    this.isExcluded = false,
    this.size = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'project_id': projectId,
      'path': path,
      'name': name,
      'is_directory': isDirectory ? 1 : 0,
      'parent_id': parentId,
      'is_excluded': isExcluded ? 1 : 0,
      'size': size,
    };
  }

  factory FileNodeEntity.fromMap(Map<String, dynamic> map) {
    return FileNodeEntity(
      id: map['id'] as String,
      projectId: map['project_id'] as String,
      path: map['path'] as String,
      name: map['name'] as String,
      isDirectory: (map['is_directory'] as int) == 1,
      parentId: map['parent_id'] as String?,
      isExcluded: (map['is_excluded'] as int) == 1,
      size: (map['size'] as int?) ?? 0,
    );
  }

  FileNodeEntity copyWith({
    String? id,
    String? projectId,
    String? path,
    String? name,
    bool? isDirectory,
    String? parentId,
    bool? isExcluded,
    int? size,
  }) {
    return FileNodeEntity(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      path: path ?? this.path,
      name: name ?? this.name,
      isDirectory: isDirectory ?? this.isDirectory,
      parentId: parentId ?? this.parentId,
      isExcluded: isExcluded ?? this.isExcluded,
      size: size ?? this.size,
    );
  }
}

class ExclusionRuleEntity {
  final String id;
  final String projectId;
  final String pattern;
  final bool isRegex;
  final int createdAt;

  const ExclusionRuleEntity({
    required this.id,
    required this.projectId,
    required this.pattern,
    this.isRegex = false,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'project_id': projectId,
      'pattern': pattern,
      'is_regex': isRegex ? 1 : 0,
      'created_at': createdAt,
    };
  }

  factory ExclusionRuleEntity.fromMap(Map<String, dynamic> map) {
    return ExclusionRuleEntity(
      id: map['id'] as String,
      projectId: map['project_id'] as String,
      pattern: map['pattern'] as String,
      isRegex: (map['is_regex'] as int) == 1,
      createdAt: map['created_at'] as int,
    );
  }
}

class SessionLogEntity {
  final String id;
  final int timestamp;
  final String eventType;
  final String message;

  const SessionLogEntity({
    required this.id,
    required this.timestamp,
    required this.eventType,
    required this.message,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'timestamp': timestamp,
      'event_type': eventType,
      'message': message,
    };
  }

  factory SessionLogEntity.fromMap(Map<String, dynamic> map) {
    return SessionLogEntity(
      id: map['id'] as String,
      timestamp: map['timestamp'] as int,
      eventType: map['event_type'] as String,
      message: map['message'] as String,
    );
  }
}
