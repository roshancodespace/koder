# Project Research Summary

**Project:** VS Code Companion System
**Domain:** Cross-Platform Developer Companion (Android Bluetooth HID + VS Code Extension)
**Researched:** 2026-11-12
**Confidence:** HIGH

## Executive Summary

The VS Code Companion System is a specialized developer utility bridging an Android companion device and the VS Code workstation environment. The system couples two distinct, independently developed subprojects: a Flutter-based Android application (`companion-app/`) and a minimal TypeScript VS Code extension (`vscode-extension/`).

The architecture strictly segregates responsibilities:
1. **The Android companion app** acts as an external hardware keyboard via the Android Bluetooth HID Device profile (`BluetoothHidDevice`), sending low-latency scan codes and shortcuts to the workstation OS. It also manages project imports, hierarchical file trees, SQLite persistence, and communication telemetry.
2. **The VS Code extension** acts as an editor state provider and safe workspace operator over WebSocket. It monitors active editor changes, cursor movements, and diagnostics, and hosts a custom QuickPick/InputBox command workflow for nested file/folder creation with strict path validation and collision safeguards.
3. **Crucial Responsibility Boundaries**: The extension must never act as an AI coding agent or autonomously generate code; keystrokes originate from user-initiated Bluetooth HID events; file operations strictly avoid implicit overwrites and path traversal outside workspace folders.

The core technical risks lie in Android OEM-specific Bluetooth HID driver availability, background lifecycle constraints on Android 14+ (requiring `FOREGROUND_SERVICE_CONNECTED_DEVICE`), and security boundaries on workspace filesystem mutations. By implementing strict capability probing, a dedicated foreground service, loopback-default WebSocket transport with token-based LAN pairing, and `workspace.fs` sandboxing, these risks are mitigated.

## Key Findings

### Recommended Stack

- **Android Companion App (`companion-app/`)**: Flutter 3.41.9 / Dart 3.11.5 with Material 3; Native Kotlin platform channels for `BluetoothHidDevice` (API 28+); `web_socket_channel` for telemetry; `sqflite` for relational persistence (projects, file trees, connection histories); `archive` and `http` for multi-source project importing.
- **VS Code Extension (`vscode-extension/`)**: TypeScript ~5.8; VS Code Extension API (`^1.96.0`); `ws` (^8.18.0) for lightweight zero-dependency WebSocket server; `@vscode/test-electron` and `@vscode/vsce` for testing and packaging.
- **CI / CD Pipelines**: Completely independent GitHub Actions in each subproject (`.github/workflows/ci.yml` and `release.yml`) for static analysis, unit/integration testing, artifact builds (APK and VSIX), and secure SHA256 release publishing.

### Expected Features

**Must Have (Table Stakes):**
- Hardware Bluetooth HID Keyboard profile (8-byte standard boot keyboard reports, key down/up cycling).
- Bidirectional WebSocket telemetry (editor awareness: active file, language, cursor, selection, diagnostics).
- Shortcut-triggered context-aware nested file creation via native VS Code QuickPick/InputBox.
- Safe workspace operations: recursive directory creation, collision detection (no implicit overwrites), and path traversal prevention.
- Android Material 3 UI with light/dark theme adaptation and non-blocking asynchronous state.
- Android SQLite persistence for projects, connection configs, session history, and error logs.
- Multi-source project import (local folder, local ZIP, ZIP URL, GitHub repo).
- Foreground service (`connectedDevice` type) for persistent active companion sessions.
- Independent GitHub Actions CI/CD with automated formatting, linting, testing, and release artifact generation.

**Should Have (Competitive / Differentiators):**
- Hierarchical tree explorer with recursive folder selection and explicit exclusions.
- Zero-config USB loopback mode (`127.0.0.1` via `adb reverse tcp:38848 tcp:38848`).
- Authenticated LAN mode with one-time pairing PIN / token displayed in VS Code.

**Defer (v2+):**
- Custom shortcut macro builder UI.
- Biometric lock on mobile companion app.
- Multi-window / multi-workspace simultaneous switching.

### Architecture Approach

The architecture maintains strict isolation:
- No monorepo tools, shared npm packages, or root-level build dependencies.
- Communication between mobile and host uses two distinct channels:
  - **Bluetooth HID (Outbound from Android to Host OS):** Sends hardware keyboard scancodes directly to the workstation window manager.
  - **WebSocket over TCP (Bidirectional between Android and Extension):** Streams JSON-RPC events, editor telemetry, and file creation results.
- File system mutations run strictly through `vscode.workspace.fs` and enforce canonical URI containment within `workspace.workspaceFolders`.

### Critical Pitfalls

