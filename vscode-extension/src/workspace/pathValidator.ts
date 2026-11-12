import * as vscode from 'vscode';
import * as path from 'path';

/**
 * Validates that a user-supplied relative path does not escape the given workspace folder root.
 *
 * @param workspaceFolder The base workspace folder.
 * @param relativePath The target path relative to the workspace folder.
 * @returns The resolved canonical target vscode.Uri.
 * @throws Error if path contains null bytes, invalid characters, or traverses outside the workspace folder.
 */
export function validateWorkspacePath(
  workspaceFolder: vscode.WorkspaceFolder,
  relativePath: string
): vscode.Uri {
  if (!relativePath || relativePath.trim() === '') {
    throw new Error('INVALID_PATH: Path cannot be empty');
  }

  // Reject null bytes (path injection guard)
  if (relativePath.includes('\0')) {
    throw new Error('INVALID_PATH: Path contains illegal null byte');
  }

  // Strip leading path separators (both POSIX and Windows)
  const sanitizedPath = relativePath.replace(/^[/\\]+/, '');

  // Normalize path segments
  const normalizedPath = path.normalize(sanitizedPath);

  // Join URI with workspace folder
  const targetUri = vscode.Uri.joinPath(workspaceFolder.uri, normalizedPath);

  // Normalize fsPath representations for boundary checking
  const rootPath = path.resolve(workspaceFolder.uri.fsPath);
  const targetFsPath = path.resolve(targetUri.fsPath);

  // Check if target path starts with the workspace root and is separated by delimiter
  const isInside =
    targetFsPath === rootPath ||
    targetFsPath.startsWith(rootPath + path.sep);

  if (!isInside) {
    throw new Error('PATH_TRAVERSAL_DETECTED: Target path is outside workspace root');
  }

  return targetUri;
}
