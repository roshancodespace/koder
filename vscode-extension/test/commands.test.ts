import * as assert from 'assert';
import * as vscode from 'vscode';
import { validateFileInput } from '../src/commands/createFileCommand';
import { validateWorkspacePath } from '../src/workspace/pathValidator';
import { EditorState } from '../src/editor/editorMonitor';

suite('Commands & Interactive Creation Workflow Test Suite', () => {
  const dummyWorkspaceFolder: vscode.WorkspaceFolder = {
    uri: vscode.Uri.file('/tmp/koder-commands-test'),
    name: 'koder-commands-test',
    index: 0,
  };

  suiteSetup(async () => {
    let ext = vscode.extensions.getExtension('companion.vscode-companion');
    if (!ext) {
      ext = vscode.extensions.all.find((e) => e.packageJSON?.name === 'vscode-companion');
    }
    if (ext && !ext.isActive) {
      await ext.activate();
    }
  });

  test('validateFileInput correctly validates file paths', () => {
    assert.strictEqual(validateFileInput(''), 'File path cannot be empty');
    assert.strictEqual(validateFileInput('   '), 'File path cannot be empty');
    assert.strictEqual(validateFileInput('bad\0path.ts'), 'File path cannot contain null bytes');
    assert.strictEqual(validateFileInput('src/components/card.tsx'), null);
    assert.strictEqual(validateFileInput('notes.md'), null);
  });

  test('vscode-companion.createFile command should be registered in vscode.commands', async () => {
    let commands = await vscode.commands.getCommands(true);
    if (!commands.includes('vscode-companion.createFile')) {
      const ext = vscode.extensions.getExtension('companion.vscode-companion') ||
        vscode.extensions.all.find((e) => e.packageJSON?.name === 'vscode-companion');
      if (ext && !ext.isActive) {
        await ext.activate();
      }
      commands = await vscode.commands.getCommands(true);
    }
    assert.ok(
      commands.includes('vscode-companion.createFile'),
      'Command vscode-companion.createFile should be registered'
    );
  });

  test('vscode-companion.getEditorState command returns valid EditorState structure', async () => {
    const state = await vscode.commands.executeCommand<EditorState>('vscode-companion.getEditorState');
    assert.ok(state, 'Editor state should be returned');
    assert.ok(Array.isArray(state.workspaceFolders), 'workspaceFolders should be an array');
    assert.ok(state.diagnostics !== undefined, 'diagnostics should be defined');
    assert.strictEqual(typeof state.diagnostics.errorCount, 'number');
    assert.strictEqual(typeof state.diagnostics.warningCount, 'number');
    assert.strictEqual(typeof state.timestamp, 'number');
  });

  test('traversal path ../../outside.ts throws PATH_TRAVERSAL_DETECTED error', () => {
    assert.throws(() => {
      validateWorkspacePath(dummyWorkspaceFolder, '../../outside.ts');
    }, /PATH_TRAVERSAL_DETECTED/);
  });
});
