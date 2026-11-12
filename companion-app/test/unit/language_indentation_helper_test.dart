import 'package:companion_app/features/automation/services/language_indentation_helper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LanguageIndentationHelper Tests', () {
    test(
        'detectLanguage correctly categorizes file extensions and language IDs',
        () {
      expect(
        LanguageIndentationHelper.detectLanguage('main.py'),
        SupportedLanguage.python,
      );
      expect(
        LanguageIndentationHelper.detectLanguage('script.pyw'),
        SupportedLanguage.python,
      );
      expect(
        LanguageIndentationHelper.detectLanguage('unknown.txt',
            languageId: 'python'),
        SupportedLanguage.python,
      );

      expect(
        LanguageIndentationHelper.detectLanguage('app.dart'),
        SupportedLanguage.braceStyle,
      );
      expect(
        LanguageIndentationHelper.detectLanguage('server.ts'),
        SupportedLanguage.braceStyle,
      );
      expect(
        LanguageIndentationHelper.detectLanguage('client.js'),
        SupportedLanguage.braceStyle,
      );
      expect(
        LanguageIndentationHelper.detectLanguage('main.rs'),
        SupportedLanguage.braceStyle,
      );
      expect(
        LanguageIndentationHelper.detectLanguage('main.go'),
        SupportedLanguage.braceStyle,
      );

      expect(
        LanguageIndentationHelper.detectLanguage('index.html'),
        SupportedLanguage.markupAndData,
      );
      expect(
        LanguageIndentationHelper.detectLanguage('data.json'),
        SupportedLanguage.markupAndData,
      );
      expect(
        LanguageIndentationHelper.detectLanguage('config.yaml'),
        SupportedLanguage.markupAndData,
      );
      expect(
        LanguageIndentationHelper.detectLanguage('notes.md'),
        SupportedLanguage.markupAndData,
      );

      expect(
        LanguageIndentationHelper.detectLanguage('plain.txt'),
        SupportedLanguage.generic,
      );
    });

    test('defaultTabSize returns correct defaults for languages', () {
      expect(
        LanguageIndentationHelper.defaultTabSize(SupportedLanguage.python),
        4,
      );
      expect(
        LanguageIndentationHelper.defaultTabSize(SupportedLanguage.braceStyle),
        2,
      );
      expect(
        LanguageIndentationHelper.defaultTabSize(
            SupportedLanguage.markupAndData),
        2,
      );
    });

    test('countLeadingIndent correctly calculates spaces and tabs', () {
      expect(LanguageIndentationHelper.countLeadingIndent('hello', 4), 0);
      expect(LanguageIndentationHelper.countLeadingIndent('    hello', 4), 4);
      expect(
          LanguageIndentationHelper.countLeadingIndent('        hello', 4), 8);
      expect(LanguageIndentationHelper.countLeadingIndent('\thello', 4), 4);
      expect(LanguageIndentationHelper.countLeadingIndent('\t\thello', 4), 8);
      expect(LanguageIndentationHelper.countLeadingIndent('  \thello', 4), 6);
    });

    test(
        'predictNextLineIndent correctly handles Python block openings and comments',
        () {
      // Python def statement
      expect(
        LanguageIndentationHelper.predictNextLineIndent(
          language: SupportedLanguage.python,
          lineBody: 'def extended_gcd(a, b):',
          lineIndent: 0,
          tabSize: 4,
          previousBlockIndent: 0,
        ),
        4,
      );

      // Python if statement inside def
      expect(
        LanguageIndentationHelper.predictNextLineIndent(
          language: SupportedLanguage.python,
          lineBody: 'if b == 0:',
          lineIndent: 4,
          tabSize: 4,
          previousBlockIndent: 4,
        ),
        8,
      );

      // Python with trailing comment
      expect(
        LanguageIndentationHelper.predictNextLineIndent(
          language: SupportedLanguage.python,
          lineBody: 'if b == 0:  # base case check',
          lineIndent: 4,
          tabSize: 4,
          previousBlockIndent: 4,
        ),
        8,
      );

      // Python return statement (not opening a block)
      expect(
        LanguageIndentationHelper.predictNextLineIndent(
          language: SupportedLanguage.python,
          lineBody: 'return a, 1, 0',
          lineIndent: 8,
          tabSize: 4,
          previousBlockIndent: 8,
        ),
        8,
      );

      // Empty line maintains previous block indent
      expect(
        LanguageIndentationHelper.predictNextLineIndent(
          language: SupportedLanguage.python,
          lineBody: '',
          lineIndent: 0,
          tabSize: 4,
          previousBlockIndent: 8,
        ),
        8,
      );
    });

    test('predictNextLineIndent correctly handles C/Dart brace syntax', () {
      expect(
        LanguageIndentationHelper.predictNextLineIndent(
          language: SupportedLanguage.braceStyle,
          lineBody: 'void main() {',
          lineIndent: 0,
          tabSize: 2,
          previousBlockIndent: 0,
        ),
        2,
      );

      expect(
        LanguageIndentationHelper.predictNextLineIndent(
          language: SupportedLanguage.braceStyle,
          lineBody: 'print("hello");',
          lineIndent: 2,
          tabSize: 2,
          previousBlockIndent: 2,
        ),
        2,
      );
    });
  });
}
