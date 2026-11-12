class HidKeyStroke {
  final int modifier;
  final int keyCode;

  const HidKeyStroke(this.modifier, this.keyCode);

  static const backspace = HidKeyStroke(0x00, 0x2A);
  static const enter = HidKeyStroke(0x00, 0x28);
  static const tab = HidKeyStroke(0x00, 0x2B);
  static const space = HidKeyStroke(0x00, 0x2C);
  static const escape = HidKeyStroke(0x00, 0x29);

  // Navigation Keycodes (USB HID Page 0x07)
  static const arrowRight = HidKeyStroke(0x00, 0x4F);
  static const arrowLeft = HidKeyStroke(0x00, 0x50);
  static const arrowDown = HidKeyStroke(0x00, 0x51);
  static const arrowUp = HidKeyStroke(0x00, 0x52);
  static const home = HidKeyStroke(0x00, 0x4A);
  static const end = HidKeyStroke(0x00, 0x4D);
  static const deleteForward = HidKeyStroke(0x00, 0x4C);

  // Ctrl Combinations for rapid word navigation and editing
  static const ctrlArrowLeft = HidKeyStroke(0x01, 0x50);
  static const ctrlArrowRight = HidKeyStroke(0x01, 0x4F);
  static const ctrlBackspace = HidKeyStroke(0x01, 0x2A);
  static const ctrlDelete = HidKeyStroke(0x01, 0x4C);
  static const ctrlA = HidKeyStroke(0x01, 0x04);

  // Shortcuts for humanized VS Code navigation & file management
  static const ctrlP = HidKeyStroke(0x01, 0x13); // Ctrl + P (Quick Open)
  static const cmdP = HidKeyStroke(0x08, 0x13); // Cmd + P (Mac Quick Open)
  static const ctrlAltN =
      HidKeyStroke(0x05, 0x11); // Ctrl + Alt + N (Companion Create File)
  static const cmdAltN =
      HidKeyStroke(0x0C, 0x11); // Cmd + Alt + N (Mac Companion Create File)
  static const shiftTab = HidKeyStroke(0x02, 0x2B); // Shift + Tab (Dedent)
}

class KeyboardScancodeMapper {
  static const int modNone = 0x00;
  static const int modShift = 0x02;

  /// Physical QWERTY Keyboard proximity lookup table for realistic typos
  static const Map<String, List<String>> _qwertyAdjacent = {
    'q': ['w', 'a', 's', '1', '2'],
    'w': ['q', 'e', 's', 'a', 'd', '2', '3'],
    'e': ['w', 'r', 'd', 's', 'f', '3', '4'],
    'r': ['e', 't', 'f', 'd', 'g', '4', '5'],
    't': ['r', 'y', 'g', 'f', 'h', '5', '6'],
    'y': ['t', 'u', 'h', 'g', 'j', '6', '7'],
    'u': ['y', 'i', 'j', 'h', 'k', '7', '8'],
    'i': ['u', 'o', 'k', 'j', 'l', '8', '9'],
    'o': ['i', 'p', 'l', 'k', '9', '0'],
    'p': ['o', '[', ';', 'l', '0', '-'],
    'a': ['q', 'w', 's', 'z'],
    's': ['a', 'w', 'e', 'd', 'x', 'z'],
    'd': ['s', 'e', 'r', 'f', 'c', 'x'],
    'f': ['d', 'r', 't', 'g', 'v', 'c'],
    'g': ['f', 't', 'y', 'h', 'b', 'v'],
    'h': ['g', 'y', 'u', 'j', 'n', 'b'],
    'j': ['h', 'u', 'i', 'k', 'm', 'n'],
    'k': ['j', 'i', 'o', 'l', ',', 'm'],
    'l': ['k', 'o', 'p', ';', '.', ','],
    'z': ['a', 's', 'x'],
    'x': ['z', 's', 'd', 'c'],
    'c': ['x', 'd', 'f', 'v'],
    'v': ['c', 'f', 'g', 'b'],
    'b': ['v', 'g', 'h', 'n'],
    'n': ['b', 'h', 'j', 'm'],
    'm': ['n', 'j', 'k', ','],
    '1': ['2', 'q'],
    '2': ['1', '3', 'q', 'w'],
    '3': ['2', '4', 'w', 'e'],
    '4': ['3', '5', 'e', 'r'],
    '5': ['4', '6', 'r', 't'],
    '6': ['5', '7', 't', 'y'],
    '7': ['6', '8', 'y', 'u'],
    '8': ['7', '9', 'u', 'i'],
    '9': ['8', '0', 'i', 'o'],
    '0': ['9', '-', 'o', 'p'],
    '-': ['0', '=', 'p', '['],
    '=': ['-', ']'],
    ';': ['l', 'p', '\'', '/'],
    '\'': [';', '[', ']'],
    ',': ['m', 'k', 'l', '.'],
    '.': [',', 'l', ';', '/'],
    '/': ['.', ';', '\''],
    ' ': ['c', 'v', 'b', 'n', 'm'],
  };

