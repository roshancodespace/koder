import * as vscode from 'vscode';
import { validateWorkspacePath } from './pathValidator';

/**
 * Creates a file within the given workspace folder safely.
 *
 * Enforces:
 * 1. Path traversal prevention (cannot escape workspace root)
 * 2. Collision detection via workspace.fs.stat (no implicit overwriting)
 * 3. Recursive directory creation via workspace.fs.createDirectory
 * 4. Writing empty or provided content via workspace.fs.writeFile
 * 5. Optional opening of the created document in the active editor
 *
 * @param workspaceFolder Target workspace folder
 * @param relativePath Relative file path
 * @param content Optional file content
 * @param openInEditor Whether to open document after creation (default: true)
 * @returns The resolved vscode.Uri of the created file
 */
export async function createWorkspaceFileSafely(
  workspaceFolder: vscode.WorkspaceFolder,
  relativePath: string,
  content?: Uint8Array,
  openInEditor = true
): Promise<vscode.Uri> {
  // Validate path boundaries
  const targetUri = validateWorkspacePath(workspaceFolder, relativePath);

  // Check if file already exists (prevent implicit overwrite)
  try {
    await vscode.workspace.fs.stat(targetUri);
    // If stat succeeds, the file or directory exists -> throw collision error
    throw new Error('FILE_ALREADY_EXISTS: Cannot overwrite existing file implicitly');
  } catch (err: unknown) {
    if (err instanceof Error && err.message.includes('FILE_ALREADY_EXISTS')) {
      throw err;
    }
    // If stat fails with FileNotFound / EntryNotFound, file doesn't exist -> safe to create
    const isFileNotFound =
      err instanceof vscode.FileSystemError &&
      (err.code === 'FileNotFound' || err.code === 'EntryNotFound');

    const message = (err as Error)?.message || '';
    if (!isFileNotFound && !message.includes('FileNotFound') && !message.includes('EntryNotFound')) {
      // Re-throw unexpected filesystem errors
      throw err;
    }
  }

  // Ensure parent directory exists recursively
  const parentDirUri = vscode.Uri.joinPath(targetUri, '..');
  await vscode.workspace.fs.createDirectory(parentDirUri);

  // Write content (empty array if not provided)
  await vscode.workspace.fs.writeFile(targetUri, content ?? new Uint8Array());

  // Optionally reveal document in editor
  if (openInEditor) {
    try {
      const doc = await vscode.workspace.openTextDocument(targetUri);
      await vscode.window.showTextDocument(doc);
    } catch {
      // Non-fatal if opening UI document fails in headless test
    }
  }

  return targetUri;
}
