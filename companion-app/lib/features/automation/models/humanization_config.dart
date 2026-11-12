class HumanizationConfig {
  /// Minimum typing speed in Words Per Minute (e.g. 20 - 40 WPM)
  final int minWpm;

  /// Maximum typing speed in Words Per Minute (e.g. 40 - 75 WPM)
  final int maxWpm;

  /// Percentage likelihood of making a typo on any given character (0.0 to 10.0%)
  final double errorRatePercent;

  /// Pause duration in ms after writing a newline (human reviewing context)
  final int newlinePauseMs;

  /// Pause duration in ms after punctuation (;, }, ), ])
  final int punctuationPauseMs;

  /// Whether to introduce natural thinking bursts / pauses every 20-50 characters
  final bool enableThinkingPauses;

  /// Whether the typer is aware of VS Code auto-indentation and avoids duplicate leading spaces
  final bool autoIndentationAware;

  /// Whether the typer is aware of VS Code auto-closing brackets and avoids duplicate brackets
  final bool autoBracketAware;

  /// Whether the self-healing drift fixer is active to detect user alterations,
  /// navigate via arrow keys, and delete unwanted text with Backspace
  final bool selfHealingFixer;

  /// Whether to speed up cursor navigation and deletion using Ctrl+Arrow and Ctrl+Backspace
  final bool enableCtrlSpeedup;

  const HumanizationConfig({
    this.minWpm = 35,
    this.maxWpm = 65,
    this.errorRatePercent = 1.5,
    this.newlinePauseMs = 250,
    this.punctuationPauseMs = 120,
    this.enableThinkingPauses = true,
    this.autoIndentationAware = false,
    this.autoBracketAware = false,
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
      selfHealingFixer: selfHealingFixer ?? this.selfHealingFixer,
      enableCtrlSpeedup: enableCtrlSpeedup ?? this.enableCtrlSpeedup,
    );
  }
}
