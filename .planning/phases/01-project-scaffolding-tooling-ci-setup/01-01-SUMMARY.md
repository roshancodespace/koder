---
phase: 01-project-scaffolding-tooling-ci-setup
plan: 01
subsystem: mobile
tags: [flutter, material3, riverpod, android, bluetooth-hid, foreground-service, github-actions]

requires: []
provides:
  - Standalone Android companion application skeleton in companion-app/ with Flutter 3.41.9 / Dart 3.11.5
  - Material 3 theming (light/dark) seeded with Colors.indigo and Riverpod ProviderScope root
  - Native Android permissions for Bluetooth HID and Android 14+ connectedDevice foreground service
  - Independent GitHub Actions CI pipeline executing format, analysis, tests, and debug APK build
affects: [01-project-scaffolding-tooling-ci-setup, 02-native-bluetooth-hid-foundation]

actuals:
  tokens: 9498
  tasks: 3
  commits: 3
  plan_head_before: 9236755baa7bdb9e1c3c5cd23b543947b34594c8
  plan_head_after: 299fb0358a2ce5342927a0477d83f263339054da

tech-stack:
  added:
    - flutter_riverpod: ^2.6.1
    - sqflite: ^2.4.1
    - path: ^1.9.0
    - web_socket_channel: ^3.0.1
    - archive: ^4.0.2
    - http: ^1.3.0
    - crypto: ^3.0.6
    - flutter_lints: ^5.0.0
  patterns:
    - Material 3 with dynamic seed colorScheme
    - Riverpod ProviderScope at root widget hierarchy
    - Defensive Android 14+ connectedDevice foreground service registration

key-files:
  created:
    - companion-app/pubspec.yaml
    - companion-app/analysis_options.yaml
    - companion-app/lib/main.dart
    - companion-app/lib/core/constants.dart
    - companion-app/test/widget_test.dart
    - companion-app/test/unit/app_smoke_test.dart
    - companion-app/.github/workflows/ci.yml
  modified:
    - companion-app/android/app/src/main/AndroidManifest.xml
    - companion-app/android/app/build.gradle.kts

key-decisions:
  - "Decoupled companion-app from workspace root with self-contained CI workflow"
  - "Configured Android minSdk=28 and targetSdk=35 to support BluetoothHidDevice and Android 14+ connectedDevice foreground service requirements"
  - "Extracted application constants into lib/core/constants.dart for centralized protocol and network parameters"

patterns-established:
  - "Root CompanionApp wraps ProviderScope for declarative Riverpod state management"
  - "Material 3 light and dark themes derived from Colors.indigo seed"

requirements-completed: [UI-01, CI-01]

coverage:
  - id: D1
    description: "Flutter Material 3 companion app skeleton with core runtime dependencies"
    requirement: UI-01
    verification:
      - kind: unit
        ref: companion-app/test/widget_test.dart
        status: pass
    human_judgment: false
  - id: D2
    description: "Native Android manifest and Gradle build config with API 28+ minSdk and connectedDevice foreground service"
    requirement: UI-01
    verification:
      - kind: unit
        ref: companion-app/test/unit/app_smoke_test.dart
        status: pass
    human_judgment: false
  - id: D3
    description: "Independent GitHub Actions CI workflow for companion-app"
    requirement: CI-01
    verification:
      - kind: other
        ref: "test -f companion-app/.github/workflows/ci.yml && grep -q 'flutter analyze' companion-app/.github/workflows/ci.yml"
        status: pass
    human_judgment: false

duration: 7m
completed: 2026-11-12
status: complete
---

# Phase 01 Plan 01: Flutter Companion App Scaffolding & CI Summary

**Standalone Android companion app skeleton established in companion-app/ with Flutter 3.41.9, Material 3 theming, Riverpod state management, native Bluetooth HID and connectedDevice permissions, and independent GitHub Actions CI.**

## Performance

