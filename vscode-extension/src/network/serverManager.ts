import * as http from 'http';
import * as vscode from 'vscode';
import { WebSocketServer, WebSocket } from 'ws';
import { AuthManager } from './authManager';
import {
  ProtocolEnvelope,
  createEventMessage,
  createResponseMessage,
  createErrorMessage,
  isProtocolEnvelope,
} from './protocol';

interface AuthenticatedSocket extends WebSocket {
  isAlive: boolean;
  isAuthenticated: boolean;
}

export interface ServerManagerConfig {
  host?: string;
  port?: number;
  maxPort?: number;
  heartbeatIntervalMs?: number;
}

export class ServerManager implements vscode.Disposable {
  private readonly _authManager: AuthManager;
  private readonly _config: Required<ServerManagerConfig>;
  private _server: http.Server | null = null;
  private _wss: WebSocketServer | null = null;
  private _activePort: number | null = null;
  private readonly _clients = new Set<AuthenticatedSocket>();
  private _heartbeatTimer: NodeJS.Timeout | null = null;

  private readonly _onDidChangeClientCount = new vscode.EventEmitter<number>();
  public readonly onDidChangeClientCount: vscode.Event<number> =
    this._onDidChangeClientCount.event;

  private readonly _onDidReceiveMessage = new vscode.EventEmitter<ProtocolEnvelope>();
  public readonly onDidReceiveMessage: vscode.Event<ProtocolEnvelope> =
    this._onDidReceiveMessage.event;

  // Custom request handlers registered by other components (e.g. editor, workspace)
  private readonly _requestHandlers = new Map<
    string,
    (payload: Record<string, unknown>) => Promise<Record<string, unknown>>
  >();

  constructor(authManager: AuthManager, config: ServerManagerConfig = {}) {
    this._authManager = authManager;
    this._config = {
      host: config.host ?? '127.0.0.1',
      port: config.port ?? 38848,
      maxPort: config.maxPort ?? 38855,
      heartbeatIntervalMs: config.heartbeatIntervalMs ?? 30000,
    };
  }

  public getActivePort(): number | null {
    return this._activePort;
  }

  public getClientCount(): number {
    return this._clients.size;
  }

  public getPairingToken(): string {
    return this._authManager.getPairingToken();
  }

  public registerRequestHandler(
    name: string,
    handler: (payload: Record<string, unknown>) => Promise<Record<string, unknown>>
  ): vscode.Disposable {
    this._requestHandlers.set(name, handler);
    return new vscode.Disposable(() => {
      this._requestHandlers.delete(name);
    });
  }

  /**
   * Starts the HTTP and WebSocket server, retrying ports on EADDRINUSE up to maxPort.
   */
  public async start(): Promise<number> {
    if (this._server) {
      return this._activePort!;
    }

    let currentPort = this._config.port;

    while (currentPort <= this._config.maxPort) {
      try {
        await this._listenOnPort(currentPort, this._config.host);
        this._activePort = currentPort;
        this._startHeartbeat();
        return currentPort;
      } catch (err: unknown) {
        const error = err as NodeJS.ErrnoException;
        if (error.code === 'EADDRINUSE' && currentPort < this._config.maxPort) {
          currentPort++;
        } else {
          throw new Error(
            `Failed to start WebSocket server on ${this._config.host} (ports ${this._config.port}-${this._config.maxPort}): ${error.message}`
          );
        }
      }
    }

    throw new Error(
      `All ports between ${this._config.port} and ${this._config.maxPort} are in use.`
    );
  }

