# VS Code Companion Extension (`vscode-extension`)

A minimal, sandbox-safe VS Code extension that functions as the workstation bridge for the **VS Code Companion System**.

The extension embeds a lightweight WebSocket server streaming editor telemetry to the Android companion device, provides a safe file creation command workflow triggered by Bluetooth HID shortcuts, and strictly adheres to architectural safety boundaries (zero autonomous code generation, zero shell commands).

---

## Features

- **Embedded WebSocket Server**:
  Defaults to loopback binding (`127.0.0.1:38848`), accessible securely over USB via `adb reverse` with zero network exposure. Supports port failover retry (38848–38855).
- **Cryptographic LAN Pairing**:
  Optional LAN mode binds to local network interfaces with a dynamically generated 6-character pairing token (cryptographically random, timing-safe validation) displayed in the VS Code status bar.
- **Real-Time Editor Awareness**:
  Monitors active document changes, language ID, and diagnostic errors/warnings using a 300ms debounced telemetry emitter.
- **Safe Workspace File Operations**:
  Provides `vscode-companion.createFile` triggered by `Ctrl+Alt+N`:
  - Path normalization asserting resolved path is strictly within active workspace folders (`E_PATH_TRAVERSAL`).
  - Collision detection checking existence via `vscode.workspace.fs.stat` to strictly prevent implicit overwrites (`E_FILE_EXISTS`).
  - Recursive directory creation via `vscode.workspace.fs.createDirectory` and atomic write via `vscode.workspace.fs.writeFile`.
- **Zero Autonomous Code Generation**:
  The extension contains no LLM clients, no autonomous generation routines, and no arbitrary shell/child_process executions.

---

## Contributed Commands & Keybindings

| Command | Title | Default Shortcut | Description |
|---------|-------|------------------|-------------|
| `vscode-companion.createFile` | Companion: Create File Safely | `Ctrl+Alt+N` (`Cmd+Alt+N`) | Prompts for a relative file path, validates sandboxing, and creates the file safely. |
| `vscode-companion.status` | Companion: Show Connection Status | — | Displays active WebSocket server port, connected clients, and pairing state. |
| `vscode-companion.showPairingToken` | Companion: Show LAN Pairing Token | — | Displays the active 6-character LAN pairing token in an info dialog. |

---

## Getting Started

### Prerequisites
- Node.js 20.x+
- `pnpm` (version 9+)

### Installation & Build
```bash
# Install dependencies
pnpm install

# Compile TypeScript
pnpm run compile

# Run linter
pnpm run lint

# Run unit tests
pnpm exec mocha --ui tdd out/test/network.test.js
```

### Packaging VSIX Extension
```bash
pnpm exec vsce package --no-dependencies --no-git-tag-version
```

Output package will be generated at `vscode-companion-0.1.0.vsix`.
