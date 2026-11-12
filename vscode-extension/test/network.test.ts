import * as assert from 'assert';
import * as http from 'http';
import { WebSocket } from 'ws';
import {
  createEventMessage,
  createRequestMessage,
  createResponseMessage,
  createErrorMessage,
  isProtocolEnvelope,
  ProtocolEnvelope,
} from '../src/network/protocol';
import { AuthManager } from '../src/network/authManager';
import { ServerManager } from '../src/network/serverManager';

suite('Protocol & Authentication Engine Test Suite', () => {
  test('createEventMessage creates valid event envelope', () => {
    const event = createEventMessage('editor.stateChanged', { activeFile: 'src/main.ts' });
    assert.strictEqual(event.version, '1.0');
    assert.strictEqual(event.type, 'event');
    assert.strictEqual(event.name, 'editor.stateChanged');
    assert.strictEqual(event.payload.activeFile, 'src/main.ts');
    assert.ok(event.id.startsWith('evt-'));
    assert.ok(event.timestamp > 0);
    assert.ok(isProtocolEnvelope(event));
  });

  test('createRequestMessage creates valid request envelope', () => {
    const req = createRequestMessage('workspace.createFile', { path: 'src/test.ts' });
    assert.strictEqual(req.version, '1.0');
    assert.strictEqual(req.type, 'request');
    assert.strictEqual(req.name, 'workspace.createFile');
    assert.ok(req.id.startsWith('req-'));
    assert.ok(isProtocolEnvelope(req));
  });

  test('createResponseMessage and createErrorMessage create correlated responses', () => {
    const res = createResponseMessage('req-123', 'workspace.createFile', { uri: 'file:///path' });
    assert.strictEqual(res.id, 'req-123');
    assert.strictEqual(res.type, 'response');
    assert.strictEqual(res.name, 'workspace.createFile');
    assert.strictEqual(res.payload.uri, 'file:///path');
    assert.strictEqual(res.error, undefined);

    const err = createErrorMessage('req-123', 'workspace.createFile', 'FILE_EXISTS', 'Collision');
    assert.strictEqual(err.id, 'req-123');
    assert.strictEqual(err.type, 'response');
    assert.ok(err.error);
    assert.strictEqual(err.error?.code, 'FILE_EXISTS');
    assert.strictEqual(err.error?.message, 'Collision');
  });

  test('isProtocolEnvelope rejects invalid payloads', () => {
    assert.strictEqual(isProtocolEnvelope(null), false);
    assert.strictEqual(isProtocolEnvelope({}), false);
    assert.strictEqual(isProtocolEnvelope({ version: '2.0', id: '1', type: 'event', name: 'n', payload: {}, timestamp: 123 }), false);
    assert.strictEqual(isProtocolEnvelope({ version: '1.0', id: '1', type: 'invalid', name: 'n', payload: {}, timestamp: 123 }), false);
  });

  test('AuthManager generates 6-char token and validates handshake', () => {
    const auth = new AuthManager(false, false);
    const token = auth.getPairingToken();
    assert.strictEqual(token.length, 6);

    // Loopback without LAN mode should succeed automatically
    const dummyReqLoopback = {
      headers: {},
      url: '/',
    } as unknown as http.IncomingMessage;

    const resLoopback = auth.validateHandshake(dummyReqLoopback, true);
    assert.strictEqual(resLoopback.success, true);

    // Non-loopback client in loopback-only mode should fail
    const resNonLoopback = auth.validateHandshake(dummyReqLoopback, false);
    assert.strictEqual(resNonLoopback.success, false);
    assert.ok(resNonLoopback.reason?.includes('LAN connections disabled'));

    // Enable LAN mode
    auth.setLanMode(true);

    // Missing token should fail
    const resMissing = auth.validateHandshake(dummyReqLoopback, false);
    assert.strictEqual(resMissing.success, false);

    // Valid header token should succeed
    const validReqHeader = {
      headers: { authorization: `Bearer ${token}` },
      url: '/',
    } as unknown as http.IncomingMessage;
    const resHeader = auth.validateHandshake(validReqHeader, false);
    assert.strictEqual(resHeader.success, true);

    // Valid query token should succeed
    const validReqQuery = {
      headers: {},
      url: `/?token=${token}`,
    } as unknown as http.IncomingMessage;
    const resQuery = auth.validateHandshake(validReqQuery, false);
    assert.strictEqual(resQuery.success, true);

    // Invalid token should fail
    const invalidReq = {
      headers: { authorization: 'Bearer WRONG1' },
      url: '/',
    } as unknown as http.IncomingMessage;
    const resInvalid = auth.validateHandshake(invalidReq, false);
    assert.strictEqual(resInvalid.success, false);
  });

  test('ServerManager binds port, accepts connection, handles ping and broadcast', async () => {
    const auth = new AuthManager(false, false);
    // Use high test port to avoid conflict
    const server = new ServerManager(auth, { port: 39100, maxPort: 39110, heartbeatIntervalMs: 5000 });
    const boundPort = await server.start();
    assert.ok(boundPort >= 39100 && boundPort <= 39110);
    assert.strictEqual(server.getActivePort(), boundPort);

    // Connect WebSocket client
    const client = new WebSocket(`ws://127.0.0.1:${boundPort}`);
    await new Promise<void>((resolve, reject) => {
      client.on('open', resolve);
      client.on('error', reject);
    });

    // Wait a tick for connection count to register
    await new Promise((r) => setTimeout(r, 50));
    assert.strictEqual(server.getClientCount(), 1);

    // Test ping-pong request/response
    const pingMessage = createRequestMessage('system.ping', {});
    client.send(JSON.stringify(pingMessage));

    const responsePromise = new Promise<ProtocolEnvelope>((resolve) => {
      client.on('message', (data) => {
        const envelope = JSON.parse(data.toString()) as ProtocolEnvelope;
        if (envelope.type === 'response' && envelope.id === pingMessage.id) {
          resolve(envelope);
        }
      });
    });

    const response = await responsePromise;
    assert.strictEqual(response.name, 'system.pong');
    assert.ok(typeof response.payload.timestamp === 'number');

    // Test server broadcast
    const broadcastPromise = new Promise<ProtocolEnvelope>((resolve) => {
      client.on('message', (data) => {
        const envelope = JSON.parse(data.toString()) as ProtocolEnvelope;
        if (envelope.type === 'event' && envelope.name === 'editor.testEvent') {
          resolve(envelope);
        }
      });
    });

    server.broadcastEvent('editor.testEvent', { status: 'ok' });
    const broadcastReceived = await broadcastPromise;
    assert.strictEqual(broadcastReceived.name, 'editor.testEvent');
    assert.strictEqual(broadcastReceived.payload.status, 'ok');

    // Clean shutdown
    client.close();
    await server.stop();
    assert.strictEqual(server.getActivePort(), null);
    assert.strictEqual(server.getClientCount(), 0);
  });
});
