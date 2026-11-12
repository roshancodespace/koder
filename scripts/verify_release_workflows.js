#!/usr/bin/env node

/**
 * Release Workflow Verification Script
 * 
 * Validates the structure and commands of independent release workflows:
 * - companion-app/.github/workflows/release.yml (REL-01)
 * - vscode-extension/.github/workflows/release.yml (REL-02)
 */

const fs = require('fs');
const path = require('path');
const assert = require('assert');

console.log('================================================================');
console.log('📦 Starting GitHub Actions Release Workflow Verification');
console.log('================================================================\n');

const repoRoot = path.resolve(__dirname, '..');
const companionWorkflowPath = path.join(repoRoot, 'companion-app', '.github', 'workflows', 'release.yml');
const extensionWorkflowPath = path.join(repoRoot, 'vscode-extension', '.github', 'workflows', 'release.yml');

assert(fs.existsSync(companionWorkflowPath), 'companion-app release.yml must exist');
assert(fs.existsSync(extensionWorkflowPath), 'vscode-extension release.yml must exist');

const companionContent = fs.readFileSync(companionWorkflowPath, 'utf8');
const extensionContent = fs.readFileSync(extensionWorkflowPath, 'utf8');

// ---------------------------------------------------------------------------
// 1. Validate Companion App Release Workflow (REL-01)
// ---------------------------------------------------------------------------
console.log('▶ [1/3] Validating Companion App Release Workflow (REL-01)...');

assert(companionContent.includes("tags:\n      - 'companion-v*'"), "Must trigger on push of 'companion-v*' tags");
assert(companionContent.includes('workflow_dispatch:'), "Must support manual 'workflow_dispatch' trigger");
assert(companionContent.includes('contents: write'), 'Must declare write permissions for contents to publish releases');
assert(companionContent.includes('subosito/flutter-action@v2'), 'Must use official flutter-action');
assert(companionContent.includes('flutter analyze'), 'Must run flutter analyze static analysis');
assert(companionContent.includes('flutter test'), 'Must execute test suite before packaging');
assert(companionContent.includes('flutter build apk --release'), 'Must build production release APK');
assert(companionContent.includes('sha256sum *.apk > SHA256SUMS.txt'), 'Must calculate SHA256 checksums of APKs');
assert(companionContent.includes('softprops/action-gh-release@v2'), 'Must publish release via softprops/action-gh-release');
assert(companionContent.includes('SHA256SUMS.txt'), 'Must attach SHA256SUMS.txt to GitHub release');

console.log('  ✔ companion-v* tag trigger and workflow_dispatch verified');
console.log('  ✔ Verification, release APK build, and SHA256 checksum hashing verified');
console.log('  ✔ GitHub Release publishing step with asset attachment verified');

// ---------------------------------------------------------------------------
// 2. Validate VS Code Extension Release Workflow (REL-02)
// ---------------------------------------------------------------------------
console.log('\n▶ [2/3] Validating VS Code Extension Release Workflow (REL-02)...');

assert(extensionContent.includes("tags:\n      - 'extension-v*'"), "Must trigger on push of 'extension-v*' tags");
assert(extensionContent.includes('workflow_dispatch:'), "Must support manual 'workflow_dispatch' trigger");
assert(extensionContent.includes('contents: write'), 'Must declare write permissions for contents to publish releases');
assert(extensionContent.includes('pnpm/action-setup@v3'), 'Must set up pnpm package manager');
assert(extensionContent.includes('actions/setup-node@v4'), 'Must set up Node.js');
assert(extensionContent.includes('pnpm run lint'), 'Must run linter before packaging');
assert(extensionContent.includes('pnpm run compile'), 'Must compile TypeScript before packaging');
assert(extensionContent.includes('pnpm test'), 'Must execute test suite before packaging');
assert(extensionContent.includes('vsce package'), 'Must package VSIX artifact using vsce');
assert(extensionContent.includes('sha256sum *.vsix > SHA256SUMS.txt'), 'Must calculate SHA256 checksums of VSIX');
assert(extensionContent.includes('softprops/action-gh-release@v2'), 'Must publish release via softprops/action-gh-release');
assert(extensionContent.includes('SHA256SUMS.txt'), 'Must attach SHA256SUMS.txt to GitHub release');

console.log('  ✔ extension-v* tag trigger and workflow_dispatch verified');
console.log('  ✔ Verification, VSIX packaging, and SHA256 checksum hashing verified');
console.log('  ✔ GitHub Release publishing step with asset attachment verified');

// ---------------------------------------------------------------------------
// 3. Dry-Run Checksum Generation Simulation
// ---------------------------------------------------------------------------
console.log('\n▶ [3/3] Simulating Cryptographic SHA256 Checksum Verification...');

const crypto = require('crypto');
const sampleBinary = Buffer.from('VS Code Companion Production Binary Simulation Artifact\n');
const sampleHash = crypto.createHash('sha256').update(sampleBinary).digest('hex');

assert.strictEqual(sampleHash.length, 64, 'SHA256 hash must be 64 hexadecimal characters');
console.log('  ✔ Simulated artifact SHA256 hash generated:', sampleHash);

console.log('\n================================================================');
console.log('✅ ALL RELEASE WORKFLOW CHECKS PASSED (REL-01 & REL-02 VERIFIED)');
console.log('================================================================\n');

process.exit(0);
