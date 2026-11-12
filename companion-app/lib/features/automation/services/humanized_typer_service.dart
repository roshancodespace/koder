import 'dart:async';
import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../bluetooth_hid/bluetooth_hid_service.dart';
import '../../network/providers/websocket_provider.dart';
import '../../project/data/project_repository.dart';
import '../../project/models/project_models.dart';
import '../../project/providers/project_provider.dart';
import '../models/humanization_config.dart';
import 'keyboard_scancode_mapper.dart';

enum AutomationStatus {
  idle,
  running,
  paused,
  completed,
  cancelled,
  error,
}

class AutomationProgress {
  final AutomationStatus status;
  final String projectId;
  final String activeFileName;
  final int currentFileIndex;
  final int characterOffset;
  final int totalFiles;
  final int charactersTyped;
  final int totalCharacters;
  final int typosCorrected;
  final int driftFixesApplied;
  final int currentWpm;
  final String? errorMessage;

  const AutomationProgress({
    this.status = AutomationStatus.idle,
    this.projectId = '',
    this.activeFileName = '',
    this.currentFileIndex = 0,
    this.characterOffset = 0,
    this.totalFiles = 0,
    this.charactersTyped = 0,
    this.totalCharacters = 0,
    this.typosCorrected = 0,
    this.driftFixesApplied = 0,
    this.currentWpm = 0,
    this.errorMessage,
  });

