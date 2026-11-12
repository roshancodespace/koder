---
phase: 02-android-bluetooth-hid-platform-channel-foreground-lifecycle
plan: 02
subsystem: mobile
tags: [android, kotlin, foreground-service, connectedDevice, notifications, riverpod, lifecycle]

requires: [02-01]
provides:
  - Native Android CompanionForegroundService with foregroundServiceType="connectedDevice"
  - Persistent ongoing notification channel keeping process alive in background
  - MethodChannel (com.companion.koder/service) handling startService and stopService
  - Dart ForegroundServiceManager automatically synchronizing service lifecycle with HID connection state
  - Reactive HomeScreen displaying Bluetooth HID, WebSocket, and Foreground Service status chips
affects: [02-android-bluetooth-hid-platform-channel-foreground-lifecycle, 04-networking-protocol-engine, 05-android-companion-ui]

actuals:
  tokens: 12000
  tasks: 3
  commits: 2
  plan_head_before: d9d61999209f87c88b9bf2294f9b23b184ef4608
  plan_head_after: c7cefd584f22ae3f8c85ae69818ca8066f287413

tech-stack:
  added: []
  patterns:
    - Android 14+ FOREGROUND_SERVICE_TYPE_CONNECTED_DEVICE registration with NotificationCompat
    - MethodChannel for service intent dispatch (startForegroundService vs stopService)
    - Riverpod ref.listen synchronization between HID connection status and foreground session
    - Responsive Material 3 status chips and diagnostic card

key-files:
  created:
    - companion-app/android/app/src/main/kotlin/com/companion/companion_app/CompanionForegroundService.kt
    - companion-app/lib/features/foreground_service/foreground_service_manager.dart
    - companion-app/test/unit/foreground_service_manager_test.dart
  modified:
    - companion-app/android/app/src/main/kotlin/com/companion/companion_app/MainActivity.kt
    - companion-app/lib/main.dart

key-decisions:
  - "Configured NotificationManager.IMPORTANCE_LOW for the active session notification channel to prevent annoying audio/vibration alerts"
  - "Automated foreground service activation upon HID connection state transition to 'connected', with clean shutdown on 'disconnected'"
  - "Declared android:exported='false' on CompanionForegroundService in AndroidManifest.xml to enforce component encapsulation"

patterns-established:
  - "Lifecycle services bound via MethodChannel and managed reactively with Riverpod StateNotifier"
  - "HomeScreen status chips reflect live hardware and service states"

requirements-completed: [HID-05]

coverage:
  - id: D1
    description: "Android Foreground Service with foregroundServiceType='connectedDevice' and persistent notification"
    requirement: HID-05
    verification:
      - kind: unit
        ref: companion-app/test/unit/foreground_service_manager_test.dart
        status: pass
    human_judgment: false
  - id: D2
    description: "Reactive companion UI reflecting foreground service and Bluetooth HID state"
    requirement: HID-05
    verification:
      - kind: widget
        ref: companion-app/test/widget_test.dart
        status: pass
    human_judgment: false

duration: 10m
completed: 2026-11-12
status: complete
---

# Phase 02 Plan 02: Android Foreground Service & Lifecycle Summary

**Android 14+ compliant CompanionForegroundService (`foregroundServiceType="connectedDevice"`) implemented with persistent notification channel, automatic HID session lifecycle synchronization, and responsive HomeScreen status indicators.**

## Performance

- **Duration:** 10 min
- **Started:** 2026-11-12T11:28:00Z
- **Completed:** 2026-11-12T11:38:00Z
- **Tasks:** 3
- **Commits:** 2

## Accomplishments

1. **Native Android CompanionForegroundService:**
   - Implemented `CompanionForegroundService.kt` declaring `ServiceInfo.FOREGROUND_SERVICE_TYPE_CONNECTED_DEVICE` for Android 14+ (API 34+).
   - Configured `NotificationChannel` (`companion_active_session`) with `IMPORTANCE_LOW` and ongoing `NotificationCompat.Builder` targeting `MainActivity`.
   - Implemented clean termination with `stopForeground(STOP_FOREGROUND_REMOVE)` and `stopSelf()`.
   - Wired explicit Intent start/stop handling in `MainActivity.kt` under MethodChannel `com.companion.koder/service`.

2. **Flutter Service Lifecycle Bridge:**
   - Created `ForegroundServiceManager` and `ForegroundServiceNotifier` managing session states (`idle`, `running`, `error`).
   - Setup automatic synchronization with `bluetoothHidServiceProvider`: automatically starts the foreground service when HID status transitions to `connected` and terminates it on `disconnected`.
   - Developed unit test suite in `test/unit/foreground_service_manager_test.dart` verifying channel dispatch and state transitions.

3. **Companion UI Status Integration:**
   - Updated `HomeScreen` in `lib/main.dart` to a `ConsumerWidget`.
   - Added dynamic status chips for Bluetooth HID (`Connected` / `Disconnected`), WebSocket, and Foreground Service (`Active` / `Idle`).
   - Integrated live diagnostic output reflecting HID capability and active session status.

## Verification

- `flutter analyze`: Zero warnings, zero errors.
- `flutter test`: All 15 tests pass across unit and widget suites.
