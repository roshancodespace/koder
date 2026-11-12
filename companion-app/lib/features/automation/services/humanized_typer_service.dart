import 'dart:async';
import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../bluetooth_hid/bluetooth_hid_service.dart';
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
  final String activeFileName;
  final int currentFileIndex;
  final int totalFiles;
  final int charactersTyped;
  final int totalCharacters;
  final int typosCorrected;
  final int currentWpm;
  final String? errorMessage;

  const AutomationProgress({
    this.status = AutomationStatus.idle,
    this.activeFileName = '',
    this.currentFileIndex = 0,
    this.totalFiles = 0,
    this.charactersTyped = 0,
    this.totalCharacters = 0,
    this.typosCorrected = 0,
    this.currentWpm = 0,
    this.errorMessage,
  });

  AutomationProgress copyWith({
    AutomationStatus? status,
    String? activeFileName,
    int? currentFileIndex,
    int? totalFiles,
    int? charactersTyped,
    int? totalCharacters,
    int? typosCorrected,
    int? currentWpm,
    String? errorMessage,
  }) {
    return AutomationProgress(
      status: status ?? this.status,
      activeFileName: activeFileName ?? this.activeFileName,
      currentFileIndex: currentFileIndex ?? this.currentFileIndex,
      totalFiles: totalFiles ?? this.totalFiles,
      charactersTyped: charactersTyped ?? this.charactersTyped,
      totalCharacters: totalCharacters ?? this.totalCharacters,
      typosCorrected: typosCorrected ?? this.typosCorrected,
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
  final Random _random = Random();

  bool _isPaused = false;
  bool _isCancelled = false;
  bool _skipRequested = false;

  HumanizedTyperNotifier(this._hidNotifier) : super(const AutomationProgress());

  void pause() {
    _isPaused = true;
    state = state.copyWith(status: AutomationStatus.paused);
  }

  void resume() {
    _isPaused = false;
    state = state.copyWith(status: AutomationStatus.running);
  }

  void cancel() {
    _isCancelled = true;
    _isPaused = false;
    state = state.copyWith(status: AutomationStatus.cancelled);
  }

  void skipCurrentFile() {
    _skipRequested = true;
  }

  Future<void> startAutomation(
    List<FileToType> files, {
    HumanizationConfig config = const HumanizationConfig(),
  }) async {
    if (files.isEmpty) return;

    _isPaused = false;
    _isCancelled = false;
    _skipRequested = false;

    final totalChars =
        files.fold<int>(0, (sum, file) => sum + file.content.length);

    state = AutomationProgress(
      status: AutomationStatus.running,
      activeFileName: files.first.relativePath,
      currentFileIndex: 0,
      totalFiles: files.length,
      charactersTyped: 0,
      totalCharacters: totalChars,
      typosCorrected: 0,
      currentWpm: (config.minWpm + config.maxWpm) ~/ 2,
    );

    int overallTyped = 0;
    int overallTypos = 0;

    for (int i = 0; i < files.length; i++) {
      if (_isCancelled) break;
      _skipRequested = false;

      final file = files[i];
      state = state.copyWith(
        currentFileIndex: i,
        activeFileName: file.relativePath,
      );

      // 1. Give human 1 second to view the next file starting
      await Future<void>.delayed(const Duration(milliseconds: 1000));
      if (_isCancelled) break;

      // 2. Type file content with humanization
      final text = file.content;
      final textLength = text.length;
      int burstCounter = 0;
      final int burstThreshold = _random.nextInt(25) + 20;

      for (int charIdx = 0; charIdx < textLength; charIdx++) {
        if (_isCancelled) break;
        if (_skipRequested) break;

        // Handle pause loop
        while (_isPaused && !_isCancelled) {
          await Future<void>.delayed(const Duration(milliseconds: 200));
        }
        if (_isCancelled) break;

        final char = text[charIdx];
        final stroke = KeyboardScancodeMapper.charToKeyStroke(char);

        if (stroke == null) {
          // Unsupported unicode character - fallback or skip
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
              // 1. Send the mistyped character
              await _hidNotifier.sendShortcut(
                wrongStroke.modifier,
                wrongStroke.keyCode,
              );
              overallTypos++;
              state = state.copyWith(typosCorrected: overallTypos);

              // 2. Human realization delay (120 - 300 ms)
              final realizationMs = _random.nextInt(180) + 120;
              await Future<void>.delayed(
                Duration(milliseconds: realizationMs),
              );

              // 3. Send Backspace to erase mistake
              await _hidNotifier.sendShortcut(
                HidKeyStroke.backspace.modifier,
                HidKeyStroke.backspace.keyCode,
              );

              // 4. Recovery delay before typing correct char (80 - 160 ms)
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

        // --- CALCULATE NATURAL DELAY ---
        final randomWpm = _random.nextInt(
              max(1, config.maxWpm - config.minWpm + 1),
            ) +
            config.minWpm;
        final baseCharDelayMs = (60000 / (randomWpm * 5)).round();
        // Add random jitter of +/- 25%
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
            currentWpm: randomWpm,
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
    }
  }
}

final humanizedTyperProvider =
    StateNotifierProvider<HumanizedTyperNotifier, AutomationProgress>((ref) {
  final hidNotifier = ref.watch(bluetoothHidServiceProvider.notifier);
  return HumanizedTyperNotifier(hidNotifier);
});

