import * as crypto from 'crypto';
import * as http from 'http';

export interface HandshakeValidationResult {
  success: boolean;
  reason?: string;
}

export class AuthManager {
  private _pairingToken: string;
  private _isLanMode: boolean;
  private _requireAuthOnLoopback: boolean;

  constructor(isLanMode = false, requireAuthOnLoopback = false) {
    this._isLanMode = isLanMode;
    this._requireAuthOnLoopback = requireAuthOnLoopback;
    this._pairingToken = this.generateNewToken();
  }

  /**
   * Generates a 6-character uppercase cryptographic pairing token.
   */
  public generateNewToken(): string {
    const chars = '23456789ABCDEFGHJKLMNPQRSTUVWXYZ'; // base32 avoiding ambiguous chars (0, 1, I, O)
    const bytes = crypto.randomBytes(6);
    let token = '';
    for (let i = 0; i < 6; i++) {
      token += chars[bytes[i] % chars.length];
    }
    this._pairingToken = token;
    return token;
  }

  public getPairingToken(): string {
    return this._pairingToken;
  }

  public setPairingToken(token: string): void {
    if (!token || token.trim().length === 0) {
      throw new Error('Pairing token cannot be empty');
    }
    this._pairingToken = token.trim().toUpperCase();
  }

  public getLanMode(): boolean {
    return this._isLanMode;
  }

  public setLanMode(enabled: boolean): void {
    this._isLanMode = enabled;
  }

  public setRequireAuthOnLoopback(required: boolean): void {
    this._requireAuthOnLoopback = required;
  }

  /**
   * Validates an incoming HTTP upgrade request.
   */
  public validateHandshake(
    req: http.IncomingMessage,
    isLoopbackClient: boolean
  ): HandshakeValidationResult {
    // If not in LAN mode and the client is not connecting via loopback, reject
    if (!this._isLanMode && !isLoopbackClient) {
      return {
        success: false,
        reason: 'LAN connections disabled. Enable LAN mode in extension settings.',
      };
    }

    // If loopback connection and no auth required on loopback, allow immediately
    if (isLoopbackClient && !this._requireAuthOnLoopback && !this._isLanMode) {
      return { success: true };
    }

    // Extract token from Authorization header or URL query parameter
    const providedToken = this._extractToken(req);

    if (!providedToken) {
      return {
        success: false,
        reason: 'Missing authentication token. Provide Authorization: Bearer <token> or ?token=<token>',
      };
    }

    // Verify token using constant-time comparison
    if (this._verifyToken(providedToken, this._pairingToken)) {
      return { success: true };
    }

    return {
      success: false,
      reason: 'Invalid pairing token',
    };
  }

  private _extractToken(req: http.IncomingMessage): string | null {
    // Check Authorization: Bearer <token>
    const authHeader = req.headers['authorization'];
    if (authHeader && typeof authHeader === 'string') {
      const match = authHeader.match(/^Bearer\s+([A-Za-z0-9_-]+)$/i);
      if (match) {
        return match[1].toUpperCase();
      }
    }

    // Check URL query param ?token=<token>
    if (req.url) {
      try {
        const parsedUrl = new URL(req.url, 'http://localhost');
        const tokenParam = parsedUrl.searchParams.get('token');
        if (tokenParam) {
          return tokenParam.toUpperCase();
        }
      } catch {
        // Fall through
      }
    }

    return null;
  }

  private _verifyToken(provided: string, expected: string): boolean {
    if (provided.length !== expected.length) {
      return false;
    }
    const bufA = Buffer.from(provided, 'utf8');
    const bufB = Buffer.from(expected, 'utf8');
    return crypto.timingSafeEqual(bufA, bufB);
  }
}
