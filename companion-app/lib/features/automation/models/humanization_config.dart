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

  const HumanizationConfig({
    this.minWpm = 30,
    this.maxWpm = 55,
    this.errorRatePercent = 3.5,
    this.newlinePauseMs = 350,
    this.punctuationPauseMs = 200,
    this.enableThinkingPauses = true,
  });

  HumanizationConfig copyWith({
    int? minWpm,
    int? maxWpm,
    double? errorRatePercent,
    int? newlinePauseMs,
    int? punctuationPauseMs,
    bool? enableThinkingPauses,
  }) {
    return HumanizationConfig(
      minWpm: minWpm ?? this.minWpm,
      maxWpm: maxWpm ?? this.maxWpm,
      errorRatePercent: errorRatePercent ?? this.errorRatePercent,
      newlinePauseMs: newlinePauseMs ?? this.newlinePauseMs,
      punctuationPauseMs: punctuationPauseMs ?? this.punctuationPauseMs,
      enableThinkingPauses: enableThinkingPauses ?? this.enableThinkingPauses,
    );
  }
}

