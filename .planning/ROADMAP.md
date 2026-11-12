# Roadmap: VS Code Companion System

## Overview

The VS Code Companion System is developed as two completely independent subprojects (`companion-app/` and `vscode-extension/`) that collaborate to turn an Android device into a low-latency hardware keyboard companion and editor telemetry monitor for VS Code. The roadmap proceeds in 6 phased milestones: beginning with independent workspace scaffolding and CI pipelines, verifying the native Android Bluetooth HID Device profile and lifecycle, implementing the VS Code extension with safe workspace operations, establishing the versioned WebSocket protocol engine, building the Android companion UI with multi-source project management and SQLite persistence, and culminating in full end-to-end integration and GitHub Actions release automation.

## Phases

- [x] **Phase 1: Project Scaffolding, Tooling & CI Setup** - Bootstrap independent `companion-app/` and `vscode-extension/` roots with formatting, linting, and CI pipelines.
- [x] **Phase 2: Android Bluetooth HID Platform Channel & Foreground Lifecycle** - Native Kotlin `BluetoothHidDevice` implementation, scancode mapping, capability probing, and `connectedDevice` foreground service.
- [ ] **Phase 3: VS Code Extension Core, Editor Awareness & Safe Workspace Operations** - TypeScript extension, editor event telemetry, QuickPick/InputBox workflows, path traversal defense, and collision-safe file creation.
- [ ] **Phase 4: Bi-Directional WebSocket Protocol & Networking Engine** - Extension WebSocket server, Android client, versioned JSON-RPC envelope, loopback USB mode, and authenticated LAN pairing.
- [ ] **Phase 5: Android Companion UI & Project Management Engine** - Material 3 companion interface, live status dashboard, multi-source project importer, hierarchical tree with exclusions, and SQLite persistence.
- [ ] **Phase 6: End-to-End Integration, Release Automation & Verification** - Full workflow validation, independent GitHub Actions release workflows (APK & VSIX), SHA256 checksums, and documentation.

## Phase Details

### Phase 1: Project Scaffolding, Tooling & CI Setup
**Goal**: Establish clean, decoupled subproject roots (`companion-app/` and `vscode-extension/`) with build tooling, static analysis, test runners, and independent GitHub Actions CI workflows.
**Depends on**: Nothing (first phase)
**Requirements**: [EXT-01, UI-01, CI-01, CI-02]
**Success Criteria**:
  1. `companion-app/` directory initializes a clean Flutter 3.x project with Material 3 theming, running `flutter analyze` and `flutter test` with zero warnings.
  2. `vscode-extension/` directory initializes a clean TypeScript extension with strict typing, running `tsc --noEmit`, ESLint, and test suite cleanly.
  3. `.github/workflows/ci.yml` in `companion-app/` runs formatting, analysis, testing, and APK compilation on push/PR.
  4. `.github/workflows/ci.yml` in `vscode-extension/` runs compilation, linting, testing, and VSIX packaging validation on push/PR.
  5. Both projects remain completely isolated with no monorepo tooling or shared package files.
**Plans**: 2 plans

Plans:
- [x] 01-01-PLAN.md — Bootstrap companion-app with Flutter Material 3 skeleton, dependencies, lint rules, and .github/workflows/ci.yml
- [x] 01-02-PLAN.md — Bootstrap vscode-extension with TypeScript configuration, package manifest, test runner, and .github/workflows/ci.yml

### Phase 2: Android Bluetooth HID Platform Channel & Foreground Lifecycle
**Goal**: Implement and verify the native Kotlin Bluetooth HID Device platform channel, sending standard keyboard scan codes and maintaining an active session via an Android 14+ compliant foreground service.
**Depends on**: Phase 1
**Requirements**: [HID-01, HID-02, HID-03, HID-04, HID-05]
**Success Criteria**:
  1. Kotlin platform channel registers as a `BluetoothHidDevice` using a standard 8-byte boot keyboard report descriptor.
  2. App checks `BluetoothProfile.HID_DEVICE` support defensively and surfaces clear diagnostics if OEM hardware/ROM disables HID Device mode.
  3. App transmits modifier and scancode byte combinations, followed immediately by all-zero release reports to prevent repeating/stuck keys.
  4. Android Foreground Service with `foregroundServiceType="connectedDevice"` runs with a persistent notification to prevent background OS termination during active sessions.
  5. Session state transitions (disconnected, connecting, connected, error) are published across a Flutter `EventChannel`.
**Plans**: 2 plans

Plans:
- [x] 02-01-PLAN.md — Implement native Kotlin BluetoothKeyboardManager platform channel with SDP registration, scancode tables, and capability detection
- [x] 02-02-PLAN.md — Implement CompanionForegroundService (connectedDevice), notification channel, and Flutter Dart platform channel client

### Phase 3: VS Code Extension Core, Editor Awareness & Safe Workspace Operations
**Goal**: Implement the VS Code extension's event-driven editor telemetry, path traversal defense, and custom QuickPick/InputBox file creation workflow using `vscode.workspace.fs`.
**Depends on**: Phase 1
**Requirements**: [EXT-02, EXT-03, EXT-04, EXT-05, EXT-06]
**Success Criteria**:
  1. Extension listens to window/workspace events and computes real-time editor state (active file URI, language, cursor, selections, workspace folders, and diagnostic counts).
  2. Custom hotkey-triggered command workflow displays native VS Code QuickPick/InputBox for entering nested file paths.
  3. Path validator canonicalizes input using `vscode.Uri.joinPath` and rejects any path escaping `workspace.workspaceFolders`.
  4. File creator checks file existence via `workspace.fs.stat` and strictly prevents implicit overwrites, returning structured errors on collision.
  5. File creator recursively creates parent directories via `workspace.fs.createDirectory`, creates the file, and reveals it in the active editor.
