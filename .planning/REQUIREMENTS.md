# Requirements: VS Code Companion System

**Defined:** 2026-11-12
**Core Value:** Enable low-latency, context-aware command execution and workspace manipulation directly from an Android companion device via Bluetooth HID shortcuts and structured WebSocket telemetry, strictly bounded by safe workspace APIs and without autonomous code generation.

## v1 Requirements

### Bluetooth HID & Native Android Foundation

- [ ] **HID-01**: Android application initializes `BluetoothAdapter` and registers as a Bluetooth HID Device using `BluetoothHidDevice` (API 28+).
- [ ] **HID-02**: Native Kotlin platform channel manages Service Discovery Protocol (SDP) keyboard record settings, QoS, and HID callbacks.
- [ ] **HID-03**: App transmits standard 8-byte boot keyboard input reports (modifier byte + keycodes) followed immediately by all-zero release reports.
- [ ] **HID-04**: App checks `BluetoothProfile.HID_DEVICE` support defensively and reports clear diagnostic status if the OEM hardware/ROM disables HID Device mode.
- [ ] **HID-05**: Android Foreground Service (`foregroundServiceType="connectedDevice"`) runs with a persistent notification during active sessions to prevent OS background termination.

### VS Code Extension & Safe Workspace Operations

- [x] **EXT-01**: Extension initializes in TypeScript with minimal dependencies, utilizing the official VS Code Extension API.
- [ ] **EXT-02**: Extension monitors and emits real-time editor state changes: active document URI, language ID, cursor position, selection range, and diagnostic error/warning counts.
- [ ] **EXT-03**: Extension provides a floating command workflow using native `vscode.window.showInputBox` and `vscode.window.createQuickPick` triggered by keyboard shortcut or companion action.
- [ ] **EXT-04**: Path validator normalizes inputs using `vscode.Uri.joinPath` and rejects any path attempting traversal outside active `workspace.workspaceFolders`.
- [ ] **EXT-05**: Extension checks file existence with `vscode.workspace.fs.stat` and strictly prevents implicit overwrites, returning structured errors on collision.
- [ ] **EXT-06**: Extension recursively creates missing parent directories via `vscode.workspace.fs.createDirectory` and creates files via `vscode.workspace.fs.writeFile`, opening the new file in the active editor.

### Networking & Versioned Protocol

- [ ] **NET-01**: Extension hosts an embedded WebSocket server defaulting to loopback (`127.0.0.1:38848`), accessible over USB via `adb reverse`.
- [ ] **NET-02**: Android client connects to WebSocket server with automatic reconnection, heartbeat/ping-pong monitoring, and connection state reporting.
- [ ] **NET-03**: Protocol defines a versioned JSON envelope (`version`, `id`, `type`, `name`, `payload`, `timestamp`) with request-response correlation and error codes.
- [ ] **NET-04**: Optional LAN mode allows binding to local network interface with a user-configured or dynamically generated pairing token/PIN required during connection handshake.

### Project Management & Persistence

- [ ] **PROJ-01**: Android app imports projects from local directory, local ZIP file, remote ZIP URL, and GitHub repository archive.
- [ ] **PROJ-02**: Android app displays a nested hierarchical file explorer supporting directory expansion and file selection.
- [ ] **PROJ-03**: File tree supports recursive parent-to-child inclusion inheritance and explicit exclusion overrides (e.g., ignoring `.git` or build directories).
- [ ] **PROJ-04**: SQLite database persists imported projects, tree hierarchies, exclusion rules, connection profiles, session histories, and error logs.

### Companion UI & Material 3 Experience

- [x] **UI-01**: Flutter application provides a clean Material 3 design supporting dynamic light and dark themes.
- [ ] **UI-02**: UI displays a persistent connection badge (Bluetooth HID status and WebSocket status) and real-time editor diagnostic counters.
- [ ] **UI-03**: UI organizes features into a clean navigation layout: Connection Controller, Editor Overview, Quick Commands Pad, and Project Explorer.
- [ ] **UI-04**: Non-blocking asynchronous state architecture ensures the UI remains responsive during Bluetooth events, network retries, and file imports.

