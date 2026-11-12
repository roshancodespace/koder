import * as vscode from 'vscode';

let statusBarItem: vscode.StatusBarItem;

export function activate(context: vscode.ExtensionContext): void {
  // Create a status bar item with alignment Right (priority 100)
  statusBarItem = vscode.window.createStatusBarItem(vscode.StatusBarAlignment.Right, 100);
  statusBarItem.text = '$(remote) Companion: Disconnected';
  statusBarItem.tooltip = 'VS Code Companion System - Standby';
  statusBarItem.command = 'vscode-companion.status';
  statusBarItem.show();

  // Register the status command to show an information message
  const statusCommand = vscode.commands.registerCommand('vscode-companion.status', () => {
    vscode.window.showInformationMessage('VS Code Companion: Disconnected (Standby)');
  });

  // Register all disposables in context.subscriptions
  context.subscriptions.push(statusBarItem);
  context.subscriptions.push(statusCommand);
}

export function deactivate(): void {
  if (statusBarItem) {
    statusBarItem.dispose();
  }
}
