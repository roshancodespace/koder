# Architecture Research

**Domain:** Android Companion Application & VS Code Extension
**Researched:** 2026-11-12
**Confidence:** HIGH

## Standard Architecture

### System Overview

```
┌────────────────────────────────────────────────────────────────────────┐
│                   Android Companion App (Flutter / Dart)               │
│                                                                        │
│  ┌───────────────────────┐                  ┌───────────────────────┐  │
│  │   Companion UI / UX   │                  │   Project Explorer    │  │
│  │   (Material 3 / State)│                  │ (Hierarchical Tree)   │  │
│  └───────────┬───────────┘                  └───────────┬───────────┘  │
│              │                                          │              │
│  ┌───────────▼───────────┐                  ┌───────────▼───────────┐  │
│  │ WebSocket Client      │                  │ SQLite Persistence    │  │
│  │ (Heartbeat, RPC, Sync)│                  │ (Projects, Exclusions)│  │
│  └───────────┬───────────┘                  └───────────────────────┘  │
│              │                                                         │
│  ┌───────────▼──────────────────────────────────────────────────────┐  │
│  │ Kotlin Platform Channel (`BluetoothHidDevice` + Foreground Svc)  │  │
│  └───────────────────────────────────┬──────────────────────────────┘  │
└──────────────────────────────────────┼─────────────────────────────────┘
                                       │
                ┌──────────────────────┴──────────────────────┐
                │                                             │
      [ Bluetooth HID ]                             [ WebSocket (TCP) ]
    Hardware Keyboard Scancodes                   Bidirectional JSON-RPC
                │                             (Loopback adb reverse / LAN)
                ▼                                             ▼
┌────────────────────────────────────────────────────────────────────────┐
│                   VS Code Extension (TypeScript / Node.js)             │
│                                                                        │
│  ┌───────────────────────┐                  ┌───────────────────────┐  │
│  │ OS / Keyboard Focus   │                  │ WebSocket Server (ws) │  │
│  │ (Hotkeys trigger UI)  │                  │ (Port 38848, Auth/Pin)│  │
│  └───────────┬───────────┘                  └───────────┬───────────┘  │
│              │                                          │              │
│  ┌───────────▼───────────┐                  ┌───────────▼───────────┐  │
│  │ QuickPick / InputBox  │                  │ Editor Awareness      │  │
│  │ Command Workflows     │                  │ (Active File, Diags)  │  │
│  └───────────┬───────────┘                  └───────────┬───────────┘  │
│              │                                          │              │
│  ┌───────────▼──────────────────────────────────────────▼───────────┐  │
│  │ Path Validator & Safe File Operations (vscode.workspace.fs)      │  │
│  └──────────────────────────────────────────────────────────────────┘  │
└────────────────────────────────────────────────────────────────────────┘
```

### Component Responsibilities

| Component | Responsibility | Typical Implementation |
|-----------|----------------|------------------------|
| **Android Bluetooth HID Manager (Kotlin)** | Manages `BluetoothHidDevice` profile registration, SDP record descriptor, device pairing state, and sends raw 8-byte HID reports (modifier byte + keycodes) followed by release reports. Runs within a Foreground Service (`connectedDevice`). | Kotlin class registered as a Flutter `MethodChannel` / `EventChannel`. |
| **Android Foreground Service** | Keeps the process, Bluetooth HID registration, and WebSocket connection alive when app is minimized or screen locks. | Android `Service` with `foregroundServiceType="connectedDevice"` and persistent notification. |
| **Android WebSocket Client** | Maintains connection to VS Code extension server, performs automatic reconnection with exponential backoff, serializes/deserializes JSON-RPC messages, correlates request IDs. | Dart `web_socket_channel` managed by Riverpod state provider. |
| **Android Project Explorer & Storage** | Imports codebases (Local, ZIP, URL, GitHub), manages recursive inclusion/exclusion trees, and persists project metadata and connection settings to SQLite. | Dart `sqflite` with clean repository pattern and hierarchical query methods. |
| **Android UI (Material 3)** | Clean, minimal, responsive companion interface; displays connection badges, editor status, diagnostic tallies, file tree, and quick shortcut triggers. | Flutter Material 3 widgets with light/dark theme support. |
| **VS Code WebSocket Server** | Hosts WebSocket server listening on `127.0.0.1:38848` (configurable); handles client connection handshakes, verifies pairing tokens for LAN, and manages heartbeats. | Node.js `ws` library wrapped in a dedicated `WebSocketServerManager` class. |
| **VS Code Editor Monitor** | Subscribes to window and workspace events (`onDidChangeActiveTextEditor`, `onDidChangeTextEditorSelection`, `onDidChangeDiagnostics`) and broadcasts state changes to connected Android clients. | Event-driven TypeScript service implementing `vscode.Disposable`. |
| **VS Code QuickPick / InputBox Workflow** | Intercepts shortcut-triggered commands; presents a floating input UI for nested file creation; returns validation feedback; invokes file creation. | Native `vscode.window.showInputBox` and `vscode.window.createQuickPick`. |
| **VS Code Path Validator & FS Manager** | Enforces security boundaries: prevents directory traversal (`../`) outside active workspace folders; checks file existence to forbid implicit overwrites; creates missing directories recursively via `workspace.fs`. | TypeScript module utilizing `vscode.Uri` and `vscode.workspace.fs`. |

