# Pitfalls Research

**Domain:** Android Companion Application & VS Code Extension
**Researched:** 2026-11-12
**Confidence:** HIGH

## Critical Pitfalls

### Pitfall 1: Android Manufacturer/OEM Bluetooth HID Device Disablement

**What goes wrong:**
Calling `bluetoothAdapter.getProfileProxy(context, listener, BluetoothProfile.HID_DEVICE)` returns false, or the service proxy never connects (`onServiceConnected` never fires), or `registerApp` fails immediately.

**Why it happens:**
While `BluetoothHidDevice` was added in AOSP Android 9 (API 28), several device manufacturers (certain Xiaomi MIUI/HyperOS, Huawei, and budget MediaTek devices) disable the HID Device role in their proprietary Bluetooth HAL builds to save power or pass custom carrier certifications.

**How to avoid:**
1. Check device capabilities defensively before attempting registration:
   - Verify `BluetoothAdapter.getDefaultAdapter() != null` and is enabled.
   - Guard `getProfileProxy` and check the boolean return value.
2. In the UI, provide explicit capability diagnostic status:
   - If `HID_DEVICE` is unsupported by the chipset/ROM, display a clear, non-crash message: *"Your Android device hardware/ROM has disabled the Bluetooth HID Device profile. Bluetooth keyboard features cannot operate on this device."*
   - Never pretend unsupported hardware will work or silently fail.

**Warning signs:**
`getProfileProxy` returns false immediately, or `onServiceConnected` never executes within a 3-second timeout.

**Phase to address:**
Phase 1 (Hardware & HID Verification)

---

### Pitfall 2: Android 14+ Foreground Service Termination & `connectedDevice` Requirement

**What goes wrong:**
When the user minimizes the companion app or the phone screen turns off, Android abruptly unregisters the HID app, disconnects the Bluetooth session, and kills the WebSocket connection. On Android 14+ (API 34), launching a foreground service without declaring `foregroundServiceType="connectedDevice"` throws a fatal `MissingForegroundServiceTypeException`.

**Why it happens:**
Modern Android OS aggressively puts background processes into cached/frozen states. Android's Bluetooth stack unregisters HID peripheral apps unless an active foreground service holds a wake lock and a connected device service lease.

**How to avoid:**
1. Add `FOREGROUND_SERVICE` and `FOREGROUND_SERVICE_CONNECTED_DEVICE` permissions to `AndroidManifest.xml`.
2. Declare `<service android:name=".CompanionForegroundService" android:foregroundServiceType="connectedDevice" android:exported="false" />`.
3. Start the service with a persistent notification when a companion session is started, and cleanly stop the service when the session ends.
4. Request `POST_NOTIFICATIONS` runtime permission on Android 13+ before invoking `startForeground()`.

**Warning signs:**
App crashes on Android 14 when starting foreground service, or Bluetooth drops within 15–30 seconds of app switching.

**Phase to address:**
Phase 1 & Phase 2 (Native Foundation & Lifecycle)

---

### Pitfall 3: Directory Traversal (`../`) and Path Injection in VS Code Extension

**What goes wrong:**
A malicious or malformed path input (e.g. `../../../../etc/passwd` or `../../.bashrc`) traverses out of the project directory and creates or touches arbitrary files on the developer's computer.

**Why it happens:**
Naive path concatenation with string interpolation (`${workspaceRoot}/${userInput}`) without checking the resolved canonical path boundary.

**How to avoid:**
1. Always resolve paths using `vscode.Uri.joinPath(workspaceUri, inputPath)`.
2. Canonicalize the path and verify that `targetUri.fsPath.startsWith(workspaceUri.fsPath)`.
3. Reject any input containing null bytes, path separators that escape root, or references to parent folders outside workspace boundaries.
4. Always reject implicit file overwrites by verifying `workspace.fs.stat(targetUri)` throws `FileNotFound` before calling `writeFile`.

**Warning signs:**
Paths with `..` produce file URIs whose prefix does not match the active `workspaceFolders[0].uri.fsPath`.

**Phase to address:**
Phase 2 (Extension Core & Workspace Safety)

---

### Pitfall 4: WebSocket Port Collisions and Unauthenticated Network Binding

**What goes wrong:**
Binding the WebSocket server to `0.0.0.0` exposes the editor state and file creation commands to anyone on the same Wi-Fi network (coffee shop, shared office). If the default port (e.g. 38848) is already in use by another instance or application, the extension fails to start or crashes.

