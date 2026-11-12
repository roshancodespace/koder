# Stack Research

**Domain:** Android Companion Application & Minimal VS Code Extension
**Researched:** 2026-11-12
**Confidence:** HIGH

## Recommended Stack

### Core Technologies

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| Flutter (Dart SDK) | 3.41.9 (Dart 3.11.5) | Android Companion App UI & Client Logic | Native performance, declarative Material 3 widgets, reactive state management, seamless platform channel interop with Kotlin. |
| Kotlin | 1.9+ / 2.0+ | Android Native Platform Channel (`BluetoothHidDevice`) | Required for Android Bluetooth HID Device profile (API 28+), foreground service lifecycle, and low-level byte buffer manipulation. |
| TypeScript | ~5.8 | VS Code Extension implementation | First-class type safety for the official VS Code API (`@types/vscode`), clean async/await patterns, minimal runtime overhead. |
| VS Code Extension API | ^1.96.0 | Editor Awareness, QuickPick/InputBox, Filesystem ops | Native integration with VS Code workbench, window events, diagnostics, and sandbox-safe `workspace.fs`. |
| `ws` (Node.js) | ^8.18.0 | Extension WebSocket Server | Battle-tested, zero-external-dependency, low-latency WebSocket server for Node.js runtime inside VS Code extensions. |
| `web_socket_channel` (Dart) | ^3.0.1 | Flutter WebSocket Client | Official Dart team cross-platform stream-based WebSocket client with stream transformations and reconnect resilience. |

### Supporting Libraries

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `sqflite` + `path` (Dart) | ^2.4.1 / ^1.9.0 | Local SQLite Persistence on Android | Storing imported projects, hierarchical file exclusions, connection history, and audit logs. |
| `flutter_riverpod` (Dart) | ^2.6.1 | State Management in Flutter | Compile-safe dependency injection, reactive state binding for connection status, active files, and project explorer tree. |
| `archive` (Dart) | ^4.0.2 | ZIP archive extraction & compression | Handling local ZIP archive and remote ZIP URL project imports without external system binaries. |
| `http` (Dart) | ^1.3.0 | Remote project downloading | Fetching remote ZIP files or GitHub repository archives over HTTPS. |
| `crypto` (Dart) & `crypto` (Node.js) | ^3.0.6 / Node builtin | Pairing tokens & HMAC validation | Securing LAN WebSocket connections, generating preshared keys (PSKs), and computing payload checksums. |
| `@vscode/test-electron` / `@vscode/test-cli` | ^2.4.1 / ^0.0.10 | VS Code Extension Integration Tests | Running headless integration tests inside a live VS Code instance. |

### Development Tools

| Tool | Purpose | Notes |
|------|---------|-------|
| `adb` (Android Debug Bridge) | Reverse port forwarding & device testing | `adb reverse tcp:38848 tcp:38848` enables zero-config loopback over USB. |
| `fnm` (Fast Node Manager) | Node.js version management on host | Host Node.js v24.21.0 active. |
| `pnpm` | Package manager for VS Code Extension | High speed, deterministic dependency locking, low disk overhead. |
| `fvm` / Flutter CLI | Flutter SDK management | Flutter stable 3.41.9. |
| `vsce` (`@vscode/vsce`) | VS Code extension packaging | Generates VSIX artifacts for CI/release. |

## Installation

### Android Companion App (`companion-app/`)

```yaml
# pubspec.yaml dependencies
dependencies:
  flutter:
    sdk: flutter
  flutter_riverpod: ^2.6.1
  sqflite: ^2.4.1
  path: ^1.9.0
  web_socket_channel: ^3.0.1
  archive: ^4.0.2
  http: ^1.3.0
  crypto: ^3.0.6

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^5.0.0
```

### VS Code Extension (`vscode-extension/`)

```bash
# Core dependencies
pnpm add ws

# Dev dependencies
pnpm add -D typescript @types/node @types/vscode @types/ws @vscode/test-cli @vscode/test-electron eslint @typescript-eslint/parser @typescript-eslint/eslint-plugin
```

## Alternatives Considered

