import { RepositoryProviderKind } from '../repository/domain/RepositoryTypes';
import {
  DeviceCodeGrant,
  OAuthError,
  OAuthErrorKind,
  TokenGrant,
  TokenPollOutcome,
  TokenPollOutcomeKind
} from './OAuthTypes';

/**
 * Pure URL/body builders and response parsers for OAuth 2.0 Device
 * Authorization Grant (RFC 8628). Kept side-effect free so the unit tests
 * under entry/src/ohosTest/ can drive every documented response shape
 * without spinning up a real HTTP client.
 *
 * Provider quirks worth knowing:
 *  - GitHub returns JSON only when `Accept: application/json` is sent;
 *    without it the body is `application/x-www-form-urlencoded`.
 *  - Both GitHub and Gitee/GitCode accept form-encoded request bodies on
 *    their token endpoints.
 *  - Scope separator is space (' '), not comma — comma is silently ignored
 *    by GitHub.
 */

const DEFAULT_POLL_INTERVAL_SECONDS: number = 5;
const DEFAULT_EXPIRES_IN_SECONDS: number = 900;

interface FormField {
  name: string;
  value: string;
}

function encodeForm(fields: FormField[]): string {
  const parts: string[] = [];
  for (let i = 0; i < fields.length; i++) {
    const field: FormField = fields[i];
    parts.push(`${encodeURIComponent(field.name)}=${encodeURIComponent(field.value)}`);
  }
  return parts.join('&');
}

/**
 * Build the form-encoded body for the device-code request.
 *
 * Per RFC 8628 §3.1 the only required parameters are `client_id` and
 * `scope`. `scope` is space-separated.
 */
export function buildDeviceCodeRequestBody(clientId: string, scopes: string[]): string {
  const fields: FormField[] = [
    { name: 'client_id', value: clientId },
    { name: 'scope', value: scopes.join(' ') }
  ];
  return encodeForm(fields);
}

/**
 * Build the form-encoded body for the token-poll request.
 *
 * Per RFC 8628 §3.4: grant_type MUST be `urn:ietf:params:oauth:grant-type:device_code`,
 * with `device_code` and `client_id`.
 */
export function buildTokenPollRequestBody(clientId: string, deviceCode: string): string {
  const fields: FormField[] = [
    { name: 'client_id', value: clientId },
    { name: 'device_code', value: deviceCode },
    { name: 'grant_type', value: 'urn:ietf:params:oauth:grant-type:device_code' }
  ];
  return encodeForm(fields);
}

type JsonValue = Object | string | number | boolean | null | undefined;
type JsonObject = Record<string, JsonValue>;

function asJsonObject(raw: string): JsonObject | undefined {
  try {
    const parsed: Object = JSON.parse(raw) as Object;
    if (parsed === null || typeof parsed !== 'object') {
      return undefined;
    }
    return parsed as JsonObject;
  } catch (_e) {
    return undefined;
  }
}

function readString(obj: JsonObject, key: string): string | undefined {
  const v: JsonValue = obj[key];
  return typeof v === 'string' ? v as string : undefined;
}

function readNumber(obj: JsonObject, key: string): number | undefined {
  const v: JsonValue = obj[key];
  if (typeof v === 'number') {
    return v as number;
  }
  if (typeof v === 'string') {
    const n: number = Number(v as string);
    return isNaN(n) ? undefined : n;
  }
  return undefined;
}

/**
 * Parse a successful device-code response.
 *
 * Accepts both the canonical RFC 8628 field names (`device_code`,
 * `user_code`, `verification_uri`, `expires_in`, `interval`,
 * `verification_uri_complete`) and GitHub's `verification_uri` (same name).
 * Returns undefined if any required field is missing.
 */
export function parseDeviceCodeResponse(rawBody: string): DeviceCodeGrant | undefined {
  const obj: JsonObject | undefined = asJsonObject(rawBody);
  if (!obj) {
    return undefined;
  }
  const deviceCode: string | undefined = readString(obj, 'device_code');
  const userCode: string | undefined = readString(obj, 'user_code');
  const verificationUri: string | undefined = readString(obj, 'verification_uri');
  if (deviceCode === undefined || userCode === undefined || verificationUri === undefined) {
    return undefined;
  }
  const expiresIn: number | undefined = readNumber(obj, 'expires_in');
  const interval: number | undefined = readNumber(obj, 'interval');
  const grant: DeviceCodeGrant = {
    deviceCode: deviceCode,
    userCode: userCode,
    verificationUri: verificationUri,
    verificationUriComplete: readString(obj, 'verification_uri_complete'),
    expiresInSeconds: expiresIn !== undefined && expiresIn > 0 ? expiresIn : DEFAULT_EXPIRES_IN_SECONDS,
    intervalSeconds: interval !== undefined && interval > 0 ? interval : DEFAULT_POLL_INTERVAL_SECONDS
  };
  return grant;
}

