import { RepositoryProviderKind } from '../repository/domain/RepositoryTypes';

/**
 * High-level state of an OAuth 2.0 Device Authorization Grant session.
 *
 * The flow is a strict forward progression unless the user cancels or an
 * error occurs:
 *
 *   Idle
 *     -> RequestingDeviceCode
 *       -> AwaitingUserAuthorization  (polls the token endpoint)
 *         -> ExchangingToken
 *           -> Authenticated   (terminal, success)
 *
 * From any non-terminal state the session may transition to:
 *   -> Cancelled   (user pressed Cancel)
 *   -> Failed      (transport error, expired_token, access_denied, etc.)
 *
 * Both Cancelled and Failed are terminal — callers must start a new
 * session to retry.
 */
export enum OAuthSessionState {
  Idle = 'idle',
  RequestingDeviceCode = 'requestingDeviceCode',
  AwaitingUserAuthorization = 'awaitingUserAuthorization',
  ExchangingToken = 'exchangingToken',
  Authenticated = 'authenticated',
  Cancelled = 'cancelled',
  Failed = 'failed'
}

/**
 * Failure categories surfaced to the UI. They are stable, machine-readable
 * codes — UI strings are produced by the layer above.
 */
export enum OAuthErrorKind {
  /** The provider has no client_id configured (Settings -> Connector). */
  MissingClientId = 'missingClientId',
  /** Network / transport failure when contacting the provider. */
  Network = 'network',
  /** Provider returned a non-2xx response with no parseable error body. */
  Provider = 'provider',
  /** OAuth `access_denied` — the user rejected the authorization. */
  AccessDenied = 'accessDenied',
  /** OAuth `expired_token` — user took too long to enter the code. */
  ExpiredToken = 'expiredToken',
  /** Provider response could not be parsed / required fields missing. */
  Malformed = 'malformed',
  /** State machine was driven into an illegal transition. */
  IllegalTransition = 'illegalTransition'
}

export interface OAuthError {
  kind: OAuthErrorKind;
  message: string;
}

/**
 * Successful response to the device-code request. Field names match
 * RFC 8628 §3.2.
 */
export interface DeviceCodeGrant {
  deviceCode: string;
  userCode: string;
  verificationUri: string;
  /** Pre-filled verification URL with code embedded (optional per RFC). */
  verificationUriComplete?: string;
  /** Seconds until deviceCode expires. */
  expiresInSeconds: number;
  /** Minimum polling interval in seconds. Defaults to 5 if absent. */
  intervalSeconds: number;
}

export enum TokenPollOutcomeKind {
  Token = 'token',
  AuthorizationPending = 'authorizationPending',
  SlowDown = 'slowDown',
  Failed = 'failed'
}

export interface TokenGrant {
  accessToken: string;
  tokenType: string;
  scopes: string[];
  refreshToken?: string;
  expiresInSeconds?: number;
}

export interface TokenPollOutcome {
  kind: TokenPollOutcomeKind;
  token?: TokenGrant;
  error?: OAuthError;
}

/**
 * Snapshot of an in-flight or terminal OAuth session. Emitted on every
 * state transition.
 */
export interface OAuthSessionSnapshot {
  provider: RepositoryProviderKind;
  state: OAuthSessionState;
  grant?: DeviceCodeGrant;
  token?: TokenGrant;
  error?: OAuthError;
  /** Current effective polling interval (seconds); slow_down increases this. */
  pollIntervalSeconds: number;
  /** Wall-clock millis when this snapshot was produced. */
  updatedAtMs: number;
}

export type OAuthSessionListener = (snapshot: OAuthSessionSnapshot) => void;