- **Duration:** 7 min
- **Started:** 2026-11-12T10:50:30Z
- **Completed:** 2026-11-12T10:57:30Z
- **Tasks:** 3
- **Files modified:** 29

## Accomplishments

- Initialized independent `companion-app/` Flutter project configured with Flutter 3.41.9 / Dart 3.11.5, Material 3, and strict linting rules.
- Configured essential runtime dependencies: `flutter_riverpod`, `sqflite`, `path`, `web_socket_channel`, `archive`, `http`, and `crypto`.
- Configured Android platform manifest permissions (`BLUETOOTH_CONNECT`, `BLUETOOTH_SCAN`, `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_CONNECTED_DEVICE`, `POST_NOTIFICATIONS`) and set `minSdk = 28` and `compileSdk = 35` in `build.gradle.kts`.
- Created unit and widget test suites covering UI rendering, Riverpod provider initialization, theme consistency, and protocol constants.
- Configured independent GitHub Actions CI workflow in `companion-app/.github/workflows/ci.yml` verifying code format, static analysis, test suite, and debug APK compilation.

## Task Commits

Each task was committed atomically:

1. **Task 1: Scaffold Flutter Material 3 companion app skeleton with core dependencies** - `83dad05` (feat)
2. **Task 2: Configure Android platform manifest permissions and unit test suite** - `4606ada` (feat)
3. **Task 3: Establish companion-app GitHub Actions CI workflow** - `299fb03` (ci)

## Files Created/Modified

- `companion-app/pubspec.yaml` - Project manifest with locked SDK constraints and required runtime/dev dependencies.
- `companion-app/analysis_options.yaml` - Strict analyzer language rules and flutter_lints configuration.
- `companion-app/lib/main.dart` - Material 3 application entry point with ProviderScope, light/dark themes, and connection chips.
- `companion-app/lib/core/constants.dart` - Centralized application constants (default host, port, protocol version).
- `companion-app/test/widget_test.dart` - Widget smoke test for HomeScreen title and connection chips.
- `companion-app/test/unit/app_smoke_test.dart` - Unit test verifying Riverpod initialization, themes, and protocol constants.
- `companion-app/android/app/src/main/AndroidManifest.xml` - Native permissions and connectedDevice foreground service.
- `companion-app/android/app/build.gradle.kts` - Android build settings with minSdk 28 and targetSdk 35.
- `companion-app/.github/workflows/ci.yml` - Independent GitHub Actions workflow.

## Decisions Made

- Decoupled `companion-app/` from workspace root to guarantee independent CI/CD execution per project architecture.
- Configured Android `minSdk = 28` because `BluetoothHidDevice` APIs require Android 9+ (API 28).
- Set `android:foregroundServiceType="connectedDevice"` with `android:exported="false"` to comply with Android 14+ background execution constraints and prevent unauthorized intent dispatching.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing Critical] Added centralized protocol and network constants**
- **Found during:** Task 2 (Unit test suite setup)
- **Issue:** Unit tests needed standard protocol constants to validate configuration without hardcoded magic numbers.
- **Fix:** Created `companion-app/lib/core/constants.dart` defining default WebSocket host (`127.0.0.1`), port (`38848`), and minimum Android SDK (`28`).
- **Files modified:** `companion-app/lib/core/constants.dart`
- **Verification:** `flutter test test/unit/app_smoke_test.dart` passed with all assertions verified.
- **Committed in:** `4606ada` (Task 2 commit)

---

**Total deviations:** 1 auto-fixed (1 missing critical)
**Impact on plan:** Completely aligned with architecture and zero scope creep.

## Issues Encountered

- Initial `flutter create` command required `--project-name companion_app` because the destination directory was named `companion-app`. Resolved immediately by providing the project name flag.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Android foundation is fully prepared for native Kotlin Bluetooth HID platform channel integration (Phase 2).
- CI workflow is operational and isolated to `companion-app/`.

---
*Phase: 01-project-scaffolding-tooling-ci-setup*
*Completed: 2026-11-12*
