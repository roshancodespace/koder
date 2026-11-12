# Feature Research

**Domain:** Android Companion Application & VS Code Extension
**Researched:** 2026-11-12
**Confidence:** HIGH

## Feature Landscape

### Table Stakes (Users Expect These)

Features users assume exist. Missing these = product feels incomplete.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Bluetooth HID Keyboard Emulation | Core mechanism to send keystrokes and hotkeys to host without lag or third-party host software. | HIGH | Needs native Kotlin integration with `BluetoothHidDevice`, standard 8-byte boot reports, key press/release cycling. |
| Bidirectional WebSocket Telemetry | Syncs editor state (active file, cursor, workspace info) to companion UI in real time. | MEDIUM | Extension hosts WebSocket server; companion app connects with auto-reconnection and heartbeat. |
| Context-Aware File Creation | Floating command triggered by Android shortcut to create nested files safely. | MEDIUM | Android sends hotkey; VS Code opens QuickPick/InputBox; validates path; creates missing parents recursively; opens new file. |
| Safe Workspace Operations | Prevents overwriting files or traversing outside workspace. | MEDIUM | Canonical path normalization, verifying URI starts with workspace folder URI, checking file existence before writing. |
| Android Material 3 UI | Clean, readable, responsive interface matching modern Android standards. | LOW | Flutter Material 3 with automatic light/dark theme adaptation, non-blocking asynchronous UI. |
| SQLite Local Persistence | Retains imported projects, file tree selections, and connection settings across app restarts. | MEDIUM | Relational tables for projects, files, connection profiles, session histories, and error logs. |
| Foreground Service for Persistent Active Session | Keeps Bluetooth HID and WebSocket connections active when app is minimized. | MEDIUM | Android 14+ compliant `connectedDevice` foreground service with clear notification and graceful stop action. |

### Differentiators (Competitive Advantage)

Features that set the product apart. Not required, but valuable.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Multi-Source Project Import | Import codebases via local folder, local ZIP, remote ZIP URL, or GitHub repository. | MEDIUM | Unifies project discovery; allows reviewing codebase trees directly from mobile. |
| Hierarchical File Selection & Explicit Exclusions | Select entire folder trees while explicitly excluding specific subfolders/files (e.g. `node_modules`, `.git`). | MEDIUM | Tri-state tree selection logic persisted in SQLite. |
| Real-time Diagnostic Counters | Displays active workspace error and warning counts on the companion screen. | LOW | Subscribes to `vscode.languages.onDidChangeDiagnostics` and streams aggregated counts over WebSocket. |
| Zero-Config USB Loopback Mode | Instant rock-solid connection over USB cable via `adb reverse` without Wi-Fi pairing headaches. | LOW | Automatic detection of loopback availability at `127.0.0.1:38848`. |
| Preshared Token / PIN for LAN Pairing | Protects developer machine from unauthorized network access when connecting over Wi-Fi. | MEDIUM | Ephemeral or configured token required during WebSocket handshake. |

### Anti-Features (Commonly Requested, Often Problematic)

Features that seem good but create problems.

| Feature | Why Requested | Why Problematic | Alternative |
|---------|---------------|-----------------|-------------|
| AI Code Autocompletion / Generation in Extension | Appears to add "modern AI power" to the companion. | Violates non-negotiable architectural boundaries; turns extension into an uncontrolled coding agent; bloats extension dependencies; risks security. | Keep the extension strictly an editor bridge, context provider, and workspace validator. Keystrokes originate from user-initiated Bluetooth HID. |
| Accessibility Service for Keystroke Injection | Avoids native Bluetooth HID complexity. | Unreliable scan-code delivery, OS lag, flagged as potential malware/keylogger by security suites, requires enabling accessibility settings. | Native `BluetoothHidDevice` API registering standard HID keyboard descriptor. |
| Monorepo with Shared Code / Tooling | Code sharing between app and extension. | Subprojects have entirely different runtimes (Dart/Flutter vs TypeScript/Node.js) and release cadences (APK vs VSIX). Monorepo tooling adds brittle complexity. | Maintain strictly two independent project directories: `companion-app/` and `vscode-extension/`. |
| Implicit File Overwriting on Creation | Quick replacement of existing files. | High risk of accidental data loss without git review. | Explicitly detect file collision and abort with a structured error message (`FILE_ALREADY_EXISTS`). |
| Path Traversal Outside Active Workspace | Accessing config files or libraries in parent directories. | Severe security vulnerability allowing malicious commands to mutate arbitrary system files. | Strict path validation verifying the target URI is contained within active `vscode.workspace.workspaceFolders`. |

