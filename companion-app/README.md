# Android Companion App (`companion-app`)

The Android companion application for the **VS Code Companion System**, built with Flutter (Material 3) and native Kotlin platform channels.

The app transforms your Android device into a hardware keyboard command pad emitting native Bluetooth HID keystrokes, provides real-time active editor telemetry from VS Code, and features an SQLite-backed multi-source project explorer with hierarchical exclusion management.

---

## Features

- **Bluetooth HID Keyboard Peripheral**:
  Registers with the Android OS as a true Bluetooth HID Device (`android.bluetooth.BluetoothHidDevice`). Sends OS-level scancodes with zero latency. No intrusive Accessibility Services required.
- **Android Foreground Service**:
  Maintains persistent Bluetooth peripheral connections and WebSocket telemetry streams when the screen is dimmed or other apps are focused (`FOREGROUND_SERVICE_CONNECTED_DEVICE` on Android 14+).
- **Active Telemetry Dashboard**:
  Displays real-time Bluetooth HID, WebSocket, and Foreground Service status chips, active file relative path, uppercase language badge, and diagnostic error/warning counters.
- **Quick Commands Pad**:
  Preconfigured Material 3 action cards triggering developer workstation shortcuts:
  - Create File (`Ctrl + Alt + N`)
  - Save Document (`Ctrl + S`)
  - Format Code (`Shift + Alt + F`)
  - Command Palette (`Ctrl + Shift + P`)
  - Quick Open (`Ctrl + P`)
  - Find in Files (`Ctrl + Shift + F`)
  - Toggle Terminal (``Ctrl + ` ``)
- **Multi-Source Project Explorer**:
  Imports projects from local directories, local ZIP files, remote ZIP URLs, or GitHub archives. Renders an interactive nested file tree with recursive parent-to-child exclusion inheritance and real-time search.
- **SQLite Persistence (`sqflite`)**:
  Stores imported projects, file node hierarchies, exclusion rules, connection profiles, and session event logs locally.

---

## Hardware & Android Requirements

- **Minimum Android SDK**: Android 9.0 (API 28)
- **Target Android SDK**: Android 15 (API 35) / Compile SDK 36
- **Hardware Requirement**: Bluetooth chipset with Bluetooth HID Device profile support.
- **OEM Compatibility Note**: Certain custom vendor ROMs disable the Bluetooth HID Device profile in the Bluetooth HAL. The app automatically checks capabilities via `checkCapability` and alerts the user if the profile is unsupported by the underlying hardware.

---

## Getting Started

### Prerequisites
- Flutter SDK `3.41.9` (Dart `3.11.5`)
- Android SDK with Platforms 35/36 and Build-Tools 36.0.0
- Java 17 OpenJDK (`temurin`)

### Setup & Run
```bash
# Fetch dependencies
flutter pub get

# Run static analysis
flutter analyze --fatal-infos --fatal-warnings

# Run all unit and widget tests
flutter test

# Run on connected Android device or emulator
flutter run
```

### Build APK
```bash
# Build debug APK
flutter build apk --debug

# Build production release APK
flutter build apk --release
```

Output APK will be generated at `build/app/outputs/flutter-apk/app-release.apk`.

---

## USB Loopback Connection

To establish low-latency, zero-firewall communication without Wi-Fi:
1. Connect device via USB with USB Debugging enabled.
2. Run on host workstation:
   ```bash
   adb reverse tcp:38848 tcp:38848
   ```
3. Open the companion app Dashboard and tap **Connect USB Loopback**.
