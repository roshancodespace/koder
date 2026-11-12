import * as assert from 'assert';
import * as http from 'http';
import {
  createEventMessage,
  createRequestMessage,
  createResponseMessage,
  createErrorMessage,
  isProtocolEnvelope,
} from '../src/network/protocol';
import { AuthManager } from '../src/network/authManager';

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
});
