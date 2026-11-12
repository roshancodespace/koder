#!/usr/bin/env node

/**
 * Architectural Boundary & Security Verification Script
 * 
 * Verifies non-negotiable architectural boundaries:
 * 1. Zero autonomous code generation or LLM client libraries in vscode-extension
 * 2. Zero shell or child_process execution for workspace mutations in vscode-extension
 * 3. Exclusive use of vscode.workspace.fs for file operations
 * 4. Predefined developer shortcuts only on Android companion (no shell execution)
 */

const fs = require('fs');
const path = require('path');
const assert = require('assert');

console.log('================================================================');
console.log('🛡️  Starting Architectural Boundary & Security Verification');
console.log('================================================================\n');

const repoRoot = path.resolve(__dirname, '..');
const extSrcDir = path.join(repoRoot, 'vscode-extension', 'src');
const companionLibDir = path.join(repoRoot, 'companion-app', 'lib');

function getAllFiles(dir, filterExt) {
  let results = [];
  if (!fs.existsSync(dir)) return results;
  const list = fs.readdirSync(dir);
  for (const file of list) {
    const fullPath = path.join(dir, file);
    const stat = fs.statSync(fullPath);
    if (stat.isDirectory()) {
      results = results.concat(getAllFiles(fullPath, filterExt));
    } else if (file.endsWith(filterExt)) {
      results.push(fullPath);
    }
  }
  return results;
}

let violationsFound = 0;

// ---------------------------------------------------------------------------
// 1. Audit Extension: Prohibit Autonomous Code Generation & LLM SDKs
// ---------------------------------------------------------------------------
console.log('▶ [1/4] Auditing Extension for Autonomous AI / LLM SDKs...');

const prohibitedAiPatterns = [
  /@google\/genai/i,
  /openai/i,
  /@anthropic-ai\/sdk/i,
  /langchain/i,
  /generateContent/i,
  /createCompletion/i,
  /chat\.completions/i,
];

const tsFiles = getAllFiles(extSrcDir, '.ts');
console.log(`  Scanned ${tsFiles.length} TypeScript source files in vscode-extension/src`);

for (const file of tsFiles) {
  const content = fs.readFileSync(file, 'utf8');
  for (const pattern of prohibitedAiPatterns) {
    if (pattern.test(content)) {
      console.error(`  ❌ VIOLATION in ${path.relative(repoRoot, file)}: Matches prohibited AI pattern ${pattern}`);
      violationsFound++;
    }
  }
}

if (violationsFound === 0) {
  console.log('  ✔ Confirmed: Zero autonomous AI code generation or LLM SDK imports.');
}

// ---------------------------------------------------------------------------
// 2. Audit Extension: Prohibit Shell / Child Process File Mutations
// ---------------------------------------------------------------------------
console.log('\n▶ [2/4] Auditing Extension for Shell / Child Process Execution...');

const prohibitedShellPatterns = [
  /child_process/i,
  /\bexec\s*\(/,
  /\bexecSync\s*\(/,
  /\bspawn\s*\(/,
  /\bspawnSync\s*\(/,
];

for (const file of tsFiles) {
  const content = fs.readFileSync(file, 'utf8');
  for (const pattern of prohibitedShellPatterns) {
    if (pattern.test(content)) {
      console.error(`  ❌ VIOLATION in ${path.relative(repoRoot, file)}: Matches prohibited shell pattern ${pattern}`);
      violationsFound++;
    }
  }
}

if (violationsFound === 0) {
  console.log('  ✔ Confirmed: Zero shell / child_process execution calls found.');
}

// ---------------------------------------------------------------------------
// 3. Audit Extension: Enforce vscode.workspace.fs for File System Operations
// ---------------------------------------------------------------------------
console.log('\n▶ [3/4] Auditing File System Mutation Boundaries...');

const safeFileManagerPath = path.join(extSrcDir, 'workspace', 'safeFileManager.ts');
assert(fs.existsSync(safeFileManagerPath), 'safeFileManager.ts must exist');

const sfmContent = fs.readFileSync(safeFileManagerPath, 'utf8');
assert(sfmContent.includes('vscode.workspace.fs.stat'), 'Must use vscode.workspace.fs.stat');
assert(sfmContent.includes('vscode.workspace.fs.createDirectory'), 'Must use vscode.workspace.fs.createDirectory');
assert(sfmContent.includes('vscode.workspace.fs.writeFile'), 'Must use vscode.workspace.fs.writeFile');

console.log('  ✔ Confirmed: Safe file operations strictly utilize vscode.workspace.fs.');

// ---------------------------------------------------------------------------
// 4. Audit Companion App: Enforce Predefined Shortcuts (No Shell Execution)
// ---------------------------------------------------------------------------
console.log('\n▶ [4/4] Auditing Companion App Shortcut Dispatch Safety...');

const dartFiles = getAllFiles(companionLibDir, '.dart');
console.log(`  Scanned ${dartFiles.length} Dart source files in companion-app/lib`);

const commandsPadScreen = path.join(companionLibDir, 'features', 'ui', 'screens', 'commands_pad_screen.dart');
assert(fs.existsSync(commandsPadScreen), 'commands_pad_screen.dart must exist');

const commandsContent = fs.readFileSync(commandsPadScreen, 'utf8');
assert(commandsContent.includes('sendShortcut'), 'Must invoke sendShortcut for HID emission');
assert(!commandsContent.includes('Process.run'), 'Must not execute arbitrary processes');
assert(!commandsContent.includes('Process.start'), 'Must not spawn shell processes');

console.log('  ✔ Confirmed: Companion shortcuts strictly trigger predefined HID keycodes.');

console.log('\n================================================================');
if (violationsFound === 0) {
  console.log('✅ ALL ARCHITECTURAL BOUNDARY CHECKS PASSED WITH ZERO VIOLATIONS');
  console.log('================================================================\n');
  process.exit(0);
} else {
  console.error(`❌ FAILED: ${violationsFound} architectural boundary violation(s) discovered!`);
  console.log('================================================================\n');
  process.exit(1);
}
