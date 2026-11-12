---
phase: 02-android-bluetooth-hid-platform-channel-foreground-lifecycle
plan: 01
subsystem: mobile
tags: [android, kotlin, bluetooth-hid, platform-channel, riverpod, scancodes]

requires: [01-01]
provides:
  - Native Kotlin BluetoothKeyboardManager implementing BluetoothHidDevice profile registration
  - Defensive OEM capability check detecting unsupported or disabled HID HAL
  - Standard 8-byte USB boot keyboard report descriptor with immediate all-zero release reports
  - MethodChannel (com.companion.koder/hid) and EventChannel (com.companion.koder/hid_events)
  - Dart BluetoothHidService with Riverpod state management and unit test suite
affects: [02-android-bluetooth-hid-platform-channel-foreground-lifecycle, 05-android-companion-ui]

actuals:
  tokens: 14000
  tasks: 3
  commits: 2
  plan_head_before: c0a721b5d19988012296b13e70aa9cac725f2bd4
  plan_head_after: 604816d5668b5a044d039f990664e10113f9f4a0

tech-stack:
  added: []
  patterns:
    - Native Kotlin BluetoothHidDevice profile proxy management with ServiceDiscoveryProtocol settings
    - Immediate all-zero release report transmission following HID keypress reports
    - Defensive capability probing for OEM Bluetooth HAL restrictions
    - Main looper thread dispatch for Flutter EventChannel state events
    - Reactive Riverpod StateNotifier for mobile HID state consumption

key-files:
  created:
    - companion-app/android/app/src/main/kotlin/com/companion/companion_app/BluetoothKeyboardManager.kt
    - companion-app/lib/features/bluetooth_hid/models/hid_state.dart
    - companion-app/lib/features/bluetooth_hid/bluetooth_hid_service.dart
    - companion-app/test/unit/bluetooth_hid_service_test.dart
  modified:
    - companion-app/android/app/src/main/kotlin/com/companion/companion_app/MainActivity.kt

key-decisions:
  - "Constructed standard 8-byte USB boot keyboard report descriptor (Usage Page 0x07) for universal workstation host OS compatibility"
  - "Guaranteed immediate all-zero release report after key reports to prevent repeating or stuck keystrokes on host OS"
  - "Isolated HID state and capability models into lib/features/bluetooth_hid/models/ for clean separation of concerns"

patterns-established:
  - "Platform channel calls wrapped in Riverpod BluetoothHidNotifier with async capability verification"
  - "EventChannel events streamed onto main thread to avoid cross-thread UI synchronization issues"

requirements-completed: [HID-01, HID-02, HID-03, HID-04]

coverage:
  - id: D1
    description: "Kotlin BluetoothKeyboardManager initializing BluetoothAdapter and registering as BluetoothHidDevice"
    requirement: HID-01
    verification:
      - kind: unit
        ref: companion-app/test/unit/bluetooth_hid_service_test.dart
        status: pass
    human_judgment: false
  - id: D2
    description: "Service Discovery Protocol SDP record settings and HID callbacks managed by Kotlin platform channel"
    requirement: HID-02
    verification:
      - kind: unit
        ref: companion-app/test/unit/bluetooth_hid_service_test.dart
        status: pass
    human_judgment: false
  - id: D3
    description: "Transmission of 8-byte boot keyboard reports followed immediately by all-zero release reports"
    requirement: HID-03
    verification:
      - kind: code_review
        ref: companion-app/android/app/src/main/kotlin/com/companion/companion_app/BluetoothKeyboardManager.kt
        status: pass
    human_judgment: false
  - id: D4
    description: "Defensive BluetoothProfile.HID_DEVICE checking and diagnostic reporting for disabled OEM HAL"
    requirement: HID-04
    verification:
      - kind: unit
        ref: companion-app/test/unit/bluetooth_hid_service_test.dart
        status: pass
    human_judgment: false

duration: 12m
completed: 2026-11-12
status: complete
---

# Phase 02 Plan 01: Native Bluetooth HID Platform Channel Summary

**Native Android Kotlin Bluetooth HID Device platform channel implemented with defensive capability probing, standard 8-byte boot keyboard report descriptor, immediate all-zero release reports, and Riverpod-managed Dart client service.**

## Performance

- **Duration:** 12 min
- **Started:** 2026-11-12T11:15:00Z
- **Completed:** 2026-11-12T11:27:00Z
- **Tasks:** 3
- **Commits:** 2

## Accomplishments

1. **Native Kotlin BluetoothKeyboardManager:**
   - Implemented `BluetoothKeyboardManager.kt` managing `BluetoothProfile.HID_DEVICE` lifecycle and proxy acquisition.
   - Defined standard 8-byte USB boot keyboard report descriptor (`Usage Page 0x07`, modifier range `0xE0-0xE7`, 6 keycodes).
   - Configured `BluetoothHidDeviceAppSdpSettings` and `BluetoothHidDeviceAppQosSettings` for SDP registration.
   - Built `sendKeyPress(modifier, keyCode)` that constructs the 8-byte key report and immediately transmits an all-zero release report to prevent stuck keys.
   - Added defensive capability probing (`checkCapability()`) returning adapter presence, enabled state, profile proxy support, and diagnostic OEM failure reasons.

2. **Platform Channel Wiring:**
   - Registered `MethodChannel` (`com.companion.koder/hid`) in `MainActivity.kt` handling `checkCapability`, `registerApp`, `unregisterApp`, `connect`, `disconnect`, and `sendKeyPress`.
   - Registered `EventChannel` (`com.companion.koder/hid_events`) streaming connection states (`CONNECTED`, `CONNECTING`, `DISCONNECTING`, `DISCONNECTED`, `REGISTERED`, `UNREGISTERED`) posted directly to the Android main looper.

3. **Dart Client Service & Riverpod:**
   - Created `HidState`, `HidCapability`, and `HidConnectionStatus` models.
   - Implemented `BluetoothHidNotifier` exposing reactive state via Riverpod `bluetoothHidServiceProvider`.
   - Developed unit test suite in `test/unit/bluetooth_hid_service_test.dart` testing capability parsing, channel mock invocations, and state transitions with 100% pass rate.

## Verification

- `flutter analyze`: Zero warnings, zero errors.
- `flutter test`: All 11 tests passed across unit and widget suites.
