export interface ProtocolError {
  code: string;
  message: string;
  details?: unknown;
}

export type ProtocolMessageType = 'event' | 'request' | 'response';

export interface ProtocolEnvelope {
  version: '1.0';
  id: string;
  type: ProtocolMessageType;
  name: string;
  payload: Record<string, unknown>;
  timestamp: number;
  error?: ProtocolError;
}

let messageCounter = 0;

/**
 * Generates a unique monotonic message ID.
 */
export function generateMessageId(prefix = 'msg'): string {
  messageCounter = (messageCounter + 1) % 1000000;
  return `${prefix}-${Date.now()}-${String(messageCounter).padStart(4, '0')}`;
}

/**
 * Creates an event envelope (one-way broadcast).
 */
export function createEventMessage(
  name: string,
  payload: Record<string, unknown> = {}
): ProtocolEnvelope {
  return {
    version: '1.0',
    id: generateMessageId('evt'),
    type: 'event',
    name,
    payload,
    timestamp: Date.now(),
  };
}

/**
 * Creates a request envelope expecting a response.
 */
export function createRequestMessage(
  name: string,
  payload: Record<string, unknown> = {},
  customId?: string
): ProtocolEnvelope {
  return {
    version: '1.0',
    id: customId ?? generateMessageId('req'),
    type: 'request',
    name,
    payload,
    timestamp: Date.now(),
  };
}

/**
 * Creates a successful response envelope for a correlated request.
 */
export function createResponseMessage(
  requestId: string,
  name: string,
  payload: Record<string, unknown> = {}
): ProtocolEnvelope {
  return {
    version: '1.0',
    id: requestId,
    type: 'response',
    name,
    payload,
    timestamp: Date.now(),
  };
}

/**
 * Creates an error response envelope for a correlated request.
 */
export function createErrorMessage(
  requestId: string,
  name: string,
  code: string,
  message: string,
  details?: unknown
): ProtocolEnvelope {
  return {
    version: '1.0',
    id: requestId,
    type: 'response',
    name,
    payload: {},
    timestamp: Date.now(),
    error: {
      code,
      message,
      details,
    },
  };
}

/**
 * Type guard for ProtocolEnvelope.
 */
export function isProtocolEnvelope(data: unknown): data is ProtocolEnvelope {
  if (typeof data !== 'object' || data === null) {
    return false;
  }
  const obj = data as Record<string, unknown>;
  return (
    obj.version === '1.0' &&
    typeof obj.id === 'string' &&
    (obj.type === 'event' || obj.type === 'request' || obj.type === 'response') &&
    typeof obj.name === 'string' &&
    typeof obj.payload === 'object' &&
    obj.payload !== null &&
    typeof obj.timestamp === 'number'
  );
}