  AutomationProgress copyWith({
    AutomationStatus? status,
    String? projectId,
    String? activeFileName,
    int? currentFileIndex,
    int? characterOffset,
    int? totalFiles,
    int? charactersTyped,
    int? totalCharacters,
    int? typosCorrected,
    int? driftFixesApplied,
    int? currentWpm,
    String? errorMessage,
  }) {
    return AutomationProgress(
      status: status ?? this.status,
      projectId: projectId ?? this.projectId,
      activeFileName: activeFileName ?? this.activeFileName,
      currentFileIndex: currentFileIndex ?? this.currentFileIndex,
      characterOffset: characterOffset ?? this.characterOffset,
      totalFiles: totalFiles ?? this.totalFiles,
      charactersTyped: charactersTyped ?? this.charactersTyped,
      totalCharacters: totalCharacters ?? this.totalCharacters,
      typosCorrected: typosCorrected ?? this.typosCorrected,
      driftFixesApplied: driftFixesApplied ?? this.driftFixesApplied,
      currentWpm: currentWpm ?? this.currentWpm,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

class FileToType {
  final String relativePath;
  final String content;

  const FileToType({
    required this.relativePath,
    required this.content,
  });
}

class HumanizedTyperNotifier extends StateNotifier<AutomationProgress> {
  final BluetoothHidNotifier _hidNotifier;
  final ProjectRepository? _repository;
  final Map<String, dynamic>? Function()? _getEditorState;
  final Future<bool> Function(String relativePath)? _prepareFileInEditor;
  final Random _random = Random();

  bool _isPaused = false;
  bool _isCancelled = false;
  bool _skipRequested = false;

  HumanizedTyperNotifier(
    this._hidNotifier, {
    ProjectRepository? repository,
    Map<String, dynamic>? Function()? getEditorState,
    Future<bool> Function(String relativePath)? prepareFileInEditor,
  })  : _repository = repository,
        _getEditorState = getEditorState,
        _prepareFileInEditor = prepareFileInEditor,
        super(const AutomationProgress());

  void pause() {
    _isPaused = true;
    state = state.copyWith(status: AutomationStatus.paused);
    _saveCheckpoint(
      projectId: state.projectId,
      fileIndex: state.currentFileIndex,
      charOffset: state.characterOffset,
      fileName: state.activeFileName,
      typed: state.charactersTyped,
      total: state.totalCharacters,
      typos: state.typosCorrected,
    );
  }

  void resume() {
    _isPaused = false;
    state = state.copyWith(status: AutomationStatus.running);
  }

  void cancel() {
    _isCancelled = true;
    _isPaused = false;
    state = state.copyWith(status: AutomationStatus.cancelled);
    _saveCheckpoint(
      projectId: state.projectId,
      fileIndex: state.currentFileIndex,
      charOffset: state.characterOffset,
      fileName: state.activeFileName,
      typed: state.charactersTyped,
      total: state.totalCharacters,
      typos: state.typosCorrected,
    );
  }

  void skipCurrentFile() {
    _skipRequested = true;
  }

  Future<void> startAutomation(
    String projectId,
    List<FileToType> files, {
    HumanizationConfig config = const HumanizationConfig(),
    int resumeFileIndex = 0,
    int resumeCharOffset = 0,
  }) async {
    if (files.isEmpty) return;

    _isPaused = false;
    _isCancelled = false;
    _skipRequested = false;

    final totalChars =
        files.fold<int>(0, (sum, file) => sum + file.content.length);

    int startTyped = 0;
    for (int idx = 0; idx < resumeFileIndex && idx < files.length; idx++) {
      startTyped += files[idx].content.length;
    }
    startTyped += resumeCharOffset;

    state = AutomationProgress(
      status: AutomationStatus.running,
      projectId: projectId,
      activeFileName:
          files[min(resumeFileIndex, files.length - 1)].relativePath,
      currentFileIndex: resumeFileIndex,
      characterOffset: resumeCharOffset,
      totalFiles: files.length,
      charactersTyped: startTyped,
      totalCharacters: totalChars,
      typosCorrected: 0,
      driftFixesApplied: 0,
      currentWpm: (config.minWpm + config.maxWpm) ~/ 2,
    );

    int overallTyped = startTyped;
    int overallTypos = 0;
    int overallDriftFixes = 0;

    for (int i = resumeFileIndex; i < files.length; i++) {
      if (_isCancelled) break;
      _skipRequested = false;

      final file = files[i];
      final text = file.content;
      final textLength = text.length;
      final int startOffset = (i == resumeFileIndex) ? resumeCharOffset : 0;

      state = state.copyWith(
        currentFileIndex: i,
        characterOffset: startOffset,
        activeFileName: file.relativePath,
      );

      // Auto-open or create the file in VS Code via WebSocket RPC if connected
      final prepareFn = _prepareFileInEditor;
      if (prepareFn != null) {
        try {
          await prepareFn(file.relativePath);
          // Wait briefly for VS Code to switch and render the editor tab
          await Future<void>.delayed(const Duration(milliseconds: 600));
        } catch (_) {}
      }
      if (_isCancelled) break;

      // Save starting checkpoint for this file
      await _saveCheckpoint(
        projectId: projectId,
        fileIndex: i,
        charOffset: startOffset,
        fileName: file.relativePath,
        typed: overallTyped,
        total: totalChars,
        typos: overallTypos,
      );

      // 1. Give human 1 second to view the next file starting
      await Future<void>.delayed(const Duration(milliseconds: 1000));
      if (_isCancelled) break;

      // 2. Type file content with humanization and drift checking
      int burstCounter = 0;
      final int burstThreshold = _random.nextInt(25) + 20;

      // Track active bracket stack for auto-bracket awareness
      final List<String> openBrackets = [];

      for (int charIdx = startOffset; charIdx < textLength; charIdx++) {
        if (_isCancelled) break;
        if (_skipRequested) break;

        // Handle pause loop
        while (_isPaused && !_isCancelled) {
          await Future<void>.delayed(const Duration(milliseconds: 200));
        }
        if (_isCancelled) break;

        final char = text[charIdx];

        // --- AUTO-INDENTATION & BRACKET AWARENESS ---
        if (config.autoBracketAware) {
          if (char == '{' || char == '(' || char == '[') {
            openBrackets.add(char);
          } else if (openBrackets.isNotEmpty) {
            final last = openBrackets.last;
            if ((char == '}' && last == '{') ||
                (char == ')' && last == '(') ||
                (char == ']' && last == '[')) {
              openBrackets.removeLast();
            }
          }
        }

        final stroke = KeyboardScancodeMapper.charToKeyStroke(char);
        if (stroke == null) {
          overallTyped++;
          continue;
        }

        // --- TYPO SIMULATION ---
        final shouldMakeTypo =
            _random.nextDouble() * 100.0 < config.errorRatePercent;
        if (shouldMakeTypo && char.trim().isNotEmpty) {
          final adjacentKey = KeyboardScancodeMapper.getAdjacentKey(char);
          if (adjacentKey != null) {
            final wrongStroke =
                KeyboardScancodeMapper.charToKeyStroke(adjacentKey);
            if (wrongStroke != null) {
              await _hidNotifier.sendShortcut(
                wrongStroke.modifier,
                wrongStroke.keyCode,
              );
              overallTypos++;
              state = state.copyWith(typosCorrected: overallTypos);

              final realizationMs = _random.nextInt(180) + 120;
              await Future<void>.delayed(
                Duration(milliseconds: realizationMs),
              );

              await _hidNotifier.sendShortcut(
                HidKeyStroke.backspace.modifier,
                HidKeyStroke.backspace.keyCode,
              );

              final recoveryMs = _random.nextInt(80) + 80;
              await Future<void>.delayed(
                Duration(milliseconds: recoveryMs),
              );
            }
          }
        }

        // --- TYPE ACTUAL CHARACTER ---
        await _hidNotifier.sendShortcut(stroke.modifier, stroke.keyCode);
        overallTyped++;
        burstCounter++;

        // --- SELF-HEALING DRIFT FIXER ---
        // Run conservatively only on newlines after brief pause for editor debounce to settle
        if (config.selfHealingFixer && char == '\n') {
          await Future<void>.delayed(const Duration(milliseconds: 280));
          if (_isCancelled) break;
          final fixes = await _healDriftIfDetected(
            file.relativePath,
            text,
            charIdx + 1,
            config,
          );
          if (fixes > 0) {
            overallDriftFixes += fixes;
            state = state.copyWith(driftFixesApplied: overallDriftFixes);
          }
        }

        // --- AUTO-INDENTATION HANDLING AFTER NEWLINE ---
        if (char == '\n' && config.autoIndentationAware) {
          final editorState = _getEditorState?.call();
          final tabSize = (editorState?['tabSize'] as int?) ?? 2;
          final skipped = _detectAutoIndentSkip(text, charIdx + 1, tabSize);
          if (skipped > 0) {
            // Fast-forward past the auto-indented spaces
            charIdx += skipped;
            overallTyped += skipped;
          }
        }

        // --- CALCULATE NATURAL DELAY ---
        final randomWpm = _random.nextInt(
              max(1, config.maxWpm - config.minWpm + 1),
            ) +
            config.minWpm;
        final baseCharDelayMs = (60000 / (randomWpm * 5)).round();
        final jitter = (_random.nextDouble() * 0.5 - 0.25) * baseCharDelayMs;
        var sleepMs = max(25, (baseCharDelayMs + jitter).round());

        // Newline pause
        if (char == '\n') {
          sleepMs += config.newlinePauseMs + _random.nextInt(150);
        }
        // Punctuation pause
        else if (char == ';' ||
            char == '}' ||
            char == ')' ||
            char == ']' ||
            char == ',') {
          sleepMs += config.punctuationPauseMs + _random.nextInt(100);
        }

        // Thinking burst pause
        if (config.enableThinkingPauses && burstCounter >= burstThreshold) {
          sleepMs += _random.nextInt(400) + 300;
          burstCounter = 0;
        }

        if (charIdx % 5 == 0) {
          state = state.copyWith(
            charactersTyped: overallTyped,
            characterOffset: charIdx,
            currentWpm: randomWpm,
          );
        }

        // Checkpoint persistence every 50 characters
        if (charIdx > 0 && charIdx % 50 == 0) {
          _saveCheckpoint(
            projectId: projectId,
            fileIndex: i,
            charOffset: charIdx,
            fileName: file.relativePath,
            typed: overallTyped,
            total: totalChars,
            typos: overallTypos,
          );
        }

        await Future<void>.delayed(Duration(milliseconds: sleepMs));
      }

      // After finishing file, send Save (Ctrl+S: modifier 0x01, keycode 0x16)
      if (!_isCancelled && !_skipRequested) {
        await Future<void>.delayed(const Duration(milliseconds: 300));
        await _hidNotifier.sendShortcut(0x01, 0x16); // Ctrl + S
        await Future<void>.delayed(const Duration(milliseconds: 500));
      }
    }

    if (!_isCancelled) {
      state = state.copyWith(
        status: AutomationStatus.completed,
        charactersTyped: totalChars,
      );
      if (_repository != null && projectId.isNotEmpty) {
        await _repository.clearAutomationCheckpoint(projectId);
      }
    }
  }

  Future<int> _healDriftIfDetected(
    String targetRelPath,
    String expectedFullContent,
    int charIdx,
    HumanizationConfig config,
  ) async {
    final getEditor = _getEditorState;
    if (getEditor == null) return 0;
    final editorState = getEditor();
    if (editorState == null) return 0;

    // 1. Guard: Only proceed if active file in VS Code matches target file
    final activeRelPath = editorState['relativePath'] as String?;
    if (activeRelPath == null) return 0;
    final normalizedActive = activeRelPath.replaceAll('\\', '/');
    final normalizedTarget = targetRelPath.replaceAll('\\', '/');
    if (!normalizedActive.endsWith(normalizedTarget) &&
        !normalizedTarget.endsWith(normalizedActive)) {
      return 0;
    }

    final live = editorState['activeContent'] as String?;
    if (live == null || live.isEmpty) return 0;

    final expected = expectedFullContent.substring(0, charIdx);
    if (live == expected) return 0;

    // 2. Guard: If expected starts with live, recent keystrokes are still in-transit
    // or pending VS Code's 250ms debounce. NEVER re-type them!
    if (expected.startsWith(live)) {
      return 0;
    }

    int fixesCount = 0;

    // Case 1: Live has extra characters at the end (e.g. auto-closing pair: extra ")" or quote)
    if (live.startsWith(expected) && live.length > expected.length) {
      int extraCount = live.length - expected.length;
      // Only fix small local over-insertions (at most 4 characters)
      if (extraCount <= 4) {
        fixesCount += extraCount;
        while (extraCount > 0 && !_isCancelled) {
          await _hidNotifier.sendShortcut(
            HidKeyStroke.backspace.modifier,
            HidKeyStroke.backspace.keyCode,
          );
          extraCount--;
          await Future<void>.delayed(const Duration(milliseconds: 35));
        }
      }
      return fixesCount;
    }

    // Case 2: Divergence at the end of the line
    int lcp = 0;
    final minLen = min(live.length, expected.length);
    while (lcp < minLen && live[lcp] == expected[lcp]) {
      lcp++;
    }

    final unwantedInLive = live.length - lcp;
    final missingInExpected = expected.length - lcp;

    // Strictly conservative: only fix tiny local typos (<= 4 chars)
    if (unwantedInLive > 0 && unwantedInLive <= 4 && missingInExpected <= 4) {
      fixesCount += unwantedInLive + missingInExpected;
      int toDelete = unwantedInLive;
      while (toDelete > 0 && !_isCancelled) {
        await _hidNotifier.sendShortcut(
          HidKeyStroke.backspace.modifier,
          HidKeyStroke.backspace.keyCode,
        );
        toDelete--;
        await Future<void>.delayed(const Duration(milliseconds: 35));
      }

      for (int i = lcp; i < expected.length; i++) {
        if (_isCancelled) break;
        final ch = expected[i];
        final stroke = KeyboardScancodeMapper.charToKeyStroke(ch);
        if (stroke != null) {
          await _hidNotifier.sendShortcut(stroke.modifier, stroke.keyCode);
          await Future<void>.delayed(const Duration(milliseconds: 30));
        }
      }
    }

    return fixesCount;
  }

  int _detectAutoIndentSkip(
    String text,
    int nextCharIdx,
    int tabSize,
  ) {
    if (nextCharIdx >= text.length) return 0;
    int spaceCount = 0;
    while (nextCharIdx + spaceCount < text.length &&
        text[nextCharIdx + spaceCount] == ' ') {
      spaceCount++;
    }
    if (spaceCount >= tabSize) {
      return tabSize;
    }
    return spaceCount;
  }

  Future<void> _saveCheckpoint({
    required String projectId,
    required int fileIndex,
    required int charOffset,
    required String fileName,
    required int typed,
    required int total,
    required int typos,
  }) async {
    final repo = _repository;
    if (repo == null || projectId.isEmpty) return;
    try {
      await repo.saveAutomationCheckpoint(
        AutomationCheckpointEntity(
          projectId: projectId,
          currentFileIndex: fileIndex,
          characterOffset: charOffset,
          activeFileName: fileName,
          charactersTyped: typed,
          totalCharacters: total,
          typosCorrected: typos,
          updatedAt: DateTime.now().millisecondsSinceEpoch,
        ),
      );
    } catch (_) {}
  }
}

final humanizedTyperProvider =
    StateNotifierProvider<HumanizedTyperNotifier, AutomationProgress>((ref) {
  final hidNotifier = ref.watch(bluetoothHidServiceProvider.notifier);
  final repository = ref.watch(projectRepositoryProvider);
  final networkNotifier = ref.watch(companionNetworkStateProvider.notifier);

  return HumanizedTyperNotifier(
    hidNotifier,
    repository: repository,
    getEditorState: () =>
        ref.read(companionNetworkStateProvider).activeEditorState,
    prepareFileInEditor: (relativePath) async {
      try {
        final res = await networkNotifier.sendRequest(
          'workspace.prepareFile',
          {'relativePath': relativePath},
          timeout: const Duration(seconds: 4),
        );
        return res.type == 'response' && res.payload['success'] == true;
      } catch (_) {
        return false;
      }
    },
  );
});
