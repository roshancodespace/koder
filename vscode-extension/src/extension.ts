import * as vscode from 'vscode';
import { EditorMonitor, EditorState } from './editor/editorMonitor';
import { validateWorkspacePath } from './workspace/pathValidator';
import { createWorkspaceFileSafely } from './workspace/safeFileManager';
import { registerCreateFileCommand } from './commands/createFileCommand';
import { showConnectionDetails } from './commands/connectionDetailsCommand';
import { AuthManager } from './network/authManager';
import { ServerManager } from './network/serverManager';

let statusBarItem: vscode.StatusBarItem;
let editorMonitor: EditorMonitor;
let authManager: AuthManager;
let serverManager: ServerManager;

export function activate(context: vscode.ExtensionContext): void {
  // Initialize EditorMonitor
  editorMonitor = new EditorMonitor();
  context.subscriptions.push(editorMonitor);

  // Initialize Network Auth & Server Manager
  authManager = new AuthManager();
  serverManager = new ServerManager(authManager);
  context.subscriptions.push(serverManager);

  // Register internal request handlers for companion RPC calls
  serverManager.registerRequestHandler('editor.getState', async () => {
    return editorMonitor.getCurrentState() as unknown as Record<string, unknown>;
  });

  serverManager.registerRequestHandler('editor.getActiveContent', async () => {
    const state = editorMonitor.getCurrentState();
    return {
      activeFileUri: state.activeFileUri,
      relativePath: state.relativePath,
      content: state.activeContent ?? '',
      lineCount: state.lineCount ?? 0,
      cursorPosition: (state.cursorPosition ?? null) as unknown as Record<string, unknown>,
      tabSize: state.tabSize ?? 2,
      insertSpaces: state.insertSpaces ?? true,
      languageId: state.languageId,
    };
  });

  serverManager.registerRequestHandler('editor.getFileContent', async (payload) => {
    const relPath = payload.path as string | undefined;
    if (!relPath) {
      throw new Error('Missing "path" in payload');
    }
    const folders = vscode.workspace.workspaceFolders;
    if (!folders || folders.length === 0) {
      throw new Error('No workspace folder open in VS Code');
    }
    const targetUri = validateWorkspacePath(folders[0], relPath);
    const fileBytes = await vscode.workspace.fs.readFile(targetUri);
    const content = Buffer.from(fileBytes).toString('utf8');
    return {
      path: relPath,
      content,
    };
  });

  serverManager.registerRequestHandler('system.info', async () => {
    return {
      vscodeVersion: vscode.version,
      appName: vscode.env.appName,
      port: serverManager.getActivePort(),
    };
  });

  serverManager.registerRequestHandler('workspace.prepareFile', async (payload) => {
    const relPath = (payload.path || payload.relativePath) as string | undefined;
    if (!relPath) {
      throw new Error('Missing "path" or "relativePath" in payload');
    }
    const folders = vscode.workspace.workspaceFolders;
    if (!folders || folders.length === 0) {
      throw new Error('No workspace folder open in VS Code');
    }
    const targetUri = validateWorkspacePath(folders[0], relPath);

    let exists = false;
    try {
      await vscode.workspace.fs.stat(targetUri);
      exists = true;
    } catch {
      exists = false;
    }

    if (!exists) {
      const parentDirUri = vscode.Uri.joinPath(targetUri, '..');
      await vscode.workspace.fs.createDirectory(parentDirUri);
      await vscode.workspace.fs.writeFile(targetUri, new Uint8Array());
    }

    const doc = await vscode.workspace.openTextDocument(targetUri);
    const editor = await vscode.window.showTextDocument(doc, {
      preview: false,
      viewColumn: vscode.ViewColumn.One,
      preserveFocus: false,
    });

    const startPos = new vscode.Position(0, 0);
    editor.selection = new vscode.Selection(startPos, startPos);

    return {
      success: true,
      relativePath: relPath,
      uri: targetUri.toString(),
      created: !exists,
    };
  });

  serverManager.registerRequestHandler('workspace.createFile', async (payload) => {
    const relPath = (payload.path || payload.relativePath) as string | undefined;
    if (!relPath) {
      throw new Error('Missing "path" or "relativePath" in payload');
    }
    const folders = vscode.workspace.workspaceFolders;
    if (!folders || folders.length === 0) {
      throw new Error('No workspace folder open in VS Code');
    }
    const targetUri = await createWorkspaceFileSafely(folders[0], relPath);
    return {
      success: true,
      uri: targetUri.toString(),
      path: relPath,
    };
  });

  // Start the WebSocket server asynchronously
  serverManager.start().catch((err: unknown) => {
    const message = err instanceof Error ? err.message : String(err);
    vscode.window.showWarningMessage(`VS Code Companion: ${message}`);
  });

  // Create a status bar item with alignment Right (priority 100)
  statusBarItem = vscode.window.createStatusBarItem(vscode.StatusBarAlignment.Right, 100);
  statusBarItem.command = 'vscode-companion.showConnectionDetails';
  updateStatusBar(editorMonitor.getCurrentState());
  statusBarItem.show();

  // Listen to editor state changes, broadcast over WebSocket, and update status bar
  editorMonitor.onDidChangeEditorState((state) => {
    serverManager.broadcastEvent('editor.stateChanged', state as unknown as Record<string, unknown>);
    updateStatusBar(state);
  });

  // Listen to client count changes and update status bar
  serverManager.onDidChangeClientCount(() => {
    updateStatusBar(editorMonitor.getCurrentState());
  });

  // Register status command to show an information message
  const statusCommand = vscode.commands.registerCommand('vscode-companion.status', () => {
    const state = editorMonitor.getCurrentState();
    const port = serverManager.getActivePort();
    const clients = serverManager.getClientCount();
    const activeFile = state.relativePath ?? 'No active file';
    vscode.window.showInformationMessage(
      `VS Code Companion: Port ${port ?? 'offline'} (${clients} connected) | File: ${activeFile} | Errors: ${state.diagnostics.errorCount}, Warnings: ${state.diagnostics.warningCount}`,
      'Show Connection & QR Code'
    ).then((selection) => {
      if (selection === 'Show Connection & QR Code') {
        showConnectionDetails(context, serverManager, authManager);
      }
    });
  });

  // Register command to display the pairing token for LAN mode
  const showPairingTokenCommand = vscode.commands.registerCommand(
    'vscode-companion.showPairingToken',
    () => {
      const token = authManager.getPairingToken();
      const port = serverManager.getActivePort() ?? 38848;
      vscode.window.showInformationMessage(
        `Companion LAN Pairing Token: ${token} (Listening on port ${port})`,
        'Show Connection & QR Code'
      ).then((selection) => {
        if (selection === 'Show Connection & QR Code') {
          showConnectionDetails(context, serverManager, authManager);
        }
      });
    }
  );

  // Register command to show connection details & QR code
  const showConnectionDetailsCommand = vscode.commands.registerCommand(
    'vscode-companion.showConnectionDetails',
    () => showConnectionDetails(context, serverManager, authManager)
  );

  // Register command to inspect current editor state (for tests and WebSocket engine)
  const getEditorStateCommand = vscode.commands.registerCommand(
    'vscode-companion.getEditorState',
    () => editorMonitor.getCurrentState()
  );

  // Register interactive safe file creation command
  const createFileCommand = registerCreateFileCommand(context);

  // Register all disposables in context.subscriptions
  context.subscriptions.push(statusBarItem);
  context.subscriptions.push(statusCommand);
  context.subscriptions.push(getEditorStateCommand);
  context.subscriptions.push(showPairingTokenCommand);
  context.subscriptions.push(showConnectionDetailsCommand);
  context.subscriptions.push(createFileCommand);
}

function updateStatusBar(state: EditorState): void {
  const port = serverManager?.getActivePort();
  const clientCount = serverManager?.getClientCount() ?? 0;
  const statusText = port ? `Port ${port} (${clientCount})` : 'Offline';
  const diagText = `$(error) ${state.diagnostics.errorCount} $(warning) ${state.diagnostics.warningCount}`;
  const langText = state.languageId ? `[${state.languageId}] ` : '';

  statusBarItem.text = `$(remote) Companion: ${statusText} | ${langText}${diagText}`;
  statusBarItem.tooltip = `VS Code Companion System\nStatus: ${statusText}\nPairing Token: ${authManager?.getPairingToken() ?? 'N/A'}\nActive File: ${state.relativePath ?? 'None'}\nErrors: ${state.diagnostics.errorCount}\nWarnings: ${state.diagnostics.warningCount}`;
}

export function deactivate(): void {
  if (statusBarItem) {
    statusBarItem.dispose();
  }
}

export {
  EditorMonitor,
  validateWorkspacePath,
  createWorkspaceFileSafely,
  registerCreateFileCommand,
  AuthManager,
  ServerManager,
  authManager,
  serverManager,
};