## Recommended Project Structure

Strictly two independent project directories without monorepo tooling:

```text
workspace/
├── .planning/                       # GSD planning & tracking artifacts
├── companion-app/                   # Android Flutter Application
│   ├── android/                     # Native Android project
│   │   ├── app/src/main/kotlin/     # Kotlin Bluetooth HID & Foreground Service
│   │   │   └── .../companion/       # BluetoothHidDevice platform channel implementation
│   │   └── app/src/main/AndroidManifest.xml # Permissions (BLUETOOTH_CONNECT, FOREGROUND_SERVICE_CONNECTED_DEVICE)
│   ├── lib/                         # Flutter Dart source code
│   │   ├── core/                    # Constants, themes, protocol models
│   │   ├── features/
│   │   │   ├── bluetooth_hid/       # HID method channel controller & scancode mappers
│   │   │   ├── connection/          # WebSocket client & reconnect service
│   │   │   ├── editor_monitor/      # Editor state receiver & display
│   │   │   └── project_explorer/    # Project import, tree parser & SQLite repository
│   │   └── main.dart                # App entry point
│   ├── test/                        # Flutter unit and widget tests
│   ├── pubspec.yaml                 # Flutter dependencies and assets
│   └── .github/workflows/           # companion-app CI/CD
│       ├── ci.yml                   # Format, analyze, test, APK build
│       └── release.yml              # Tagged release, SHA256, APK artifact
│
└── vscode-extension/                # VS Code Extension
    ├── src/                         # TypeScript source code
    │   ├── server/                  # WebSocket server & client connection manager
    │   ├── protocol/                # JSON-RPC schema & message validators
    │   ├── editor/                  # Editor state listener (active file, selection, diagnostics)
    │   ├── workspace/               # Safe workspace filesystem operations & path validator
    │   ├── commands/                # QuickPick / InputBox command flows
    │   └── extension.ts             # Extension activation & lifecycle
    ├── test/                        # Extension unit & integration tests
    │   ├── suite/                   # Test suites
    │   └── runTest.ts               # Test runner
    ├── package.json                 # Extension manifest, commands, settings, dependencies
    ├── tsconfig.json                # TypeScript compiler configuration
    └── .github/workflows/           # vscode-extension CI/CD
        ├── ci.yml                   # Lint, compile, test, VSIX build
        └── release.yml              # Tagged release, SHA256, VSIX artifact
```

### Structure Rationale

- **No Shared Monorepo Tooling:** Eliminates root-level lockfile conflicts, distinct language package managers (`pub` vs `pnpm`), and cross-contamination of CI environments.
- **Independent GitHub Actions:** Allows testing and deploying the Android APK independently of the VS Code VSIX extension.
- **Isolated Native Code in `android/`:** Kotlin HID implementation is cleanly isolated in the native Android directory and accessed strictly via Flutter Platform Channels (`MethodChannel` and `EventChannel`).

## Architectural Patterns

### Pattern 1: Platform Channel Bridge for Bluetooth HID

**What:** A bidirectional channel between Flutter Dart and Kotlin to manage `BluetoothHidDevice` registration and send HID scan code reports.

**Trade-offs:** Requires native Kotlin code and Android-specific lifecycle handling, but enables direct OS-level Bluetooth HID profile access impossible through standard Flutter plugins.