1. **Android OEM Bluetooth HID Disablement:** Check `getProfileProxy` defensively and surface clear status in the UI if the device HAL does not support `HID_DEVICE`.
2. **Android 14+ Foreground Service Termination:** Enforce `FOREGROUND_SERVICE_CONNECTED_DEVICE` in manifest and request `POST_NOTIFICATIONS` runtime permission to prevent OS termination during active sessions.
3. **Workspace Traversal & Implicit Overwrite:** Canonicalize all user input with `vscode.Uri.joinPath`, assert path containment within the workspace, and assert `workspace.fs.stat` throws `FileNotFound` before file creation.
4. **WebSocket Network Exposure:** Bind to `127.0.0.1` by default; require cryptographically random pairing tokens when LAN mode is active.
5. **Stuck Key Scancodes:** Always emit an immediate all-zero release report after transmitting an HID scancode.

## Implications for Roadmap

The implementation should follow a layered, milestone-based structure that verifies feasibility early before expanding higher-level features:

### Phase 1: Project Scaffolding, Tooling & CI Setup
- **Rationale:** Establish the two independent directories (`companion-app/` and `vscode-extension/`), package configurations, linting, formatting, and GitHub Actions CI pipelines from day one.
- **Delivers:** Compiling Flutter app skeleton, compiling TypeScript extension skeleton, independent CI pipelines running on GitHub Actions.
- **Avoids:** Monorepo confusion and late CI integration surprises.

### Phase 2: Native Bluetooth HID Platform Channel & Android Lifecycle
- **Rationale:** De-risk the most critical hardware capability: verifying `BluetoothHidDevice` API, SDP registration, scancode transmission, and Android 14+ foreground service lifecycle.
- **Delivers:** Functional Kotlin `BluetoothHidDevice` bridge, scancode mapping for shortcuts, and `connectedDevice` foreground service.
- **Avoids:** Unverified assumptions about Bluetooth HID and background OS termination.

### Phase 3: Extension Core, Editor Awareness & Safe Workspace Operations
- **Rationale:** Build the VS Code extension core, editor event listeners, path validation engine, and the QuickPick/InputBox file creation workflow.
- **Delivers:** Extension activated in VS Code, event telemetry emitters, path traversal defense, recursive directory creation, and non-overwriting file creation.
- **Avoids:** Security vulnerabilities, path traversal, and accidental file overwrites.

### Phase 4: Bi-Directional WebSocket Protocol & Networking Engine
- **Rationale:** Connect Android and VS Code over a robust, versioned JSON-RPC protocol with loopback default and authenticated LAN pairing.
- **Delivers:** Extension-hosted WebSocket server (`127.0.0.1:38848`), Android WebSocket client with auto-reconnect, heartbeat, pairing token handshake, and event sync.
- **Avoids:** Unauthenticated network exposure and socket disconnection stalls.

### Phase 5: Android Companion UI & Project Management Engine
- **Rationale:** Build the Material 3 companion interface, project importer (local folder, local ZIP, ZIP URL, GitHub repo), nested file explorer with selection/exclusions, and SQLite persistence.
- **Delivers:** Polished Flutter UI, multi-source project import, tri-state folder selection with exclusions, and full SQLite persistence.
- **Addresses:** Complete companion user experience and project management requirements.

### Phase 6: End-to-End Integration, Release Workflows & Documentation
- **Rationale:** Connect the entire loop (Android shortcut -> Bluetooth HID -> VS Code QuickPick -> Safe File Creation -> WebSocket telemetry -> Android UI update), verify all acceptance criteria, and implement GitHub Actions release workflows with checksums.
- **Delivers:** Tested end-to-end companion system, `.github/workflows/release.yml` producing APK and VSIX artifacts, complete project documentation and fallback guides.

### Phase Ordering Rationale

- **Risk-First Approach:** Verifying Bluetooth HID and Native Kotlin channels in Phase 2 guarantees the core hardware dependency works before building dependent UI.
- **Decoupled Verification:** The extension (Phase 3) and mobile app (Phases 2 & 5) can be developed and unit-tested in isolation, then integrated over the protocol engine (Phase 4).
- **Security from the Start:** Path validation and loopback network binding are built into the initial implementation rather than retrofitted.

### Research Flags

- **Phase 2 (Bluetooth HID):** Requires verification on physical Android hardware or an emulator with Bluetooth passthrough; requires clear diagnostic feedback if the host device HAL lacks `HID_DEVICE` support.
- **Phase 4 (Networking):** Requires testing `adb reverse` loopback vs Wi-Fi LAN pairing with tokens.

---
*Research summary for: VS Code Companion System*
*Researched: 2026-11-12*