| Recommended | Alternative | When to Use Alternative |
|-------------|-------------|-------------------------|
| Native `BluetoothHidDevice` (Kotlin platform channel) | Accessibility Service / Virtual Soft Keyboard | Never for this system. Mandated requirement is true hardware Bluetooth HID; Accessibility Services introduce latency, require intrusive permissions, and cannot send standard OS-level hardware scan codes. |
| `ws` (builtin Node.js server) | Socket.IO or gRPC | Socket.IO adds heavy client and server dependencies and unnecessary polling overhead. gRPC requires complex HTTP/2 framing and proto compilation. Standard WebSocket with lightweight JSON-RPC envelope is optimal. |
| `sqflite` (SQLite) | Hive / Isar / SharedPreferences | SQLite supports complex hierarchical queries (nested folder exclusions, parent-child inheritance) and relational schema migrations required for project management. |
| `workspace.fs` API | Node.js `fs` / `fs/promises` | Node.js `fs` does not respect VS Code virtual filesystems, multi-root workspaces, or VS Code file event watchers. `workspace.fs` is mandatory for safety. |
| Independent subprojects | Monorepo (Nx / Turborepo / Melos) | Excluded by non-negotiable workspace requirements. Independent project directories provide clean separation and independent CI/CD. |

## What NOT to Use

| Avoid | Why | Use Instead |
|-------|-----|-------------|
| Monorepo orchestration tools (Lerna, Nx, Melos) | Unnecessary cross-project coupling, complex build caching, and bloated CI scripts. | Independent project directories (`companion-app/` and `vscode-extension/`). |
| Accessibility Service for input simulation | Fails non-negotiable requirements; unreliable scan-code mapping; perceived as malware by OS. | Native `BluetoothHidDevice` API. |
| AI code completion or autonomous file generation in extension | Breaks core architectural responsibility boundary; extension must remain a minimal editor bridge. | Extension restricted to editor awareness, QuickPick workflows, path validation, and safe workspace operations. |
| Unauthenticated `0.0.0.0` WebSocket binding | Exposes the developer's workspace and command execution to any device on the local network. | Default to `127.0.0.1` (loopback / USB adb reverse). Require explicit pairing token/PSK for LAN mode. |
| Shell command file creation (`mkdir`, `touch`) | Vulnerable to shell injection, platform path delimiter mismatches, and lacks VS Code event hooks. | Official `vscode.workspace.fs` API. |

## Stack Patterns by Variant

**If USB-connected Android device:**
- Use Loopback Mode: Android connects to `ws://127.0.0.1:38848`.
- Execute `adb reverse tcp:38848 tcp:38848` on host.
- Zero network exposure, zero firewall issues, minimal latency.

**If Wi-Fi / Local Area Network (LAN):**
- Extension binds to local interface.
- Extension generates a cryptographically random pairing PIN/token displayed in VS Code status bar.
- Android companion app scans QR code or enters pairing PIN to establish authenticated WebSocket session.

## Version Compatibility

| Component | Target Version | Compatibility Notes |
|-----------|----------------|---------------------|
| Android OS | Android 9.0 (API 28) - Android 15 (API 35) | `BluetoothHidDevice` available from API 28. Requires `FOREGROUND_SERVICE_CONNECTED_DEVICE` permission on Android 14+ (API 34+). |
| VS Code Engine | ^1.90.0 | Compatible with modern VS Code releases and forks (Cursor, VSCodium, Antigravity). |
| Node.js Runtime | Node 20.x / 22.x / 24.x | Standard LTS versions supported by VS Code's internal Electron Node runtime. |
| Dart / Flutter | Flutter 3.24+ / Dart 3.5+ | Tested with Flutter 3.41.9 and Dart 3.11.5. |

## Sources

- Android Developers: `android.bluetooth.BluetoothHidDevice` Reference
- Android 14 Changes: Foreground Service Types (`connectedDevice`)
- VS Code Extension API: `vscode.workspace.fs`, `vscode.window.createQuickPick`
- USB HID Usage Tables v1.5 (Keyboard/Keypad Page 0x07)

---
*Stack research for: VS Code Companion System*
*Researched: 2026-11-12*
