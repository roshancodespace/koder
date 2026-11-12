import * as assert from 'assert';
import * as vscode from 'vscode';
import { validateWorkspacePath } from '../src/workspace/pathValidator';

suite('Workspace PathValidator & Safety Tests', () => {
  const dummyWorkspaceFolder: vscode.WorkspaceFolder = {
    uri: vscode.Uri.file('/tmp/koder-test-workspace'),
    name: 'koder-test-workspace',
    index: 0,
  };

  test('valid relative path resolves inside workspace folder', () => {
    const targetUri = validateWorkspacePath(dummyWorkspaceFolder, 'src/components/button.tsx');
    assert.strictEqual(
      targetUri.fsPath,
      vscode.Uri.file('/tmp/koder-test-workspace/src/components/button.tsx').fsPath
    );
  });

  test('path with leading slashes is stripped and normalized inside workspace', () => {
    const targetUri = validateWorkspacePath(dummyWorkspaceFolder, '///utils/helpers.ts');
    assert.strictEqual(
      targetUri.fsPath,
      vscode.Uri.file('/tmp/koder-test-workspace/utils/helpers.ts').fsPath
    );
  });

  test('path traversal attempting to escape root throws PATH_TRAVERSAL_DETECTED', () => {
    assert.throws(() => {
      validateWorkspacePath(dummyWorkspaceFolder, '../../etc/passwd');
    }, /PATH_TRAVERSAL_DETECTED/);

    assert.throws(() => {
      validateWorkspacePath(dummyWorkspaceFolder, '../outside.txt');
    }, /PATH_TRAVERSAL_DETECTED/);
  });

  test('empty path throws INVALID_PATH', () => {
    assert.throws(() => {
      validateWorkspacePath(dummyWorkspaceFolder, '');
    }, /INVALID_PATH/);

    assert.throws(() => {
      validateWorkspacePath(dummyWorkspaceFolder, '   ');
    }, /INVALID_PATH/);
  });

  test('path containing null byte throws INVALID_PATH', () => {
    assert.throws(() => {
      validateWorkspacePath(dummyWorkspaceFolder, 'file\0.txt');
    }, /INVALID_PATH/);
  });
});
