import * as assert from 'assert';
import * as vscode from 'vscode';

suite('VS Code Companion Extension Test Suite', () => {
  vscode.window.showInformationMessage('Start all tests.');

  test('Status command should be registered in commands list', async () => {
    const commands = await vscode.commands.getCommands(true);
    assert.ok(
      commands.includes('vscode-companion.status'),
      'Command vscode-companion.status should be registered'
    );
  });
});