```kotlin
// Kotlin snippet: Sending HID Keyboard Scancode Report
val report = byteArrayOf(modifier, 0x00, keyCode, 0x00, 0x00, 0x00, 0x00, 0x00)
bluetoothHidDevice?.sendReport(connectedHostDevice, 0, report)
// Immediate release report
val releaseReport = byteArrayOf(0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00)
bluetoothHidDevice?.sendReport(connectedHostDevice, 0, releaseReport)
```

### Pattern 2: Safe Workspace Mutation via `workspace.fs`

**What:** Validates requested paths relative to the active workspace folder and performs atomic checks before writing files.

**Trade-offs:** Requires asynchronous URI handling, but guarantees safety against directory traversal attacks (`../../`) and prevents data loss from inadvertent file overwrites.

```typescript
// TypeScript snippet: Safe file creation in VS Code
export async function createWorkspaceFileSafely(
  workspaceFolderUri: vscode.Uri,
  relativePath: string
): Promise<vscode.Uri> {
  const targetUri = vscode.Uri.joinPath(workspaceFolderUri, relativePath);
  
  // Guard against path traversal outside the workspace
  if (!targetUri.fsPath.startsWith(workspaceFolderUri.fsPath)) {
    throw new Error('PATH_TRAVERSAL_DETECTED: Target path is outside workspace root');
  }

  // Check if target file already exists (prevent implicit overwrite)
  try {
    await vscode.workspace.fs.stat(targetUri);
    throw new Error('FILE_ALREADY_EXISTS: Cannot overwrite existing file implicitly');
  } catch (err: any) {
    if (err.code !== 'FileNotFound' && err.message.includes('FILE_ALREADY_EXISTS')) {
      throw err;
    }
  }

  // Ensure parent directory exists recursively
  const parentDirUri = vscode.Uri.joinPath(targetUri, '..');
  await vscode.workspace.fs.createDirectory(parentDirUri);

  // Create empty file safely
  await vscode.workspace.fs.writeFile(targetUri, new Uint8Array());
  return targetUri;
}
```

### Pattern 3: Versioned Typed Protocol over WebSocket

**What:** Structured JSON-RPC 2.0-like messaging for events, requests, and responses.

**Envelope Structure:**
```json
{
  "version": "1.0",
  "id": "msg-1731405000-001",
  "type": "event | request | response",
  "name": "editor.activeFileChanged | workspace.createFile",
  "payload": {},
  "timestamp": 1731405000000
}
```

## Data Flow

### Context-Aware File Creation Flow

```
1. User taps "Create Component" on Android Companion UI.
2. Companion App triggers Kotlin HID Platform Channel.
3. Kotlin sends HID scancode (e.g., Ctrl+Alt+N) via Bluetooth to Host OS.
4. VS Code receives global/editor shortcut and triggers Extension Command.
5. Extension displays native QuickPick / InputBox prompt in VS Code window.
6. User inputs nested relative path: "src/components/button/button.tsx".
7. Extension validates path:
   - Validates URI against workspaceFolder bounds.
   - Verifies target file does NOT already exist via workspace.fs.stat.
8. Extension creates missing directories recursively via workspace.fs.createDirectory.
9. Extension creates the file via workspace.fs.writeFile.
10. Extension opens the file via vscode.window.showTextDocument.
11. Extension emits WebSocket event `workspace.fileCreated` to Android.
12. Android Companion App receives event and updates its local operation history in SQLite.
```

## Security Model

1. **Localhost Loopback Default:** The extension binds strictly to `127.0.0.1`. When connected via USB, `adb reverse` allows direct communication without exposing ports on the local network.
2. **Explicit LAN Pairing:** When binding to `0.0.0.0` for LAN Wi-Fi mode, the extension displays a one-time cryptographic pairing PIN/token in the VS Code UI. The WebSocket handshake requires an `Authorization: Bearer <token>` header or query parameter. Unauthenticated connections are terminated immediately.
3. **Workspace Sandbox Isolation:** All file system mutations use `vscode.workspace.fs` and enforce canonical URI path containment inside `vscode.workspace.workspaceFolders`. Traversal attempts (`..`) throw security violations.
4. **No Code Generation Agency:** The extension does NOT execute terminal commands, evaluate arbitrary scripts, or generate source code. It only performs structured workspace file/folder creations.
5. **Bluetooth HID Trust:** Uses standard OS Bluetooth pairing. Scancodes are processed by the host OS as standard hardware keyboard events.

---
*Architecture research for: VS Code Companion System*
*Researched: 2026-11-12*

