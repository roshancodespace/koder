import * as vscode from 'vscode';
import { createWorkspaceFileSafely } from '../workspace/safeFileManager';

/**
 * Validates file path input entered into the input box.
 */
export function validateFileInput(value: string): string | null {
  if (!value || value.trim().length === 0) {
    return 'File path cannot be empty';
  }
  if (value.includes('\0')) {
    return 'File path cannot contain null bytes';
  }
  return null;
}

/**
 * Executes the interactive nested file creation workflow.
 */
export async function executeCreateFileWorkflow(): Promise<vscode.Uri | undefined> {
  const folders = vscode.workspace.workspaceFolders;
  if (!folders || folders.length === 0) {
    vscode.window.showErrorMessage('No active workspace folder open');
    return undefined;
  }

  let selectedFolder: vscode.WorkspaceFolder;

  if (folders.length === 1) {
    selectedFolder = folders[0];
  } else {
    // Multi-root workspace: prompt user to select destination workspace folder
    interface FolderQuickPickItem extends vscode.QuickPickItem {
      folder: vscode.WorkspaceFolder;
    }

    const items: FolderQuickPickItem[] = folders.map((folder) => ({
      label: folder.name,
      description: folder.uri.fsPath,
      folder,
    }));

    const picked = await vscode.window.showQuickPick(items, {
      placeHolder: 'Select target workspace folder',
      matchOnDescription: true,
    });

    if (!picked) {
      return undefined;
    }

    selectedFolder = picked.folder;
  }

  // Prompt user for nested relative path
  const inputPath = await vscode.window.showInputBox({
    prompt: 'Enter relative file path (e.g. src/utils/helper.ts)',
    placeHolder: 'path/to/file.ext',
    validateInput: validateFileInput,
  });

  if (!inputPath || inputPath.trim().length === 0) {
    return undefined;
  }

  const normalizedInput = inputPath.trim();

  try {
    const createdUri = await createWorkspaceFileSafely(selectedFolder, normalizedInput);
    vscode.window.showInformationMessage(`Created ${normalizedInput}`);
    return createdUri;
  } catch (err: unknown) {
    const message = err instanceof Error ? err.message : String(err);

    if (message.includes('PATH_TRAVERSAL_DETECTED')) {
      vscode.window.showErrorMessage('Cannot create file outside active workspace folder');
    } else if (message.includes('FILE_ALREADY_EXISTS')) {
      vscode.window.showErrorMessage('File already exists: implicit overwrite is forbidden');
    } else {
      vscode.window.showErrorMessage(`Failed to create file: ${message}`);
    }
    return undefined;
  }
}

/**
 * Registers the 'vscode-companion.createFile' command.
 */
export function registerCreateFileCommand(context: vscode.ExtensionContext): vscode.Disposable {
  const disposable = vscode.commands.registerCommand(
    'vscode-companion.createFile',
    async () => {
      return executeCreateFileWorkflow();
    }
  );

  context.subscriptions.push(disposable);
  return disposable;
}
