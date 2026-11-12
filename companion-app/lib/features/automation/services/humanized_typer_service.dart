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
import 'language_indentation_helper.dart';

enum AutomationStatus {
  idle,
  navigating,
  running,
  resting, // Deep work break
  paused,
  completed,
  cancelled,
  error,
}

class AutomationProgress {
  final AutomationStatus status;
  final String statusMessage;
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
  final int breakRemainingSeconds;
  final int sessionElapsedSeconds;
  final String? errorMessage;

  const AutomationProgress({
    this.status = AutomationStatus.idle,
    this.statusMessage = '',
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
    this.breakRemainingSeconds = 0,
    this.sessionElapsedSeconds = 0,
    this.errorMessage,
  });

  AutomationProgress copyWith({
    AutomationStatus? status,
    String? statusMessage,
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
    int? breakRemainingSeconds,
    int? sessionElapsedSeconds,
    String? errorMessage,
  }) {
    return AutomationProgress(
      status: status ?? this.status,
      statusMessage: statusMessage ?? this.statusMessage,
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
      breakRemainingSeconds:
          breakRemainingSeconds ?? this.breakRemainingSeconds,
      sessionElapsedSeconds:
          sessionElapsedSeconds ?? this.sessionElapsedSeconds,
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
  bool _skipBreakRequested = false;

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
    state = state.copyWith(
      status: AutomationStatus.paused,
      statusMessage: 'Automation Paused',
    );
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
    state = state.copyWith(
      status: AutomationStatus.running,
      statusMessage: 'Auto-Typing in Progress...',
    );
  }

  void cancel() {
    _isCancelled = true;
    _isPaused = false;
    _skipBreakRequested = true;
    state = state.copyWith(
      status: AutomationStatus.cancelled,
      statusMessage: 'Automation Stopped',
    );
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

  void skipBreak() {
    _skipBreakRequested = true;
  }

  /// Sends a string of keystrokes character-by-character at natural typing cadence
  Future<void> _typeStringHumanized(String text, {int charDelayMs = 35}) async {
    for (int i = 0; i < text.length; i++) {
      if (_isCancelled) break;
      final ch = text[i];
      final stroke = KeyboardScancodeMapper.charToKeyStroke(ch);
      if (stroke != null) {
        await _hidNotifier.sendShortcut(stroke.modifier, stroke.keyCode);
        await Future<void>.delayed(Duration(milliseconds: charDelayMs));
      }
    }
  }

  /// Ensures target file is open and active in VS Code editor.
  /// Uses humanized shortcuts (Ctrl+P Quick Open, then Ctrl+Alt+N Create File)
  /// rather than instant background filesystem modifications.
  Future<bool> _ensureFileOpenAndActive(
    FileToType file,
    HumanizationConfig config,
  ) async {
    final targetPath = file.relativePath;
    final normalizedTarget = targetPath.replaceAll('\\', '/');

    // 1. Check if the active editor in VS Code is already this file
    final editorState = _getEditorState?.call();
    final activePath = editorState?['relativePath'] as String?;
    if (activePath != null) {
      final normalizedActive = activePath.replaceAll('\\', '/');
      if (normalizedActive.endsWith(normalizedTarget) ||
          normalizedTarget.endsWith(normalizedActive)) {
        return true;
      }
    }

    if (!config.useShortcutsForNavigation) {
      final prepare = _prepareFileInEditor;
      if (prepare != null) {
        return await prepare(file.relativePath);
      }
      return false;
    }

    // 2. Humanized Shortcut Navigation
    state = state.copyWith(
      status: AutomationStatus.navigating,
      statusMessage: 'Navigating to $targetPath via Quick Open...',
    );

    // Step A: Quick Open (Ctrl+P / Cmd+P)
    final quickOpenStroke =
        config.isMac ? HidKeyStroke.cmdP : HidKeyStroke.ctrlP;
    await _hidNotifier.sendShortcut(
      quickOpenStroke.modifier,
      quickOpenStroke.keyCode,
    );
    await Future<void>.delayed(const Duration(milliseconds: 380));

    // Type the file name / relative path into Quick Open
    await _typeStringHumanized(targetPath, charDelayMs: 35);
    await Future<void>.delayed(const Duration(milliseconds: 450));

    // Press Enter to open
    await _hidNotifier.sendShortcut(
      HidKeyStroke.enter.modifier,
      HidKeyStroke.enter.keyCode,
    );
    await Future<void>.delayed(const Duration(milliseconds: 650));

    // Verify if VS Code opened the file
    final stateAfterQuickOpen = _getEditorState?.call();
    final newActive = stateAfterQuickOpen?['relativePath'] as String?;
    if (newActive != null) {
      final normalizedNew = newActive.replaceAll('\\', '/');
      if (normalizedNew.endsWith(normalizedTarget) ||
          normalizedTarget.endsWith(normalizedNew)) {
        return true;
      }
    }

    // Step B: File does not exist yet. Dismiss Quick Open palette if still open.
    await _hidNotifier.sendShortcut(
      HidKeyStroke.escape.modifier,
      HidKeyStroke.escape.keyCode,
    );
    await Future<void>.delayed(const Duration(milliseconds: 250));

    // Use Companion Create File shortcut (Ctrl+Alt+N / Cmd+Alt+N)
    state = state.copyWith(
      status: AutomationStatus.navigating,
      statusMessage:
          'Creating $targetPath via Companion shortcut (Ctrl+Alt+N)...',
    );

    final createFileStroke =
        config.isMac ? HidKeyStroke.cmdAltN : HidKeyStroke.ctrlAltN;
    await _hidNotifier.sendShortcut(
      createFileStroke.modifier,
      createFileStroke.keyCode,
    );
    await Future<void>.delayed(const Duration(milliseconds: 400));

    // Type relative file path into the InputBox
    await _typeStringHumanized(targetPath, charDelayMs: 38);
    await Future<void>.delayed(const Duration(milliseconds: 300));

    // Press Enter to confirm file creation
    await _hidNotifier.sendShortcut(
      HidKeyStroke.enter.modifier,
      HidKeyStroke.enter.keyCode,
    );
    await Future<void>.delayed(const Duration(milliseconds: 700));

    // Verify if file is now active
    final stateAfterCreate = _getEditorState?.call();
    final createdActive = stateAfterCreate?['relativePath'] as String?;
    if (createdActive != null) {
      final norm = createdActive.replaceAll('\\', '/');
      if (norm.endsWith(normalizedTarget) || normalizedTarget.endsWith(norm)) {
        return true;
      }
    }

    // Step C: Fallback to extension RPC if shortcut didn't register
    final prepareFallback = _prepareFileInEditor;
    if (prepareFallback != null) {
      final success = await prepareFallback(file.relativePath);
      await Future<void>.delayed(const Duration(milliseconds: 500));
      return success;
    }

    return true;
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
    _skipBreakRequested = false;

    final totalChars =
        files.fold<int>(0, (sum, file) => sum + file.content.length);

    int startTyped = 0;
    for (int idx = 0; idx < resumeFileIndex && idx < files.length; idx++) {
      startTyped += files[idx].content.length;
    }
    startTyped += resumeCharOffset;

    state = AutomationProgress(
      status: AutomationStatus.running,
      statusMessage: 'Starting Humanized Auto-Typing...',
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
      breakRemainingSeconds: 0,
      sessionElapsedSeconds: 0,
    );

    int overallTyped = startTyped;
    int overallTypos = 0;
    final stopwatch = Stopwatch()..start();
    int nextBreakSeconds =
        config.enableDeepWorkBreaks ? (config.breakIntervalMinutes * 60) : 0;
    final int sessionGoalSeconds = config.sessionDurationMinutes * 60;

    for (int i = resumeFileIndex; i < files.length; i++) {
      if (_isCancelled) break;
      _skipRequested = false;

      final file = files[i];
      final normalizedTarget = file.relativePath.replaceAll('\\', '/');

      state = state.copyWith(
        currentFileIndex: i,
        characterOffset: 0,
        activeFileName: file.relativePath,
        status: AutomationStatus.navigating,
        statusMessage: 'Preparing ${file.relativePath}...',
      );

      // Open or create the file using humanized VS Code shortcuts
      await _ensureFileOpenAndActive(file, config);
      if (_isCancelled) break;

      // Detect language profile and tab size
      final editorState = _getEditorState?.call();
      final editorLang = editorState?['languageId'] as String?;
      final lang = LanguageIndentationHelper.detectLanguage(
        file.relativePath,
        languageId: editorLang,
      );
      final tabSize = (editorState?['tabSize'] as int?) ??
          LanguageIndentationHelper.defaultTabSize(lang);

      state = state.copyWith(
        status: AutomationStatus.running,
        statusMessage:
            'Typing ${file.relativePath} (${LanguageIndentationHelper.getLanguageDisplayName(lang)})',
      );

      // Save starting checkpoint for this file
      await _saveCheckpoint(
        projectId: projectId,
        fileIndex: i,
        charOffset: 0,
        fileName: file.relativePath,
        typed: overallTyped,
        total: totalChars,
        typos: overallTypos,
      );

      // Pause briefly for user to view file start
      await Future<void>.delayed(const Duration(milliseconds: 700));
      if (_isCancelled) break;

      // Split file into lines for language-aware indentation handling
      final rawLines = file.content.split('\n');
      int predictedCol = 0;
      int activeBlockIndent = 0;
      int burstCounter = 0;
      final int burstThreshold = _random.nextInt(25) + 20;

      for (int lineIdx = 0; lineIdx < rawLines.length; lineIdx++) {
        if (_isCancelled || _skipRequested) break;

        // Handle user pause loop
        while (_isPaused && !_isCancelled) {
          await Future<void>.delayed(const Duration(milliseconds: 200));
        }
        if (_isCancelled) break;

        // Session Duration Goal Check
        final elapsedSeconds = stopwatch.elapsed.inSeconds;
        state = state.copyWith(sessionElapsedSeconds: elapsedSeconds);
        if (sessionGoalSeconds > 0 && elapsedSeconds >= sessionGoalSeconds) {
          state = state.copyWith(
            status: AutomationStatus.completed,
            statusMessage:
                'Session duration goal reached (${config.sessionDurationMinutes} min)!',
          );
          _isCancelled = true;
          break;
        }

        // Deep Work Break Check
        if (config.enableDeepWorkBreaks &&
            elapsedSeconds >= nextBreakSeconds &&
            nextBreakSeconds > 0) {
          state = state.copyWith(
            status: AutomationStatus.resting,
            statusMessage: 'Deep Work Break — Rest your hands and eyes',
            breakRemainingSeconds: config.breakDurationMinutes * 60,
          );

          int breakRemaining = config.breakDurationMinutes * 60;
          while (breakRemaining > 0 &&
              !_isCancelled &&
              !_isPaused &&
              !_skipBreakRequested) {
            await Future<void>.delayed(const Duration(seconds: 1));
            breakRemaining--;
            state = state.copyWith(breakRemainingSeconds: breakRemaining);
          }

          _skipBreakRequested = false;
          if (_isCancelled) break;

          nextBreakSeconds =
              stopwatch.elapsed.inSeconds + (config.breakIntervalMinutes * 60);
          state = state.copyWith(
            status: AutomationStatus.running,
            statusMessage:
                'Resuming typing ${file.relativePath} (${LanguageIndentationHelper.getLanguageDisplayName(lang)})',
            breakRemainingSeconds: 0,
          );
        }

        // Active File Focus Guard: If user switched tabs or closed file, re-open it
        final getEditor = _getEditorState;
        if (getEditor != null) {
          final currentEd = getEditor();
          final currentAct = currentEd?['relativePath'] as String?;
          if (currentAct != null && currentAct.isNotEmpty) {
            final norm = currentAct.replaceAll('\\', '/');
            if (!norm.endsWith(normalizedTarget) &&
                !normalizedTarget.endsWith(norm)) {
              state = state.copyWith(
                status: AutomationStatus.navigating,
                statusMessage:
                    'Focus lost. Re-focusing ${file.relativePath}...',
              );
              final quickOpen =
                  config.isMac ? HidKeyStroke.cmdP : HidKeyStroke.ctrlP;
              await _hidNotifier.sendShortcut(
                quickOpen.modifier,
                quickOpen.keyCode,
              );
              await Future<void>.delayed(const Duration(milliseconds: 350));
              await _typeStringHumanized(file.relativePath, charDelayMs: 30);
              await Future<void>.delayed(const Duration(milliseconds: 400));
              await _hidNotifier.sendShortcut(
                HidKeyStroke.enter.modifier,
                HidKeyStroke.enter.keyCode,
              );
              await Future<void>.delayed(const Duration(milliseconds: 600));

              state = state.copyWith(
                status: AutomationStatus.running,
                statusMessage: 'Typing ${file.relativePath}',
              );
            }
          }
        }

        final rawLine = rawLines[lineIdx];
        final line = rawLine.endsWith('\r')
            ? rawLine.substring(0, rawLine.length - 1)
            : rawLine;
        final targetIndent =
            LanguageIndentationHelper.countLeadingIndent(line, tabSize);
        final lineBody =
            line.length >= targetIndent ? line.substring(targetIndent) : line;

        // Case 1: Empty line
        if (lineBody.isEmpty) {
          if (lineIdx < rawLines.length - 1) {
            await _hidNotifier.sendShortcut(
              HidKeyStroke.enter.modifier,
              HidKeyStroke.enter.keyCode,
            );
            overallTyped++;
            final newlineDelay = config.newlinePauseMs + _random.nextInt(60);
            await Future<void>.delayed(Duration(milliseconds: newlineDelay));
          }
          continue;
        }

        // Case 2: Content line -> Language-aware indentation alignment
        if (config.autoIndentationAware) {
          final editorPos = _getEditorState?.call()?['cursorPosition'];
          final currentRealCol =
              (editorPos?['character'] as int?) ?? predictedCol;

          if (currentRealCol > targetIndent) {
            // Dedent: send necessary backspaces
            final toDelete = currentRealCol - targetIndent;
            for (int d = 0; d < toDelete; d++) {
              if (_isCancelled) break;
              await _hidNotifier.sendShortcut(
                HidKeyStroke.backspace.modifier,
                HidKeyStroke.backspace.keyCode,
              );
              await Future<void>.delayed(const Duration(milliseconds: 25));
            }
          } else if (currentRealCol < targetIndent) {
            // Indent: send necessary spaces
            final toAdd = targetIndent - currentRealCol;
            for (int s = 0; s < toAdd; s++) {
              if (_isCancelled) break;
              await _hidNotifier.sendShortcut(
                HidKeyStroke.space.modifier,
                HidKeyStroke.space.keyCode,
              );
              await Future<void>.delayed(const Duration(milliseconds: 25));
            }
          }
        } else {
          // If indentation awareness is disabled, type raw leading spaces
          for (int s = 0; s < targetIndent; s++) {
            if (_isCancelled) break;
            await _hidNotifier.sendShortcut(
              HidKeyStroke.space.modifier,
              HidKeyStroke.space.keyCode,
            );
            await Future<void>.delayed(const Duration(milliseconds: 25));
          }
        }

        // Type line body character-by-character with realistic typing physics
        for (int c = 0; c < lineBody.length; c++) {
          if (_isCancelled || _skipRequested) break;
          while (_isPaused && !_isCancelled) {
            await Future<void>.delayed(const Duration(milliseconds: 200));
          }
          if (_isCancelled) break;

          final char = lineBody[c];
          final stroke = KeyboardScancodeMapper.charToKeyStroke(char);
          if (stroke == null) {
            overallTyped++;
            continue;
          }

          // Typo simulation
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

                final realizationMs = _random.nextInt(150) + 100;
                await Future<void>.delayed(
                  Duration(milliseconds: realizationMs),
                );

                await _hidNotifier.sendShortcut(
                  HidKeyStroke.backspace.modifier,
                  HidKeyStroke.backspace.keyCode,
                );

                final recoveryMs = _random.nextInt(70) + 60;
                await Future<void>.delayed(Duration(milliseconds: recoveryMs));
              }
            }
          }

          // Type actual character
          await _hidNotifier.sendShortcut(stroke.modifier, stroke.keyCode);
          overallTyped++;
          burstCounter++;

          // Natural human typing delay
          final randomWpm = _random.nextInt(
                max(1, config.maxWpm - config.minWpm + 1),
              ) +
              config.minWpm;
          final baseCharDelayMs = (60000 / (randomWpm * 5)).round();
          final jitter = (_random.nextDouble() * 0.4 - 0.2) * baseCharDelayMs;
          var sleepMs = max(25, (baseCharDelayMs + jitter).round());

          // Punctuation pause
          if (char == ';' ||
              char == '}' ||
              char == ')' ||
              char == ']' ||
              char == ',') {
            sleepMs += config.punctuationPauseMs + _random.nextInt(80);
          }

          // Natural thinking burst pause
          if (config.enableThinkingPauses && burstCounter >= burstThreshold) {
            sleepMs += _random.nextInt(350) + 250;
            burstCounter = 0;
          }

          await Future<void>.delayed(Duration(milliseconds: sleepMs));

          if (overallTyped % 8 == 0) {
            state = state.copyWith(
              charactersTyped: overallTyped,
              characterOffset: lineIdx,
              currentWpm: randomWpm,
            );
          }
        }

        activeBlockIndent = targetIndent;

        // Press Enter if not the last line of the file
        if (lineIdx < rawLines.length - 1) {
          await _hidNotifier.sendShortcut(
            HidKeyStroke.enter.modifier,
            HidKeyStroke.enter.keyCode,
          );
          overallTyped++;

          final newlineDelay = config.newlinePauseMs + _random.nextInt(80);
          await Future<void>.delayed(Duration(milliseconds: newlineDelay));

          // Predict next line's cursor column based on language syntax
          predictedCol = LanguageIndentationHelper.predictNextLineIndent(
            language: lang,
            lineBody: lineBody,
            lineIndent: targetIndent,
            tabSize: tabSize,
            previousBlockIndent: activeBlockIndent,
          );
        }

        // Save progress checkpoint every 10 lines
        if (lineIdx > 0 && lineIdx % 10 == 0) {
          _saveCheckpoint(
            projectId: projectId,
            fileIndex: i,
            charOffset: lineIdx,
            fileName: file.relativePath,
            typed: overallTyped,
            total: totalChars,
            typos: overallTypos,
          );
        }
      }
    }

    if (!_isCancelled) {
      state = state.copyWith(
        status: AutomationStatus.completed,
        statusMessage: 'Automation Successfully Completed!',
        charactersTyped: totalChars,
      );
      if (_repository != null && projectId.isNotEmpty) {
        await _repository.clearAutomationCheckpoint(projectId);
      }
    }
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
