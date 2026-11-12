---
phase: 06-end-to-end-integration-release-automation-verification
plan: 02
subsystem: ci-cd
tags: [github-actions, release, apk, vsix, sha256, automation]

requires: [06-01]
provides:
  - Independent Android companion release workflow (.github/workflows/release.yml) building release APKs with SHA256 checksums
  - Independent VS Code extension release workflow (.github/workflows/release.yml) packaging production VSIX extensions with SHA256 checksums
  - GitHub Releases publication for both subprojects on companion-v* and extension-v* version tags and workflow_dispatch
  - Automated release workflow configuration validator (scripts/verify_release_workflows.js)
affects: [06-end-to-end-integration-release-automation-verification]

actuals:
  tokens: 18000
  tasks: 3
  commits: 1
  plan_head_before: adfe120fa2c4155b1a37cce1f422eec74b886c95
  plan_head_after: HEAD

tech-stack:
  added: []
  patterns:
    - Decoupled release workflows triggered by subproject-prefixed version tags
    - Mandatory cryptographic SHA256 checksum generation attached alongside binaries
    - Automated GitHub Release publication with auto-generated release notes

key-files:
  created:
    - companion-app/.github/workflows/release.yml
    - vscode-extension/.github/workflows/release.yml
    - scripts/verify_release_workflows.js

key-decisions:
  - "Configured companion-app release workflow triggered on 'companion-v*' tags and manual 'workflow_dispatch'"
  - "Configured vscode-extension release workflow triggered on 'extension-v*' tags and manual 'workflow_dispatch'"
  - "Mandated generation of SHA256SUMS.txt in both pipelines ensuring tamper-evident release distribution"
  - "Utilized softprops/action-gh-release@v2 with auto-generated release notes and write permissions"

requirements-completed: [REL-01, REL-02]

coverage:
  - id: D1
    description: "companion-app includes .github/workflows/release.yml building release APKs with SHA256 checksums and publishing GitHub releases on companion-v* tags"
    requirement: REL-01
    verification:
      - kind: automated
        ref: scripts/verify_release_workflows.js
        status: pass
    human_judgment: false
  - id: D2
    description: "vscode-extension includes .github/workflows/release.yml packaging production VSIX extensions with SHA256 checksums and publishing GitHub releases on extension-v* tags"
    requirement: REL-02
    verification:
      - kind: automated
        ref: scripts/verify_release_workflows.js
        status: pass
    human_judgment: false

audit-notes:
  - "All release workflow structure checks pass with 0 errors."
  - "Both subprojects have completely decoupled release pipelines."
---

# Plan 06-02 Summary: Independent GitHub Actions Release Pipelines with SHA256 Checksums

Plan 06-02 implemented independent, production-grade release automation workflows for both subprojects, fulfilling requirements REL-01 and REL-02.

## Key Accomplishments

1. **Android Companion Release Pipeline (`companion-app/.github/workflows/release.yml`)**:
   - Triggered on push of version tags matching `companion-v*` (e.g. `companion-v0.1.0`) and on manual `workflow_dispatch`.
   - Executes code formatting check, static analysis (`flutter analyze`), and unit/widget tests.
   - Builds release APK via `flutter build apk --release`.
   - Computes cryptographic SHA256 checksums of built APK files and writes to `SHA256SUMS.txt`.
   - Publishes GitHub Release using `softprops/action-gh-release@v2` attaching APKs and `SHA256SUMS.txt` with auto-generated release notes.

2. **VS Code Extension Release Pipeline (`vscode-extension/.github/workflows/release.yml`)**:
   - Triggered on push of version tags matching `extension-v*` (e.g. `extension-v0.1.0`) and on manual `workflow_dispatch`.
   - Sets up pnpm 9 and Node.js 20.x, running ESLint, TypeScript compilation, and headless tests (`xvfb-run`).
   - Packages production VSIX extension using `npx @vscode/vsce package --no-dependencies --no-git-tag-version`.
   - Computes cryptographic SHA256 checksums of packaged `.vsix` files and writes to `SHA256SUMS.txt`.
   - Publishes GitHub Release using `softprops/action-gh-release@v2` attaching the VSIX and `SHA256SUMS.txt` with auto-generated release notes.

3. **Automated Release Pipeline Validation (`scripts/verify_release_workflows.js`)**:
   - Automated script parsed both YAML workflow files, verifying triggers, compilation targets, checksum steps, and release publishing actions.
   - Simulated cryptographic SHA256 hashing conforming to 64-character hexadecimal format.
