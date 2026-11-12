enum SupportedLanguage {
  python,
  braceStyle, // Dart, TypeScript, JavaScript, C, C++, Java, Rust, Go, Kotlin, Swift, C#
  markupAndData, // HTML, XML, JSON, YAML, Markdown, CSS, SCSS, SQL
  generic,
}

class LanguageIndentationHelper {
  /// Detects the target language from the file name or editor language identifier.
  static SupportedLanguage detectLanguage(String fileName,
      {String? languageId}) {
    if (languageId != null && languageId.isNotEmpty) {
      final lid = languageId.toLowerCase().trim();
      if (lid == 'python') return SupportedLanguage.python;
      if (const [
        'dart',
        'typescript',
        'javascript',
        'c',
        'cpp',
        'java',
        'rust',
        'go',
        'csharp',
        'kotlin',
        'swift',
        'php',
      ].contains(lid)) {
        return SupportedLanguage.braceStyle;
      }
      if (const [
        'html',
        'xml',
        'json',
        'yaml',
        'markdown',
        'css',
        'scss',
        'sql',
      ].contains(lid)) {
        return SupportedLanguage.markupAndData;
      }
    }

    final lower = fileName.toLowerCase().trim();
    if (lower.endsWith('.py') || lower.endsWith('.pyw')) {
      return SupportedLanguage.python;
    }
    if (lower.endsWith('.dart') ||
        lower.endsWith('.ts') ||
        lower.endsWith('.js') ||
        lower.endsWith('.tsx') ||
        lower.endsWith('.jsx') ||
        lower.endsWith('.c') ||
        lower.endsWith('.cpp') ||
        lower.endsWith('.h') ||
        lower.endsWith('.hpp') ||
        lower.endsWith('.java') ||
        lower.endsWith('.rs') ||
        lower.endsWith('.go') ||
        lower.endsWith('.kt') ||
        lower.endsWith('.swift') ||
        lower.endsWith('.cs') ||
        lower.endsWith('.php')) {
      return SupportedLanguage.braceStyle;
    }
    if (lower.endsWith('.json') ||
        lower.endsWith('.yaml') ||
        lower.endsWith('.yml') ||
        lower.endsWith('.html') ||
        lower.endsWith('.xml') ||
        lower.endsWith('.md') ||
        lower.endsWith('.css') ||
        lower.endsWith('.scss') ||
        lower.endsWith('.sql')) {
      return SupportedLanguage.markupAndData;
    }

    return SupportedLanguage.generic;
  }

  /// Returns the human-readable display name for the language profile.
  static String getLanguageDisplayName(SupportedLanguage language) {
    switch (language) {
      case SupportedLanguage.python:
        return 'Python (Semantic Indentation)';
      case SupportedLanguage.braceStyle:
        return 'C-Style / Brace Syntax';
      case SupportedLanguage.markupAndData:
        return 'Markup & Data';
      case SupportedLanguage.generic:
        return 'Standard Text';
    }
  }

  /// Default tab size for the language profile when editor telemetry is absent.
  static int defaultTabSize(SupportedLanguage language) {
    switch (language) {
      case SupportedLanguage.python:
        return 4;
      case SupportedLanguage.braceStyle:
      case SupportedLanguage.markupAndData:
      case SupportedLanguage.generic:
        return 2;
    }
  }

  /// Measures leading whitespace (treating tabs as [tabSize] spaces).
  static int countLeadingIndent(String line, int tabSize) {
    int count = 0;
    for (int i = 0; i < line.length; i++) {
      if (line[i] == ' ') {
        count++;
      } else if (line[i] == '\t') {
        count += tabSize;
      } else {
        break;
      }
    }
    return count;
  }

  /// Predicts the indentation column where VS Code editor will position
  /// the cursor after pressing Enter on [lineBody] with target indentation [lineIndent].
  static int predictNextLineIndent({
    required SupportedLanguage language,
    required String lineBody,
    required int lineIndent,
    required int tabSize,
    required int previousBlockIndent,
  }) {
    final trimmed = lineBody.trim();
    if (trimmed.isEmpty) {
      // Empty line maintains the active block indentation level
      return previousBlockIndent;
    }

    switch (language) {
      case SupportedLanguage.python:
        // Python: Lines ending in colon ':' open a new indented block
        final clean = _stripPythonComment(trimmed);
        if (clean.endsWith(':')) {
          return lineIndent + tabSize;
        }
        return lineIndent;

      case SupportedLanguage.braceStyle:
        // Brace languages: Lines ending in '{' open an indented block
        if (trimmed.endsWith('{')) {
          return lineIndent + tabSize;
        }
        return lineIndent;

      case SupportedLanguage.markupAndData:
      case SupportedLanguage.generic:
        return lineIndent;
    }
  }

  static String _stripPythonComment(String line) {
    final hashIdx = line.indexOf('#');
    if (hashIdx >= 0) {
      return line.substring(0, hashIdx).trim();
    }
    return line;
  }
}