  /// Returns an adjacent key on a standard physical QWERTY keyboard for typos
  static String? getAdjacentKey(String char) {
    final lower = char.toLowerCase();
    final neighbors = _qwertyAdjacent[lower];
    if (neighbors == null || neighbors.isEmpty) return null;

    final picked = (neighbors..shuffle()).first;
    // Preserve case if original was uppercase
    if (char != lower) {
      return picked.toUpperCase();
    }
    return picked;
  }

  /// Maps an ASCII character to a standard USB HID keystroke (modifier, keyCode)
  static HidKeyStroke? charToKeyStroke(String char) {
    if (char.isEmpty) return null;
    final codeUnit = char.codeUnitAt(0);

    // Enter / Return
    if (char == '\n' || char == '\r') {
      return HidKeyStroke.enter;
    }
    // Tab
    if (char == '\t') {
      return HidKeyStroke.tab;
    }
    // Space
    if (char == ' ') {
      return HidKeyStroke.space;
    }

    // Lowercase letters a - z (HID 0x04 - 0x1D)
    if (codeUnit >= 97 && codeUnit <= 122) {
      return HidKeyStroke(modNone, 0x04 + (codeUnit - 97));
    }

    // Uppercase letters A - Z (HID 0x04 - 0x1D with Shift)
    if (codeUnit >= 65 && codeUnit <= 90) {
      return HidKeyStroke(modShift, 0x04 + (codeUnit - 65));
    }

    // Numbers 1 - 9 (HID 0x1E - 0x26)
    if (codeUnit >= 49 && codeUnit <= 57) {
      return HidKeyStroke(modNone, 0x1E + (codeUnit - 49));
    }
    // Number 0 (HID 0x27)
    if (char == '0') {
      return const HidKeyStroke(modNone, 0x27);
    }

    // Standard Shifted Symbols on Numbers
    switch (char) {
      case '!':
        return const HidKeyStroke(modShift, 0x1E); // Shift + 1
      case '@':
        return const HidKeyStroke(modShift, 0x1F); // Shift + 2
      case '#':
        return const HidKeyStroke(modShift, 0x20); // Shift + 3
      case r'$':
        return const HidKeyStroke(modShift, 0x21); // Shift + 4
      case '%':
        return const HidKeyStroke(modShift, 0x22); // Shift + 5
      case '^':
        return const HidKeyStroke(modShift, 0x23); // Shift + 6
      case '&':
        return const HidKeyStroke(modShift, 0x24); // Shift + 7
      case '*':
        return const HidKeyStroke(modShift, 0x25); // Shift + 8
      case '(':
        return const HidKeyStroke(modShift, 0x26); // Shift + 9
      case ')':
        return const HidKeyStroke(modShift, 0x27); // Shift + 0

      // Punctuation & Brackets
      case '-':
        return const HidKeyStroke(modNone, 0x2D);
      case '_':
        return const HidKeyStroke(modShift, 0x2D);
      case '=':
        return const HidKeyStroke(modNone, 0x2E);
      case '+':
        return const HidKeyStroke(modShift, 0x2E);
      case '[':
        return const HidKeyStroke(modNone, 0x2F);
      case '{':
        return const HidKeyStroke(modShift, 0x2F);
      case ']':
        return const HidKeyStroke(modNone, 0x30);
      case '}':
        return const HidKeyStroke(modShift, 0x30);
      case '\\':
        return const HidKeyStroke(modNone, 0x31);
      case '|':
        return const HidKeyStroke(modShift, 0x31);
      case ';':
        return const HidKeyStroke(modNone, 0x33);
      case ':':
        return const HidKeyStroke(modShift, 0x33);
      case '\'':
        return const HidKeyStroke(modNone, 0x34);
      case '"':
        return const HidKeyStroke(modShift, 0x34);
      case '`':
        return const HidKeyStroke(modNone, 0x35);
      case '~':
        return const HidKeyStroke(modShift, 0x35);
      case ',':
        return const HidKeyStroke(modNone, 0x36);
      case '<':
        return const HidKeyStroke(modShift, 0x36);
      case '.':
        return const HidKeyStroke(modNone, 0x37);
      case '>':
        return const HidKeyStroke(modShift, 0x37);
      case '/':
        return const HidKeyStroke(modNone, 0x38);
      case '?':
        return const HidKeyStroke(modShift, 0x38);
      default:
        return null;
    }
  }
}
