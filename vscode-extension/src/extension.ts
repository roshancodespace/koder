import * as vscode from 'vscode';
import { EditorMonitor, EditorState } from './editor/editorMonitor';
import { validateWorkspacePath } from './workspace/pathValidator';
import { createWorkspaceFileSafely } from './workspace/safeFileManager';

let statusBarItem: vscode.StatusBarItem;
let editorMonitor: EditorMonitor;

export function activate(context: vscode.ExtensionContext): void {
  // Initialize EditorMonitor
  editorMonitor = new EditorMonitor();
  context.subscriptions.push(editorMonitor);

  // Create a status bar item with alignment Right (priority 100)
  statusBarItem = vscode.window.createStatusBarItem(vscode.StatusBarAlignment.Right, 100);
  statusBarItem.command = 'vscode-companion.status';
  updateStatusBar(editorMonitor.getCurrentState());
  statusBarItem.show();

  // Listen to editor state changes and update status bar
  editorMonitor.onDidChangeEditorState((state) => {
    updateStatusBar(state);
  });

  // Register status command to show an information message
  const statusCommand = vscode.commands.registerCommand('vscode-companion.status', () => {
    const state = editorMonitor.getCurrentState();
    const activeFile = state.relativePath ?? 'No active file';
    vscode.window.showInformationMessage(
      `VS Code Companion: Disconnected | File: ${activeFile} | Errors: ${state.diagnostics.errorCount}, Warnings: ${state.diagnostics.warningCount}`
    );
  });

  // Register command to inspect current editor state (for tests and WebSocket engine)
  const getEditorStateCommand = vscode.commands.registerCommand(
    'vscode-companion.getEditorState',
    () => editorMonitor.getCurrentState()
  );

  // Register all disposables in context.subscriptions
  context.subscriptions.push(statusBarItem);
  context.subscriptions.push(statusCommand);
  context.subscriptions.push(getEditorStateCommand);
}

function updateStatusBar(state: EditorState): void {
  const diagText = `$(error) ${state.diagnostics.errorCount} $(warning) ${state.diagnostics.warningCount}`;
  const langText = state.languageId ? `[${state.languageId}] ` : '';
  statusBarItem.text = `$(remote) Companion: Disconnected | ${langText}${diagText}`;
  statusBarItem.tooltip = `VS Code Companion System - Standby\nActive File: ${state.relativePath ?? 'None'}\nErrors: ${state.diagnostics.errorCount}\nWarnings: ${state.diagnostics.warningCount}`;
}

export function deactivate(): void {
  if (statusBarItem) {
    statusBarItem.dispose();
  }
}

export { EditorMonitor, validateWorkspacePath, createWorkspaceFileSafely };
