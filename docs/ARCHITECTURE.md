# System Architecture & Technical Specifications

This document details the architectural boundaries, telemetry data flow, security model, and communication protocols of the **VS Code Companion System**.

---

## 1. Architectural Overview

The companion system is designed around a strictly decoupled, dual-runtime architecture:

```
┌────────────────────────────────────────────────────────┐
│            Android Device (Flutter + Kotlin)           │
│                                                        │
│  ┌────────────────────────┐  ┌───────────────────────┐ │
│  │     Commands Pad       │  │ Project Explorer Tree │ │
│  │  (Hardware Shortcuts)  │  │  (SQLite Persistence) │ │
│  └───────────┬────────────┘  └───────────────────────┘ │
│              │                                         │
│              ▼                               ▲         │
│  ┌────────────────────────┐  ┌───────────────┴───────┐ │
│  │ Kotlin Platform Channel│  │   WebSocket Client    │ │
│  │   (BluetoothHidDevice) │  │  (web_socket_channel) │ │
│  └───────────┬────────────┘  └───────────────▲───────┘ │
└──────────────┼───────────────────────────────┼─────────┘
               │ Bluetooth HID Scancodes       │ WebSocket (JSON-RPC)
               │ (Ctrl+Alt+N, Ctrl+S...)       │ (Telemetry & Events)
               ▼                               │
┌──────────────────────────────────────────────┼─────────┐
│           Workstation Host (VS Code)         │         │
│                                              │         │
│  ┌────────────────────────┐  ┌───────────────┴───────┐ │
│  │   OS Keyboard Buffer   │  │   Embedded WS Server  │ │
│  │   (Global Keybindings) │  │     (ws library)      │ │
│  └───────────┬────────────┘  └───────────────▲───────┘ │
│              │                               │         │
│              ▼                               │         │
│  ┌────────────────────────┐  ┌───────────────┴───────┐ │
│  │  createFileCommand.ts  │  │   editorMonitor.ts    │ │
│  │   (QuickPick / Input)  │  │  (Debounced Telemetry)│ │
│  └───────────┬────────────┘  └───────────────────────┘ │
│              │                                         │
│              ▼                                         │
│  ┌────────────────────────┐                            │
│  │   safeFileManager.ts   │                            │
│  │   (workspace.fs only)  │                            │
│  └────────────────────────┘                            │
└────────────────────────────────────────────────────────┘
```

---

## 2. Core Architectural Principles & Boundaries

1. **Dual Independent Project Roots**:
   Strictly two project roots: `companion-app/` and `vscode-extension/`. Zero monorepo tooling (no Nx, Turborepo, or Melos) to prevent artificial build coupling and complex caching issues.
2. **True Hardware Bluetooth HID Input**:
   Input emulation is strictly handled via native Android `BluetoothHidDevice` (API 28+), registering the phone as a USB/Bluetooth keyboard. No Android Accessibility Services are used.
3. **Zero Autonomous Code Generation**:
   The VS Code extension must **never** act as an autonomous coding agent, LLM client, or automated code generator. It is strictly an editor bridge, diagnostic provider, and safe file operator.
4. **Zero Shell Execution for Workspace Mutations**:
   All directory and file mutations must strictly use the official `vscode.workspace.fs` API. No shell command execution (`mkdir`, `touch`, `child_process.exec`) is permitted.
5. **Strict Path Sandboxing**:
   All paths passed to the extension are normalized with `vscode.Uri.joinPath` and checked against `workspace.workspaceFolders`. Any attempt to traverse outside (`E_PATH_TRAVERSAL`) is rejected.
6. **No Implicit Overwrite**:
   Before creating any file, existence is tested via `vscode.workspace.fs.stat`. If a file exists, `E_FILE_EXISTS` is returned, preventing accidental data loss.

---

## 3. Communication Protocols

### A. Bluetooth HID Channel (Android -> Host)
- Standard USB HID Keyboard Usage Table (Page `0x07`).
- Boot keyboard descriptor: 8-byte input report (`[modifier, reserved, key1, key2, key3, key4, key5, key6]`).
- Typical scancodes:
  - `Create File`: Modifier `0x05` (Ctrl+Alt), KeyCode `0x11` (`N`)
  - `Save`: Modifier `0x01` (Ctrl), KeyCode `0x16` (`S`)
  - `Format`: Modifier `0x06` (Shift+Alt), KeyCode `0x09` (`F`)
  - `Command Palette`: Modifier `0x03` (Ctrl+Shift), KeyCode `0x13` (`P`)
  - `Quick Open`: Modifier `0x01` (Ctrl), KeyCode `0x13` (`P`)
  - `Terminal`: Modifier `0x01` (Ctrl), KeyCode `0x35` (Grave Accent `` ` ``)

### B. Bi-Directional WebSocket Protocol (Host <-> Android)
All messages use a versioned JSON envelope:

```typescript
interface ProtocolEnvelope<T = unknown> {
  version: "1.0.0";
  id: string; // Unique UUID or message ID
  type: "event" | "request" | "response" | "error";
  name: string; // Event or method name
  payload: T; // Strongly-typed payload data
  timestamp: number; // Epoch milliseconds
}
```

#### Supported Messages:
- **`ping` / `pong`**: Heartbeat monitoring (every 15s client-side, 30s server-side sweep).
- **`editorState`**: Active document telemetry (`relativePath`, `languageId`, `diagnostics: { errorCount, warningCount }`).
- **`fileCreated`**: Confirmation event emitted after successful safe workspace creation.

---

## 4. Trust Boundaries & STRIDE Security Register

| Trust Boundary | Threats Identified | Mitigations Implemented |
|----------------|--------------------|-------------------------|
| Touch UI -> Bluetooth HID | Tampering, Injection | Predefined developer keypress mappings only. Zero arbitrary shell command execution. |
| LAN WebSocket Network | Spoofing, Eavesdropping | Default loopback binding (`127.0.0.1:38848`). LAN mode mandates 6-char cryptographic pairing token with constant-time comparison (`crypto.timingSafeEqual`). |
| Host Workspace File System | Path Traversal, Data Loss | Path resolution validated strictly within active workspace folders (`pathValidator.ts`). Existence check prevents implicit overwrite (`safeFileManager.ts`). |
| Release Distribution | Artifact Tampering | Automated GitHub Actions CI/CD generates SHA256 checksum manifests (`SHA256SUMS.txt`) for all published APK and VSIX binaries. |
