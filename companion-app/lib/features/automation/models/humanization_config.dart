class HumanizationConfig {
  /// Minimum typing speed in Words Per Minute (e.g. 20 - 40 WPM)
  final int minWpm;

  /// Maximum typing speed in Words Per Minute (e.g. 40 - 75 WPM)
  final int maxWpm;

  /// Percentage likelihood of making a typo on any given character (0.0 to 10.0%)
  final double errorRatePercent;

  /// Pause duration in ms after writing a newline (human reviewing context)
  final int newlinePauseMs;

  /// Pause duration in ms after punctuation (;, }, ), ], :)
  final int punctuationPauseMs;

  /// Whether to introduce natural thinking bursts / pauses every 20-50 characters
  final bool enableThinkingPauses;

  /// Whether the typer is aware of language-specific indentation (Python, C-style, etc.)
  /// and automatically aligns indentation without duplicate spaces or staircase cascade
  final bool autoIndentationAware;

  /// Whether the typer is aware of VS Code auto-closing brackets and avoids duplicate brackets
  final bool autoBracketAware;

  /// Total duration in minutes for the active automation session (0 = unlimited / type all)
  final int sessionDurationMinutes;

  /// Whether deep work breaks are automatically triggered during long typing sessions
  final bool enableDeepWorkBreaks;

  /// Interval between deep work breaks in minutes (e.g. 25 min)
  final int breakIntervalMinutes;

  /// Duration of each rest break in minutes (e.g. 5 min)
  final int breakDurationMinutes;

  /// Whether the target workstation OS is macOS (uses Cmd shortcuts instead of Ctrl)
  final bool isMac;

  /// Whether to use humanized VS Code keyboard shortcuts (Ctrl+P / Ctrl+Alt+N)
  /// to open and create files interactively instead of instant silent RPC calls
  final bool useShortcutsForNavigation;

  /// Whether conservative drift checking is enabled
  final bool selfHealingFixer;

  /// Whether to speed up cursor navigation and deletion using Ctrl+Arrow and Ctrl+Backspace
  final bool enableCtrlSpeedup;

  const HumanizationConfig({
    this.minWpm = 35,
    this.maxWpm = 65,
    this.errorRatePercent = 1.2,
    this.newlinePauseMs = 200,
    this.punctuationPauseMs = 100,
    this.enableThinkingPauses = true,
    this.autoIndentationAware = true,
    this.autoBracketAware = true,
    this.sessionDurationMinutes = 0,
    this.enableDeepWorkBreaks = true,
    this.breakIntervalMinutes = 25,
    this.breakDurationMinutes = 5,
    this.isMac = false,
    this.useShortcutsForNavigation = true,
    this.selfHealingFixer = false,
    this.enableCtrlSpeedup = false,
  });

  HumanizationConfig copyWith({
    int? minWpm,
    int? maxWpm,
    double? errorRatePercent,
    int? newlinePauseMs,
    int? punctuationPauseMs,
    bool? enableThinkingPauses,
    bool? autoIndentationAware,
    bool? autoBracketAware,
    int? sessionDurationMinutes,
    bool? enableDeepWorkBreaks,
    int? breakIntervalMinutes,
    int? breakDurationMinutes,
    bool? isMac,
    bool? useShortcutsForNavigation,
    bool? selfHealingFixer,
    bool? enableCtrlSpeedup,
  }) {
    return HumanizationConfig(
      minWpm: minWpm ?? this.minWpm,
      maxWpm: maxWpm ?? this.maxWpm,
      errorRatePercent: errorRatePercent ?? this.errorRatePercent,
      newlinePauseMs: newlinePauseMs ?? this.newlinePauseMs,
      punctuationPauseMs: punctuationPauseMs ?? this.punctuationPauseMs,
      enableThinkingPauses: enableThinkingPauses ?? this.enableThinkingPauses,
      autoIndentationAware: autoIndentationAware ?? this.autoIndentationAware,
      autoBracketAware: autoBracketAware ?? this.autoBracketAware,
      sessionDurationMinutes:
          sessionDurationMinutes ?? this.sessionDurationMinutes,
      enableDeepWorkBreaks: enableDeepWorkBreaks ?? this.enableDeepWorkBreaks,
      breakIntervalMinutes: breakIntervalMinutes ?? this.breakIntervalMinutes,
      breakDurationMinutes: breakDurationMinutes ?? this.breakDurationMinutes,
      isMac: isMac ?? this.isMac,
      useShortcutsForNavigation:
          useShortcutsForNavigation ?? this.useShortcutsForNavigation,
      selfHealingFixer: selfHealingFixer ?? this.selfHealingFixer,
      enableCtrlSpeedup: enableCtrlSpeedup ?? this.enableCtrlSpeedup,
    );
  }
}