  private _listenOnPort(port: number, host: string): Promise<void> {
    return new Promise((resolve, reject) => {
      const server = http.createServer((_req, res) => {
        res.writeHead(200, { 'Content-Type': 'text/plain' });
        res.end('VS Code Companion System WebSocket Endpoint\n');
      });

      const wss = new WebSocketServer({ noServer: true });

      server.on('upgrade', (req, socket, head) => {
        const remoteIp = req.socket.remoteAddress ?? '';
        const isLoopback =
          remoteIp === '127.0.0.1' ||
          remoteIp === '::1' ||
          remoteIp === '::ffff:127.0.0.1';

        const validation = this._authManager.validateHandshake(req, isLoopback);

        if (!validation.success) {
          socket.write('HTTP/1.1 401 Unauthorized\r\n\r\n');
          socket.destroy();
          return;
        }

        wss.handleUpgrade(req, socket, head, (ws) => {
          wss.emit('connection', ws, req);
        });
      });

      wss.on('connection', (ws: WebSocket) => {
        const client = ws as AuthenticatedSocket;
        client.isAlive = true;
        client.isAuthenticated = true;
        this._clients.add(client);
        this._onDidChangeClientCount.fire(this._clients.size);

        client.on('pong', () => {
          client.isAlive = true;
        });

        client.on('message', async (data: Buffer | string) => {
          await this._handleClientMessage(client, data);
        });

        client.on('close', () => {
          this._clients.delete(client);
          this._onDidChangeClientCount.fire(this._clients.size);
        });

        client.on('error', () => {
          this._clients.delete(client);
          this._onDidChangeClientCount.fire(this._clients.size);
        });
      });

      server.once('error', (err) => {
        reject(err);
      });

      server.listen(port, host, () => {
        this._server = server;
        this._wss = wss;
        resolve();
      });
    });
  }

  private async _handleClientMessage(
    client: AuthenticatedSocket,
    rawData: Buffer | string
  ): Promise<void> {
    let text: string;
    if (typeof rawData === 'string') {
      text = rawData;
    } else {
      text = rawData.toString('utf8');
    }

    let parsed: unknown;
    try {
      parsed = JSON.parse(text);
    } catch {
      return;
    }

    if (!isProtocolEnvelope(parsed)) {
      return;
    }

    const envelope = parsed;
    this._onDidReceiveMessage.fire(envelope);

    if (envelope.type === 'request') {
      // Built-in system ping handler
      if (envelope.name === 'system.ping') {
        const response = createResponseMessage(envelope.id, 'system.pong', {
          timestamp: Date.now(),
        });
        this._sendToClient(client, response);
        return;
      }

      // Dispatch to registered request handlers
      const handler = this._requestHandlers.get(envelope.name);
      if (handler) {
        try {
          const result = await handler(envelope.payload);
          const response = createResponseMessage(envelope.id, envelope.name, result);
          this._sendToClient(client, response);
        } catch (err: unknown) {
          const message = err instanceof Error ? err.message : String(err);
          const errorResponse = createErrorMessage(
            envelope.id,
            envelope.name,
            'HANDLER_ERROR',
            message
          );
          this._sendToClient(client, errorResponse);
        }
      } else {
        const notFoundResponse = createErrorMessage(
          envelope.id,
          envelope.name,
          'METHOD_NOT_FOUND',
          `No handler registered for request '${envelope.name}'`
        );
        this._sendToClient(client, notFoundResponse);
      }
    }
  }

  private _sendToClient(client: AuthenticatedSocket, envelope: ProtocolEnvelope): void {
    if (client.readyState === WebSocket.OPEN) {
      client.send(JSON.stringify(envelope));
    }
  }

  /**
   * Broadcasts an event to all open authenticated clients.
   */
  public broadcastEvent(name: string, payload: Record<string, unknown> = {}): void {
    const envelope = createEventMessage(name, payload);
    const serialized = JSON.stringify(envelope);

    for (const client of this._clients) {
      if (client.readyState === WebSocket.OPEN) {
        client.send(serialized);
      }
    }
  }

  private _startHeartbeat(): void {
    this._heartbeatTimer = setInterval(() => {
      for (const client of this._clients) {
        if (!client.isAlive) {
          client.terminate();
          this._clients.delete(client);
          this._onDidChangeClientCount.fire(this._clients.size);
          continue;
        }
        client.isAlive = false;
        client.ping();
      }
    }, this._config.heartbeatIntervalMs);
  }

  public async stop(): Promise<void> {
    if (this._heartbeatTimer) {
      clearInterval(this._heartbeatTimer);
      this._heartbeatTimer = null;
    }

    for (const client of this._clients) {
      try {
        client.close(1000, 'Server stopping');
      } catch {
        // Fall through
      }
    }
    this._clients.clear();
    this._onDidChangeClientCount.fire(0);

    if (this._wss) {
      await new Promise<void>((resolve) => {
        this._wss!.close(() => resolve());
      });
      this._wss = null;
    }

    if (this._server) {
      await new Promise<void>((resolve) => {
        this._server!.close(() => resolve());
      });
      this._server = null;
    }

    this._activePort = null;
  }

  public dispose(): void {
    void this.stop();
    this._onDidChangeClientCount.dispose();
    this._onDidReceiveMessage.dispose();
  }
}