## Feature Dependencies

```
[Android Bluetooth HID Device] ──triggers──> [VS Code Hotkey Workflow]
                                                     │
                                                     ▼
                                        [QuickPick / InputBox UI]
                                                     │
                                                     ▼
                                        [Path Traversal & Overwrite Validation]
                                                     │
                                                     ▼
                                        [Recursive Directory & File Creation]
                                                     │
                                                     ▼
[WebSocket Telemetry Server] ──streams result──> [Android Companion UI & Persistence]
```

### Dependency Notes

- **Hotkeys require Bluetooth HID:** The shortcut that triggers the VS Code QuickPick/InputBox workflow must be transmitted via Bluetooth HID scan codes, not through an arbitrary WebSocket command injection, preserving user-command attribution.
- **File Creation requires WebSocket feedback:** Once VS Code validates and creates the file, it emits a structured response over WebSocket so Android updates its recent operations history.
- **Foreground Service requires Bluetooth HID Active Session:** Android will terminate background Bluetooth HID registrations unless wrapped in a valid Foreground Service (`connectedDevice` type).

## MVP Definition

### Launch With (v1)

- [ ] **HID Keyboard Profile**: Register `BluetoothHidDevice` and send standard modifier + keycode combinations (e.g., `Ctrl+Shift+P`, custom shortcuts).
- [ ] **WebSocket Server & Loopback Client**: Extension hosts WS server at `127.0.0.1:38848`; Flutter client connects over loopback with heartbeat.
- [ ] **Editor Awareness**: Extension pushes active file, language ID, cursor position, selection range, and diagnostics over WebSocket.
- [ ] **Context-Aware File Creation**: Bluetooth HID triggers shortcut -> VS Code QuickPick/InputBox opens -> user enters nested path -> path validated -> parent directories created -> file opened -> WebSocket result emitted.
- [ ] **Safe Workspace Operations**: Reject any path outside active workspace; reject file creation if target file already exists.
- [ ] **Android Material 3 UI**: Clean dashboard displaying connection state, editor status, quick action buttons, and project explorer.
- [ ] **Project Management**: Import local folder, local ZIP, remote ZIP URL, GitHub repo; view nested file tree with selection state.
- [ ] **SQLite Persistence**: Store projects, file trees, selections, and connection settings.
- [ ] **Independent CI/CD**: GitHub Actions workflows for format, lint, test, APK build, and VSIX packaging.

### Add After Validation (v1.x)

- [ ] **Authenticated LAN Mode**: Secure pairing PIN/QR code generation in VS Code and token-based LAN WebSocket connections.
- [ ] **Custom Shortcut Macro Editor**: Companion UI allowing users to configure custom keyboard shortcut buttons.

### Future Consideration (v2+)

- [ ] **Biometric Lock on Companion App**: Securing sensitive codebase access on Android.
- [ ] **Multi-Window VS Code Awareness**: Managing multiple workspace instances simultaneously.

## Feature Prioritization Matrix

| Feature | User Value | Implementation Cost | Priority |
|---------|------------|---------------------|----------|
| Bluetooth HID Keyboard Service | HIGH | HIGH | P1 |
| WebSocket Telemetry & Protocol | HIGH | MEDIUM | P1 |
| Context-Aware File Creation Workflow | HIGH | MEDIUM | P1 |
| Workspace Path Traversal Prevention | HIGH | LOW | P1 |
| SQLite Project & State Persistence | HIGH | MEDIUM | P1 |
| Multi-Source Project Explorer | MEDIUM | MEDIUM | P1 |
| Independent CI/CD Workflows | HIGH | MEDIUM | P1 |
| Authenticated LAN Connectivity | MEDIUM | MEDIUM | P2 |
| Custom Macro Configuration | MEDIUM | LOW | P2 |

---
*Feature research for: VS Code Companion System*
*Researched: 2026-11-12*
