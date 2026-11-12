# VS Code Companion System

## What This Is

A developer companion system consisting of an Android companion application (`companion-app/`) built with Flutter and a minimal VS Code extension (`vscode-extension/`) built with TypeScript. The Android application functions as an external keyboard and command pad using Bluetooth HID to send low-latency keystrokes and shortcuts to the workstation, while communicating over WebSocket with the VS Code extension for editor state synchronization, context awareness, and safe workspace operations.

## Core Value

Enable low-latency, context-aware command execution and workspace manipulation directly from an Android companion device via Bluetooth HID shortcuts and structured WebSocket telemetry, strictly bounded by safe workspace APIs and without autonomous code generation.

## Requirements

### Validated

(None yet — ship to validate)

### Active

- [ ] **HID-01**: Android application registers and connects as a Bluetooth HID Device (keyboard profile) to send keystrokes and system shortcuts.
- [ ] **HID-02**: Native Kotlin platform channel handles `BluetoothHidDevice` lifecycle, state registration, SDP record management, and HID report transmission.
- [ ] **UI-01**: Minimal Material 3 Flutter companion interface supporting light and dark themes, responsive layout, clear visual hierarchy, and connection status.
- [ ] **PERSIST-01**: SQLite persistence on Android for connection profiles, project imports, active file selections, session history, and error logs.
- [ ] **PROJ-01**: Project management in Android app supporting local directories, local ZIP files, remote ZIP URLs, and GitHub repository imports.
- [ ] **PROJ-02**: Nested file explorer with recursive directory inheritance, explicit child file/folder exclusions, and file selection persistence.
- [ ] **EXT-01**: Minimal TypeScript VS Code extension with zero heavy dependencies and low resource overhead.
- [ ] **EXT-02**: Event-driven editor awareness reporting active file, language ID, cursor position, selections, workspace folders, and file diagnostics.
- [ ] **EXT-03**: Custom hotkey-triggered QuickPick / InputBox floating command workflow for nested file/folder creation and context actions.
- [ ] **EXT-04**: Strict path validation and safe workspace operations using VS Code `workspace.fs` API preventing traversal outside workspace root and preventing implicit file overwrites.
- [ ] **NET-01**: Extension-hosted WebSocket server supporting loopback by default and optional authenticated LAN access with pairing secrets.
- [ ] **NET-02**: Versioned bidirectional protocol with request-response correlation, sequence tracking, timeout handling, and automatic reconnection.
- [ ] **CI-01**: Independent GitHub Actions CI workflows for both `companion-app` (format, analyze, test, APK build) and `vscode-extension` (lint, compile, test, VSIX packaging).
- [ ] **REL-01**: Independent GitHub Actions release workflows with tagged releases, manual dispatch, SHA256 checksums, and credential protection.

### Out of Scope

- **AI Code Generation**: The extension must never generate, modify, or type code autonomously; it is strictly an editor bridge and context provider.
- **Accessibility Service / Soft Keyboard Hacks**: Software keyboard hacks and accessibility touch simulation are prohibited in place of true Bluetooth HID.
- **Monorepo / Shared Packages**: Monorepo build tools (e.g. Nx, Turborepo, Melos) and shared cross-project npm packages are excluded to keep projects completely decoupled.
- **iOS / Desktop Flutter Targets**: The companion app targets Android exclusively.
- **Unauthenticated LAN Exposure**: The WebSocket server will not accept unauthenticated non-loopback connections.

## Context

- **Host Machine Environment**: EndeavourOS Linux (kernel 7.2.9-arch1-1), Node.js v24.21.0, pnpm 12.6.0, OpenJDK 21, Android SDK (build-tools 36.0.0, platforms/android-36, adb 37.0.1), Flutter 3.41.9 (Dart 3.11.5), VS Code installed.
- **Bluetooth HID Device Requirements**: Android API 28+ (Pie) introduced `BluetoothHidDevice`. Support depends on device manufacturer Bluetooth HAL (Bluetooth HID Device Profile / BAP/HID role).
- **Networking**: Loopback (via `adb reverse tcp:PORT tcp:PORT` over USB) provides the most reliable zero-configuration connection; LAN connection requires discovery/pairing and token exchange.
- **File System Safety**: All file creations and manipulations in VS Code must use `vscode.workspace.fs` and `vscode.Uri` comparisons rather than raw Node.js `fs` or shell commands to preserve multi-root workspace containment and platform abstraction.

## Constraints

- **Tech Stack**: Flutter (Android only) + Kotlin Platform Channel, TypeScript (VS Code Extension API).
- **Workspace Structure**: Strictly two directories: `companion-app/` and `vscode-extension/`.
- **Bluetooth HID**: Mandatory standard HID Keyboard descriptor; no Accessibility Service workarounds.
- **Safety**: No implicit overwrite of existing files; no path traversal outside active workspace root.
- **CI/CD**: Fully independent `.github/workflows/ci.yml` and `.github/workflows/release.yml` in each subproject.

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Android Bluetooth HID Device API (API 28+) via Kotlin Platform Channel | Mandated requirement; true hardware keyboard emulation without host-side companion drivers | — Pending |
| Extension-hosted WebSocket Server with Loopback Default | Enables direct, bi-directional event streaming and RPC without cloud middleman; adb reverse tcp enables reliable zero-network USB connection | — Pending |
| VS Code Native UI (QuickPick & InputBox) for Command Workflows | Follows native VS Code conventions, matches theme automatically, requires zero webview overhead | — Pending |
| VS Code `workspace.fs` for Workspace Mutations | Provides unified cross-platform workspace-relative abstraction and path sandboxing | — Pending |
| Completely Decoupled Subprojects | Simplifies CI/CD, prevents dependency leakage, matches distinct deployment lifecycles (APK vs VSIX) | — Pending |
| SQLite for Android Local State | Reliable structured storage for file trees, exclusions, and connection histories | — Pending |

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `/gsd-transition`):
1. Requirements invalidated? → Move to Out of Scope with reason
2. Requirements validated? → Move to Validated with phase reference
3. New requirements emerged? → Add to Active
4. Decisions to log? → Add to Key Decisions
5. "What This Is" still accurate? → Update if drifted

**After each milestone** (via `/gsd-complete-milestone`):
1. Full review of all sections
2. Core Value check — still the right priority?
3. Audit Out of Scope — reasons still valid?
4. Update Context with current state

---
*Last updated: 2026-11-12 after initialization*

