import * as vscode from 'vscode';
import * as QRCode from 'qrcode';
import { ServerManager } from '../network/serverManager';
import { AuthManager } from '../network/authManager';

let currentPanel: vscode.WebviewPanel | undefined;

export async function showConnectionDetails(
  context: vscode.ExtensionContext,
  serverManager: ServerManager,
  authManager: AuthManager
): Promise<void> {
  const port = serverManager.getActivePort() ?? 38848;
  const token = authManager.getPairingToken();
  const ips = serverManager.getLocalIpAddresses();
  const primaryIp = ips[0] ?? '127.0.0.1';
  const connectionUrl = `ws://${primaryIp}:${port}?token=${token}`;
  const clients = serverManager.getClientCount();

  let qrSvg = '';
  try {
    qrSvg = await QRCode.toString(connectionUrl, {
      type: 'svg',
      margin: 2,
      color: {
        dark: '#0f172a',
        light: '#ffffff',
      },
    });
  } catch {
    qrSvg = '<p style="color:red;">Failed to render QR Code</p>';
  }

  if (currentPanel) {
    currentPanel.reveal(vscode.ViewColumn.Active);
  } else {
    currentPanel = vscode.window.createWebviewPanel(
      'companionConnection',
      'VS Code Companion: Connection & QR Code',
      vscode.ViewColumn.Active,
      {
        enableScripts: true,
        retainContextWhenHidden: true,
      }
    );

    currentPanel.onDidDispose(() => {
      currentPanel = undefined;
    }, null, context.subscriptions);
  }

  currentPanel.webview.html = getWebviewContent(ips, port, token, connectionUrl, clients, qrSvg);
}

function getWebviewContent(
  ips: string[],
  port: number,
  token: string,
  connectionUrl: string,
  clients: number,
  qrSvg: string
): string {
  const ipListHtml = ips.map((ip) => `<code>${ip}</code>`).join(' or ');

  return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Companion Connection</title>
  <style>
    body {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif;
      padding: 24px;
      line-height: 1.6;
      color: var(--vscode-foreground);
      background-color: var(--vscode-editor-background);
      max-width: 650px;
      margin: 0 auto;
    }
    h2 {
      margin-top: 0;
      color: var(--vscode-titleBar-activeForeground, #38bdf8);
      display: flex;
      align-items: center;
      gap: 8px;
    }
    .badge {
      display: inline-block;
      padding: 3px 8px;
      font-size: 12px;
      font-weight: 600;
      border-radius: 12px;
      background: var(--vscode-badge-background, #0284c7);
      color: var(--vscode-badge-foreground, #fff);
    }
    .qr-container {
      background: #ffffff;
      padding: 16px;
      border-radius: 12px;
      display: inline-block;
      margin: 16px 0;
      box-shadow: 0 4px 12px rgba(0, 0, 0, 0.15);
    }
    .qr-container svg {
      width: 200px;
      height: 200px;
      display: block;
    }
    .card {
      background: var(--vscode-editorWidget-background, #1e293b);
      border: 1px solid var(--vscode-editorWidget-border, #334155);
      border-radius: 8px;
      padding: 16px;
      margin-bottom: 16px;
    }
    .row {
      display: flex;
      justify-content: space-between;
      align-items: center;
      padding: 6px 0;
      border-bottom: 1px solid var(--vscode-widget-border, #334155);
    }
    .row:last-child {
      border-bottom: none;
    }
    .label {
      font-weight: 600;
      color: var(--vscode-descriptionForeground, #94a3b8);
    }
    code {
      font-family: var(--vscode-editor-font-family, monospace);
      background: var(--vscode-textCodeBlock-background, #0f172a);
      padding: 2px 6px;
      border-radius: 4px;
      font-size: 13px;
    }
    button {
      background: var(--vscode-button-background, #2563eb);
      color: var(--vscode-button-foreground, #ffffff);
      border: none;
      padding: 8px 14px;
      border-radius: 6px;
      cursor: pointer;
      font-weight: 500;
      margin-top: 8px;
    }
    button:hover {
      background: var(--vscode-button-hoverBackground, #1d4ed8);
    }
    .instructions {
      font-size: 13px;
      color: var(--vscode-descriptionForeground, #94a3b8);
    }
  </style>
</head>
<body>
  <h2>📱 VS Code Companion System <span class="badge">${clients} Connected</span></h2>
  <p>Connect your Android device to synchronise editor state and send low-latency commands.</p>

  <div style="text-align: center;">
    <div class="qr-container">
      ${qrSvg}
    </div>
    <div class="instructions">Scan this QR Code in the companion app to connect instantly</div>
  </div>

  <div class="card">
    <div class="row">
      <span class="label">Workstation IP</span>
      <span>${ipListHtml}</span>
    </div>
    <div class="row">
      <span class="label">Port</span>
      <code>${port}</code>
    </div>
    <div class="row">
      <span class="label">Pairing Token</span>
      <code>${token}</code>
    </div>
    <div class="row">
      <span class="label">WebSocket URL</span>
      <code>${connectionUrl}</code>
    </div>
  </div>

  <div class="card">
    <h3>🔌 USB Loopback Alternative (Zero Wi-Fi Required)</h3>
    <p class="instructions">If Wi-Fi is unavailable or restricted, connect your phone with a USB cable and run:</p>
    <code>adb reverse tcp:${port} tcp:${port}</code>
    <p class="instructions">Then tap <strong>Connect USB Loopback</strong> in the companion app.</p>
  </div>
</body>
</html>`;
}