### Build, CI/CD & Release Automation

- [x] **CI-01**: `companion-app` includes `.github/workflows/ci.yml` running Flutter formatting, static analysis (`flutter analyze`), unit tests (`flutter test`), and APK debug compilation.
- [x] **CI-02**: `vscode-extension` includes `.github/workflows/ci.yml` running TypeScript compilation (`tsc`), ESLint, unit/extension tests, and VSIX packaging verification.
- [ ] **REL-01**: `companion-app` includes `.github/workflows/release.yml` triggered by version tags (`companion-v*`) or manual dispatch to build release APKs with SHA256 checksums and GitHub Release publishing.
- [ ] **REL-02**: `vscode-extension` includes `.github/workflows/release.yml` triggered by version tags (`extension-v*`) or manual dispatch to package production VSIX artifacts with SHA256 checksums and GitHub Release publishing.

## v2 Requirements

### Advanced Automation & Configuration

- **ADV-01**: User-customizable keyboard shortcut macro builder on Android companion app.
- **ADV-02**: Biometric authentication gate (fingerprint/face) for accessing sensitive imported projects on Android.
- **ADV-03**: Multi-root and multi-window VS Code workspace selector from companion app.
- **ADV-04**: QR code scanning on Android for instant Wi-Fi LAN pairing with VS Code extension.

## Out of Scope

| Feature | Reason |
|---------|--------|
| Autonomous AI Code Generation | The extension must never act as an AI coding agent or independently generate code; it is strictly an editor bridge, telemetry provider, and safe workspace operator. |
| Accessibility Service Input Simulation | Accessibility services introduce latency, cannot emit true hardware scancodes, and violate the non-negotiable Bluetooth HID requirement. |
| Monorepo Build Tools | Monorepo tools (Nx, Turborepo, Melos) introduce unnecessary cross-language coupling and brittle build pipelines. Strictly two independent project roots. |
| Desktop & iOS Flutter Targets | The companion application specifically targets Android. |
| Unauthenticated 0.0.0.0 Exposure | Exposing workspace file creation and command execution without authentication over public/shared networks is a severe security risk. |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| HID-01 | Phase 2 | Pending |
| HID-02 | Phase 2 | Pending |
| HID-03 | Phase 2 | Pending |
| HID-04 | Phase 2 | Pending |
| HID-05 | Phase 2 | Pending |
| EXT-01 | Phase 1 | Complete |
| EXT-02 | Phase 3 | Pending |
| EXT-03 | Phase 3 | Pending |
| EXT-04 | Phase 3 | Pending |
| EXT-05 | Phase 3 | Pending |
| EXT-06 | Phase 3 | Pending |
| NET-01 | Phase 4 | Pending |
| NET-02 | Phase 4 | Pending |
| NET-03 | Phase 4 | Pending |
| NET-04 | Phase 4 | Pending |
| PROJ-01 | Phase 5 | Pending |
| PROJ-02 | Phase 5 | Pending |
| PROJ-03 | Phase 5 | Pending |
| PROJ-04 | Phase 5 | Pending |
| UI-01 | Phase 1 | Complete |
| UI-02 | Phase 5 | Pending |
| UI-03 | Phase 5 | Pending |
| UI-04 | Phase 5 | Pending |
| CI-01 | Phase 1 | Complete |
| CI-02 | Phase 1 | Complete |
| REL-01 | Phase 6 | Pending |
| REL-02 | Phase 6 | Pending |

**Coverage:**
- v1 requirements: 26 total
- Mapped to phases: 26
- Unmapped: 0 ✓

---
*Requirements defined: 2026-11-12*
*Last updated: 2026-11-12 after initialization*