**Why it happens:**
Lack of port retry logic and binding to wildcard addresses (`0.0.0.0`) without authentication.

**How to avoid:**
1. Bind strictly to `127.0.0.1` by default. Rely on `adb reverse tcp:38848 tcp:38848` for USB connections.
2. Implement dynamic port fallback (try 38848, then 38849-38855) or provide a clear status bar warning if the port is busy.
3. If LAN mode is explicitly enabled by user setting, generate a random 6-character alphanumeric pairing token, display it in the VS Code notification/status bar, and reject any WebSocket client that does not provide the matching token in its handshake header or query param.

**Warning signs:**
EADDRINUSE errors in extension console; unauthenticated incoming connections from non-loopback IP addresses.

**Phase to address:**
Phase 3 (Networking & Protocol Engine)

---

### Pitfall 5: Broken Monorepo Tooling and Conflicting Package Management

**What goes wrong:**
Attempting to create a monorepo with root `package.json` / workspace tools that try to manage both the TypeScript VS Code extension and the Flutter Dart app. CI fails, lockfiles clash, and tooling gets confused.

**Why it happens:**
Imposing web/monorepo paradigms on two completely disparate ecosystems with incompatible package managers (`pnpm` vs `pub`).

**How to avoid:**
Strictly maintain two independent folders:
- `companion-app/` with standard Flutter `pubspec.yaml` and `.github/workflows/`.
- `vscode-extension/` with standard `package.json` (managed via `pnpm`) and `.github/workflows/`.
Zero monorepo tooling or shared package links between them.

**Warning signs:**
Root-level `node_modules` interfering with Flutter builds or CI scripts that run `pnpm install` in the mobile app directory.

**Phase to address:**
Phase 1 (Workspace Bootstrap & CI Setup)

---

## Technical Debt Patterns

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| Using Accessibility Service instead of Bluetooth HID | Fast to prototype on Android without native Kotlin Bluetooth HID | Banned by requirements; terrible input lag; rejected by OS app stores; unable to send hardware scancodes | Never |
| Node.js native `fs` instead of `vscode.workspace.fs` | Simpler Node.js API syntax | Breaks multi-root workspace tracking; bypasses VS Code undo history and file watchers; path traversal bugs | Never |
| Unauthenticated WebSocket server | Avoids implementing pairing/token exchange | Dangerous remote file manipulation vulnerability on shared networks | Only on loopback (127.0.0.1) |
| Hardcoded scancode mapping | Saves writing an HID keycode lookup table | Difficult to support different keyboard layouts (QWERTY, AZERTY) or multi-key combinations | Only for initial MVP shortcut set |

## Integration Gotchas

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|------------------|
| `BluetoothHidDevice.sendReport` | Sending key down without an immediate key release report | Always send the key down report with keycode, followed immediately or after a 15-25ms delay by an all-zero release report; otherwise the host registers a repeating/stuck key. |
| `vscode.window.showInputBox` | Allowing relative path input with leading `/` | Strip leading slashes from user input and normalize path segments before joining with workspace URI. |
| Android `adb reverse` | Assuming reverse port forwarding persists after USB unplug/replug | Catch connection refused in the Flutter client and present a helpful hint: "USB connected? Run: adb reverse tcp:38848 tcp:38848". |
| GitHub Actions Release | Storing signing secrets in repo or publishing unverified artifacts | Use GitHub Secrets for signing credentials, generate SHA256 checksums, and attach artifacts only when CI passes. |

## Performance Traps

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|----------------|
| Unthrottled Editor Diagnostics Broadcast | High CPU and battery drain on Android device during rapid typing in VS Code | Debounce diagnostic updates (e.g. 250ms debounce) in the VS Code extension before transmitting over WebSocket. | In large files (>1,000 lines) with TypeScript language server reporting diagnostics on every keystroke. |
| Massive Project Tree Parsing in Memory | Android app stutters or crashes with OOM when importing large repository (e.g. Chromium or React) | Lazy-load directory trees in the Flutter UI; store tree nodes in SQLite; filter out `.git` and `node_modules` during import traversal. | Repositories with >5,000 files. |

---
*Pitfalls research for: VS Code Companion System*
*Researched: 2026-11-12*

