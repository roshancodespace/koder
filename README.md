# VS Code Companion System

A low-latency, context-aware developer companion system pairing an **Android companion app** (`companion-app/`) with a minimal, sandbox-safe **VS Code extension** (`vscode-extension/`).

The Android device acts as a hardware keyboard command pad using the native **Bluetooth HID Device profile** (`BluetoothHidDevice`), dispatching hardware scancodes and shortcuts directly to the workstation. Concurrently, a lightweight bi-directional **WebSocket telemetry engine** synchronizes active editor state, language indicators, diagnostic counts, and safe file creation confirmations.

---

## Key Highlights

- **Hardware Bluetooth HID Profile**: Acts as a true external Bluetooth keyboard peripheral (API 28+). No accessibility service workarounds, ensuring zero input latency and standard OS scan codes.
- **Bi-Directional Telemetry**: VS Code extension embeds a lightweight WebSocket server streaming active document paths, diagnostics (errors and warnings), and file events.
- **Safe Workspace Operations**: Collision-safe file creation via `vscode.workspace.fs`. Path traversal outside active workspace roots is strictly rejected (`E_PATH_TRAVERSAL`), and implicit overwrites are prevented (`E_FILE_EXISTS`).
- **Zero Autonomous Code Generation**: The extension operates strictly as an editor bridge and context provider—no LLM generation endpoints, no shell commands, and no autonomous background writes.
- **Multi-Source Project Explorer**: Android app imports project trees from local directories, local ZIP files, remote ZIP URLs, or GitHub archives, persisting hierarchies in SQLite (`sqflite`) with hierarchical parent-to-child exclusion inheritance.
- **Independent CI/CD**: Clean, decoupled subprojects with independent GitHub Actions test suites and release pipelines publishing verified APK and VSIX artifacts with cryptographic SHA256 checksums.

---

## Repository Structure

```
.
├── companion-app/                # Android Companion App (Flutter 3.41.9 / Kotlin)
│   ├── android/                  # Native Android host with BluetoothHidDevice platform channel
│   ├── lib/
│   │   ├── features/bluetooth_hid/   # Bluetooth HID registration & scancode emission
│   │   ├── features/foreground_service/ # Android foreground service lifecycle manager
│   │   ├── features/network/         # WebSocket client & JSON-RPC protocol
│   │   ├── features/project/         # SQLite persistence, tree parser & importer
│   │   └── features/ui/screens/      # Material 3 screens: Dashboard, Commands, Explorer, Settings
│   └── test/                     # Unit and widget test suites
│
├── vscode-extension/             # VS Code Extension (TypeScript ~5.8 / Node.js)
│   ├── src/
│   │   ├── commands/             # QuickPick & InputBox file creation commands
│   │   ├── editor/               # Debounced editor telemetry monitor & diagnostics
│   │   ├── network/              # Embedded WebSocket server & auth manager
│   │   └── workspace/            # Sandboxed path validator & safe file manager
│   └── test/                     # Headless integration & network unit test suites
│
├── docs/                         # In-depth architectural and setup documentation
│   ├── ARCHITECTURE.md           # System data flow, trust boundaries, and protocols
│   └── SETUP_GUIDE.md            # Step-by-step developer onboarding and troubleshooting
│
└── scripts/                      # Verification and audit tools
    ├── verify_e2e_contract.js    # End-to-end integration contract assertion runner
    ├── verify_boundaries.js      # Static security and architectural boundary auditor
    └── verify_release_workflows.js # CI/CD release workflow structure validator
```

---

## Quickstart

### 1. Prerequisites
- **Android Device**: Android 9.0 (API 28) or higher with Bluetooth HID Device profile support.
- **Workstation**: Linux, macOS, or Windows with Bluetooth support.
- **Development Tools**:
  - Flutter SDK 3.41.9+ (Dart 3.11.5+)
  - Node.js 20.x+ and `pnpm`
  - Android Debug Bridge (`adb`) for zero-config USB loopback

### 2. VS Code Extension Setup
```bash
cd vscode-extension
pnpm install
pnpm run compile
pnpm run test
```
To launch the extension in development mode, open `vscode-extension` in VS Code and press `F5`.

### 3. Android Companion App Setup
```bash
cd companion-app
flutter pub get
flutter analyze
flutter test
flutter run
```

### 4. Connect Device & Workstation
- **USB Loopback Mode (Recommended)**:
  Connect phone via USB and run on workstation:
  ```bash
  adb reverse tcp:38848 tcp:38848
  ```
  Tap **Connect USB Loopback** on the Android Dashboard.
- **Bluetooth HID Pairing**:
  Pair the Android device as a Bluetooth keyboard in your workstation OS Bluetooth settings.
- **LAN Wi-Fi Mode**:
  Run `Companion: Show LAN Pairing Token` in VS Code, and enter the host IP and 6-character token on your companion device.

---

## Documentation

- [Step-by-Step Setup & Troubleshooting Guide](docs/SETUP_GUIDE.md)
- [System Architecture & Security Specifications](docs/ARCHITECTURE.md)
- [Android Companion App Documentation](companion-app/README.md)
- [VS Code Extension Documentation](vscode-extension/README.md)

---

## Verification & Quality Gates

Run full system verification across both subprojects:
```bash
# Verify end-to-end contract
node scripts/verify_e2e_contract.js

# Verify architectural boundaries (no LLM, no shell execution)
node scripts/verify_boundaries.js

# Run companion tests
cd companion-app && flutter analyze && flutter test

# Run extension tests
cd vscode-extension && pnpm run lint && pnpm run compile && pnpm test
```

---

## License

MIT License. See `LICENSE` for details.