**Plans**: 2 plans

Plans:
- [ ] 03-01-PLAN.md — Implement EditorMonitor and SafeWorkspaceManager (path traversal guard, collision detection, recursive directory/file creation)
- [ ] 03-02-PLAN.md — Implement floating QuickPick/InputBox command workflow and bind extension commands and shortcut contributions

### Phase 4: Bi-Directional WebSocket Protocol & Networking Engine
**Goal**: Implement the versioned bidirectional JSON-RPC messaging engine connecting the VS Code extension server and the Android companion client over loopback and authenticated LAN.
**Depends on**: Phase 2, Phase 3
**Requirements**: [NET-01, NET-02, NET-03, NET-04]
**Success Criteria**:
  1. Extension hosts an embedded WebSocket server listening on `127.0.0.1:38848` by default, reachable over USB via `adb reverse`.
  2. Android app connects to the extension WebSocket with auto-reconnection, heartbeat monitoring, and connection state reporting.
  3. Structured JSON-RPC protocol envelopes events (`editor.stateChanged`, `workspace.fileCreated`) and request/response calls with unique request IDs and error codes.
  4. Optional LAN mode binds to local network interfaces and enforces cryptographic pairing token / PIN verification during the connection handshake.
**Plans**: 2 plans

Plans:
- [ ] 04-01: Implement extension WebSocket server (`WebSocketServerManager`), session authenticator, and event broadcast engine.
- [ ] 04-02: Implement Dart WebSocket client service with auto-reconnect, message routing, and loopback/LAN connection controllers.

### Phase 5: Android Companion UI & Project Management Engine
**Goal**: Build the full Android Material 3 companion interface, live status dashboard, multi-source project importer, hierarchical file explorer with exclusion rules, and SQLite persistence.
**Depends on**: Phase 4
**Requirements**: [UI-02, UI-03, UI-04, PROJ-01, PROJ-02, PROJ-03, PROJ-04]
**Success Criteria**:
  1. Android app provides a responsive Material 3 UI with light/dark themes, connection status badges, editor state cards, and diagnostic tallies.
  2. Importer extracts projects from local directory trees, local ZIP files, remote ZIP URLs, and GitHub repository archives.
  3. Nested file explorer renders expandable directory trees with recursive parent-to-child selection and explicit child exclusions.
  4. SQLite database (`sqflite`) persists project metadata, file trees, exclusion rules, connection profiles, session histories, and error logs.
  5. UI operations remain non-blocking and asynchronous across all database and network tasks.
**Plans**: 3 plans

Plans:
- [ ] 05-01: Implement SQLite database schema, migrations, and repository layer for projects, files, exclusions, and settings.
- [ ] 05-02: Implement multi-source project importer (local folder, local ZIP, ZIP URL, GitHub repo) and hierarchical tree parser.
- [ ] 05-03: Implement companion UI screens: Connection Dashboard, Editor Overview, Shortcut Trigger Pad, and Project Explorer.

### Phase 6: End-to-End Integration, Release Automation & Verification
**Goal**: Validate the complete end-to-end user workflow across Bluetooth HID and WebSocket, enforce security and architectural boundaries, and implement independent GitHub Actions release pipelines producing verified APK and VSIX artifacts with checksums.
**Depends on**: Phase 5
**Requirements**: [REL-01, REL-02]
**Success Criteria**:
  1. Complete workflow verified: Android Bluetooth HID shortcut triggers VS Code QuickPick -> user inputs path -> path validated & created -> WebSocket confirmation arrives on Android.
  2. Architectural boundary verified: Extension operates strictly as an editor bridge and context provider; zero autonomous code generation; zero shell commands.
  3. `.github/workflows/release.yml` in `companion-app/` builds release APKs, calculates SHA256 checksums, and publishes GitHub releases on tag or manual dispatch.
  4. `.github/workflows/release.yml` in `vscode-extension/` packages production VSIX extensions, calculates SHA256 checksums, and publishes GitHub releases on tag or manual dispatch.
  5. Complete documentation produced: setup instructions, Bluetooth HID troubleshooting, ADB reverse usage, and security architecture.
**Plans**: 2 plans

Plans:
- [ ] 06-01: Perform end-to-end integration testing, boundary verification, and documentation.
- [ ] 06-02: Implement `.github/workflows/release.yml` in both projects with SHA256 checksum generation and release artifact automation.

## Progress

**Execution Order:**
Phases execute in numeric order: 1 → 2 → 3 → 4 → 5 → 6

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Project Scaffolding, Tooling & CI Setup | 2/2 | Complete | 2026-11-12 |
| 2. Android Bluetooth HID Platform Channel & Foreground Lifecycle | 2/2 | Complete | 2026-11-12 |
| 3. VS Code Extension Core, Editor Awareness & Safe Workspace Operations | 0/2 | Not started | - |
| 4. Bi-Directional WebSocket Protocol & Networking Engine | 0/2 | Not started | - |
| 5. Android Companion UI & Project Management Engine | 0/3 | Not started | - |
| 6. End-to-End Integration, Release Automation & Verification | 0/2 | Not started | - |