/**
 * Parse a token-poll response.
 *
 * Successful body has `access_token`. RFC 8628 §3.5 transient errors
 * `authorization_pending` and `slow_down` map to non-token outcomes; the
 * remaining errors (`expired_token`, `access_denied`, anything else) are
 * terminal failures.
 */
export function parseTokenPollResponse(rawBody: string, statusCode: number): TokenPollOutcome {
  const obj: JsonObject | undefined = asJsonObject(rawBody);
  if (!obj) {
    if (statusCode >= 200 && statusCode < 300) {
      const failed: TokenPollOutcome = {
        kind: TokenPollOutcomeKind.Failed,
        error: { kind: OAuthErrorKind.Malformed, message: 'Token endpoint returned non-JSON body' } as OAuthError
      };
      return failed;
    }
    const failed: TokenPollOutcome = {
      kind: TokenPollOutcomeKind.Failed,
      error: { kind: OAuthErrorKind.Provider, message: `Token endpoint returned status ${statusCode}` } as OAuthError
    };
    return failed;
  }

  const accessToken: string | undefined = readString(obj, 'access_token');
  if (accessToken !== undefined && accessToken.length > 0) {
    const scopeRaw: string | undefined = readString(obj, 'scope');
    const scopes: string[] = scopeRaw !== undefined && scopeRaw.length > 0
      ? scopeRaw.split(/[\s,]+/).filter((s: string) => s.length > 0)
      : [];
    const token: TokenGrant = {
      accessToken: accessToken,
      tokenType: readString(obj, 'token_type') || 'bearer',
      scopes: scopes,
      refreshToken: readString(obj, 'refresh_token'),
      expiresInSeconds: readNumber(obj, 'expires_in')
    };
    const ok: TokenPollOutcome = { kind: TokenPollOutcomeKind.Token, token: token };
    return ok;
  }

  const errorCode: string | undefined = readString(obj, 'error');
  const errorDescription: string | undefined = readString(obj, 'error_description');
  if (errorCode === 'authorization_pending') {
    const pending: TokenPollOutcome = { kind: TokenPollOutcomeKind.AuthorizationPending };
    return pending;
  }
  if (errorCode === 'slow_down') {
    const slow: TokenPollOutcome = { kind: TokenPollOutcomeKind.SlowDown };
    return slow;
  }
  if (errorCode === 'access_denied') {
    const denied: TokenPollOutcome = {
      kind: TokenPollOutcomeKind.Failed,
      error: { kind: OAuthErrorKind.AccessDenied, message: errorDescription || 'User declined authorization' } as OAuthError
    };
    return denied;
  }
  if (errorCode === 'expired_token') {
    const expired: TokenPollOutcome = {
      kind: TokenPollOutcomeKind.Failed,
      error: { kind: OAuthErrorKind.ExpiredToken, message: errorDescription || 'Device code expired' } as OAuthError
    };
    return expired;
  }
  if (errorCode !== undefined) {
    const provider: TokenPollOutcome = {
      kind: TokenPollOutcomeKind.Failed,
      error: { kind: OAuthErrorKind.Provider, message: errorDescription || errorCode } as OAuthError
    };
    return provider;
  }

  const malformed: TokenPollOutcome = {
    kind: TokenPollOutcomeKind.Failed,
    error: { kind: OAuthErrorKind.Malformed, message: 'Token response had neither access_token nor error' } as OAuthError
  };
  return malformed;
}

/**
 * Apply RFC 8628 §3.5 polling back-off: when the server returns
 * `slow_down`, the client MUST increase its polling interval by 5 seconds.
 */
export function applySlowDown(currentIntervalSeconds: number): number {
  return currentIntervalSeconds + 5;
}

/**
 * Provider display name used in user-facing strings (e.g. modal headings).
 * Kept separate from RepositoryProviderMetadata to avoid pulling the full
 * provider registry into the OAuth UI.
 */
export function describeProvider(provider: RepositoryProviderKind): string {
  if (provider === RepositoryProviderKind.GitHub) {
    return 'GitHub';
  }
  if (provider === RepositoryProviderKind.GitCode) {
    return 'GitCode';
  }
  return 'Gitee';
}
