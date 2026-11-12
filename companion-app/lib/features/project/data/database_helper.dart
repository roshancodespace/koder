import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  static const String _databaseName = 'companion_koder.db';
  static const int _databaseVersion = 1;

  DatabaseHelper._internal();
  static final DatabaseHelper instance = DatabaseHelper._internal();

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _databaseName);

    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
      onConfigure: _onConfigure,
      onOpen: _onOpen,
    );
  }

  Future<void> _onConfigure(Database db) async {
    // Enable foreign key constraints
    await db.execute('PRAGMA foreign_keys = ON');
  }

  Future<void> _onOpen(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS automation_checkpoints (
        project_id TEXT PRIMARY KEY,
        current_file_index INTEGER NOT NULL DEFAULT 0,
        character_offset INTEGER NOT NULL DEFAULT 0,
        active_file_name TEXT NOT NULL DEFAULT '',
        characters_typed INTEGER NOT NULL DEFAULT 0,
        total_characters INTEGER NOT NULL DEFAULT 0,
        typos_corrected INTEGER NOT NULL DEFAULT 0,
        updated_at INTEGER NOT NULL,
        FOREIGN KEY (project_id) REFERENCES projects (id) ON DELETE CASCADE
      )
    ''');
  }

  Future<void> _onCreate(Database db, int version) async {
    // Projects table
    await db.execute('''
      CREATE TABLE projects (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        source TEXT NOT NULL,
        root_path TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        last_accessed_at INTEGER NOT NULL
      )
    ''');

    // File nodes table
    await db.execute('''
      CREATE TABLE file_nodes (
        id TEXT PRIMARY KEY,
        project_id TEXT NOT NULL,
        path TEXT NOT NULL,
        name TEXT NOT NULL,
        is_directory INTEGER NOT NULL,
        parent_id TEXT,
        is_excluded INTEGER NOT NULL DEFAULT 0,
        size INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (project_id) REFERENCES projects (id) ON DELETE CASCADE
      )
    ''');

    // Exclusion rules table
    await db.execute('''
      CREATE TABLE exclusion_rules (
        id TEXT PRIMARY KEY,
        project_id TEXT NOT NULL,
        pattern TEXT NOT NULL,
        is_regex INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL,
        FOREIGN KEY (project_id) REFERENCES projects (id) ON DELETE CASCADE
      )
    ''');

    // Session audit history
    await db.execute('''
      CREATE TABLE session_history (
        id TEXT PRIMARY KEY,
        timestamp INTEGER NOT NULL,
        event_type TEXT NOT NULL,
        message TEXT NOT NULL
      )
    ''');

    // Indices for rapid query performance
    await db.execute(
      'CREATE INDEX idx_file_nodes_project ON file_nodes(project_id, parent_id)',
    );
    await db.execute(
      'CREATE INDEX idx_exclusion_rules_project ON exclusion_rules(project_id)',
    );
  }

  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }
}
