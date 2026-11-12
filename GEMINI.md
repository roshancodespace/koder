<!-- GSD:project-start source:PROJECT.md -->

## Project

**VS Code Companion System**

A developer companion system consisting of an Android companion application (`companion-app/`) built with Flutter and a minimal VS Code extension (`vscode-extension/`) built with TypeScript. The Android application functions as an external keyboard and command pad using Bluetooth HID to send low-latency keystrokes and shortcuts to the workstation, while communicating over WebSocket with the VS Code extension for editor state synchronization, context awareness, and safe workspace operations.

**Core Value:** Enable low-latency, context-aware command execution and workspace manipulation directly from an Android companion device via Bluetooth HID shortcuts and structured WebSocket telemetry, strictly bounded by safe workspace APIs and without autonomous code generation.

### Constraints

- **Tech Stack**: Flutter (Android only) + Kotlin Platform Channel, TypeScript (VS Code Extension API).
- **Workspace Structure**: Strictly two directories: `companion-app/` and `vscode-extension/`.
- **Bluetooth HID**: Mandatory standard HID Keyboard descriptor; no Accessibility Service workarounds.
- **Safety**: No implicit overwrite of existing files; no path traversal outside active workspace root.
- **CI/CD**: Fully independent `.github/workflows/ci.yml` and `.github/workflows/release.yml` in each subproject.

<!-- GSD:project-end -->

<!-- GSD:stack-start source:research/STACK.md -->

## Technology Stack

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

# pubspec.yaml dependencies

### VS Code Extension (`vscode-extension/`)

# Core dependencies

# Dev dependencies

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

- Use Loopback Mode: Android connects to `ws://127.0.0.1:38848`.
- Execute `adb reverse tcp:38848 tcp:38848` on host.
- Zero network exposure, zero firewall issues, minimal latency.
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

<!-- GSD:stack-end -->

<!-- GSD:conventions-start source:CONVENTIONS.md -->

## Conventions

Conventions not yet established. Will populate as patterns emerge during development.
<!-- GSD:conventions-end -->

<!-- GSD:architecture-start source:ARCHITECTURE.md -->

## Architecture

Architecture not yet mapped. Follow existing patterns found in the codebase.
<!-- GSD:architecture-end -->

<!-- GSD:skills-start source:skills/ -->

## Project Skills

No project skills found. Add skills to any of: `.agents/skills/`, `.agents/skills/`, `.cursor/skills/`, `.github/skills/`, or `.codex/skills/` with a `SKILL.md` index file.
<!-- GSD:skills-end -->

<!-- GSD:workflow-start source:GSD defaults -->

## GSD Workflow Enforcement

Before using Edit, Write, or other file-changing tools, start work through a GSD command so planning artifacts and execution context stay in sync.

Use these entry points:
- `/gsd-fast` for a trivial task inline, with no subagents and no PLAN.md
- `/gsd-quick` for small fixes, doc updates, and ad-hoc tasks
- `/gsd-debug` for investigation and bug fixing
- `/gsd-execute-phase` for planned phase work

Do not make direct repo edits outside a GSD workflow unless the user explicitly asks to bypass it.
<!-- GSD:workflow-end -->

<!-- GSD:profile-start -->

## Developer Profile

> Profile not yet configured. Run `/gsd-profile-user` to generate your developer profile.
> This section is managed by `generate-claude-profile` -- do not edit manually.
<!-- GSD:profile-end -->
