# Developer Setup & Troubleshooting Guide

This guide walks you through setting up, pairing, and troubleshooting the **VS Code Companion System** across your workstation and Android companion device.

---

## 1. Prerequisites Checklist

| Component | Minimum Version | Recommended Version | Notes |
|-----------|-----------------|---------------------|-------|
| Host OS | Linux, macOS, or Windows | Linux / macOS | Must have Bluetooth 4.0+ hardware adapter |
| VS Code / Forks | ^1.90.0 | Latest stable VS Code / Cursor / VSCodium | Required for `vscode.workspace.fs` APIs |
| Node.js / pnpm | Node 20.x, pnpm 9 | Node 20 LTS / pnpm 9 | Required for extension compilation |
| Android Device | Android 9.0 (API 28) | Android 12 - 15 (API 31 - 35) | Must support Bluetooth HID Device profile |
| Flutter SDK | 3.24.0+ | 3.41.9 (Dart 3.11.5) | Required for companion app compilation |

---

## 2. Workstation Extension Setup

1. Open a terminal in `vscode-extension/`:
   ```bash
   cd vscode-extension
   pnpm install
   pnpm run compile
   ```
2. Package and install the extension:
   ```bash
   pnpm exec vsce package --no-dependencies --no-git-tag-version
   code --install-extension vscode-companion-0.1.0.vsix
   ```
   *(Or press `F5` in VS Code to launch the extension in an Extension Development Host window).*
3. Verify activation:
   Check the status bar in the bottom right corner: `Companion: 38848 (0)` indicating the WebSocket server is listening on port 38848.

---

## 3. Android Companion App Setup

1. Open a terminal in `companion-app/`:
   ```bash
   cd companion-app
   flutter pub get
   flutter run --release
   ```
2. Grant requested runtime permissions:
   - **Bluetooth / Nearby Devices**: Required for Bluetooth HID peripheral registration.
   - **Notifications**: Required on Android 13+ (API 33+) for the persistent Foreground Service.

---

## 4. Pairing & Connection Modes

### Option A: USB Loopback Mode (Recommended)
This mode provides the highest reliability, zero network exposure, and lowest latency:
1. Connect your Android device to your workstation via USB cable with **USB Debugging** enabled.
2. In your workstation terminal, run:
   ```bash
   adb reverse tcp:38848 tcp:38848
   ```
3. On the companion device, navigate to the **Dashboard** tab and tap **USB Loopback**.
4. The WebSocket chip will turn green and display `WebSocket: Connected`.

### Option B: Wi-Fi / Local Area Network (LAN) Mode
For wireless telemetry synchronization:
1. In VS Code, run `Preferences: Open Settings (UI)` and search for `companion`.
2. Configure `vscode-companion.network.bindAddress` to `0.0.0.0` or your workstation's LAN IP.
3. Click the status bar item or run `Companion: Show LAN Pairing Token`. Note the 6-character token (e.g. `K9X2P4`).
4. On the companion app Dashboard, tap **LAN Connect**, enter your workstation's LAN IP address, port `38848`, and the 6-character token, then tap **Connect**.

---

## 5. Bluetooth HID Pairing (Hardware Keyboard Mode)

1. On the Android device, go to **Dashboard** and ensure the **HID: Connected** badge is active.
2. Open your workstation's OS **Bluetooth Settings** and search for new devices.
3. Select your Android phone from the list.
4. When prompted, confirm pairing on both devices.
5. Your workstation will recognize the phone as a **Bluetooth Keyboard**.
6. Switch to the **Commands** tab on the phone and tap **Create File**. Your workstation will trigger `Ctrl+Alt+N` and open the VS Code file creation prompt!

---

## 6. Troubleshooting & FAQs

### Bluetooth HID: "Profile not supported" or Registration Fails
- **Cause**: Some OEM distributions (e.g., specific budget devices or heavily customized ROMs) disable the Bluetooth HID Device profile in the Bluetooth Hardware Abstraction Layer (HAL).
- **Resolution**: Verify device support. The companion app displays `Supported: false` in the **Settings** tab if your device kernel or HAL omits API 28+ `BluetoothHidDevice`. Test with an alternative Android device or standard Google Pixel / Samsung Galaxy device running Android 10+.

### WebSocket: "Connection Refused" in USB Loopback Mode
- **Cause**: Port forwarding rule not established or reset.
- **Resolution**:
  1. Check device connectivity: `adb devices`
  2. Re-execute: `adb reverse tcp:38848 tcp:38848`
  3. Verify port is listening in VS Code: Run `Companion: Show Connection Status`.

### File Creation: "E_PATH_TRAVERSAL" Error
- **Cause**: Attempting to input a relative path containing `../` that resolves outside your open workspace folder.
- **Resolution**: The VS Code companion strictly enforces workspace root sandboxing. All created files must remain within the active workspace root folders.

### File Creation: "E_FILE_EXISTS" Error
- **Cause**: The target file path already exists on disk.
- **Resolution**: By design, the companion system strictly prevents implicit overwrites to avoid data loss. Specify a unique file name or inspect the existing file in the VS Code explorer.
