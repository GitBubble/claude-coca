import { RepositoryProviderKind } from '../repository/domain/RepositoryTypes';
import {
  buildOAuthProviderConfig,
  OAuthClientIds,
  OAuthProviderConfig
} from './OAuthConfig';
import {
  applySlowDown,
  buildDeviceCodeRequestBody,
  buildTokenPollRequestBody,
  parseDeviceCodeResponse,
  parseTokenPollResponse
} from './OAuthParsing';
import {
  DeviceCodeGrant,
  OAuthError,
  OAuthErrorKind,
  OAuthSessionListener,
  OAuthSessionSnapshot,
  OAuthSessionState,
  TokenGrant,
  TokenPollOutcome,
  TokenPollOutcomeKind
} from './OAuthTypes';
import { NetworkKitOAuthHttpClient, OAuthHttpClient, OAuthHttpResponse } from './OAuthHttpAdapter';

/**
 * Injectable clock + sleep, so unit tests can drive polling
 * deterministically without real timers.
 */
export interface OAuthClock {
  nowMs(): number;
  sleep(durationMs: number): Promise<void>;
}

class SystemClock implements OAuthClock {
  public nowMs(): number {
    return Date.now();
  }

  public sleep(durationMs: number): Promise<void> {
    return new Promise<void>((resolve: () => void) => {
      setTimeout(resolve, durationMs);
    });
  }
}

export interface OAuthServiceDeps {
  http?: OAuthHttpClient;
  clock?: OAuthClock;
}

/** Internal helper return type for the device-code request step. */
interface DeviceCodeRequestResult {
  grant?: DeviceCodeGrant;
  error?: OAuthError;
}

/**
 * Drives one OAuth 2.0 Device Authorization Grant session at a time.
 *
 * Lifecycle:
 *   start(provider, clientIds)  -> emits snapshots through onChange
 *   cancel()                    -> only effective until terminal state
 *
 * Concurrency: starting a new session while another is in flight first
 * cancels the previous one. cancel() is idempotent.
 *
 * The state machine is intentionally explicit (no implicit transitions)
 * so it can be inspected in tests. The whitelist of legal transitions
 * lives in `assertTransition`.
 */
export class OAuthService {
  private readonly http: OAuthHttpClient;
  private readonly clock: OAuthClock;

  private listeners: OAuthSessionListener[] = [];
  private snapshot: OAuthSessionSnapshot | undefined = undefined;
  private cancelRequested: boolean = false;
  private runId: number = 0;

  constructor(deps?: OAuthServiceDeps) {
    this.http = deps && deps.http ? deps.http : new NetworkKitOAuthHttpClient();
    this.clock = deps && deps.clock ? deps.clock : new SystemClock();
  }

  public subscribe(listener: OAuthSessionListener): () => void {
    this.listeners.push(listener);
    if (this.snapshot) {
      listener(this.snapshot);
    }
    return (): void => {
      this.listeners = this.listeners.filter((l: OAuthSessionListener) => l !== listener);
    };
  }

  public getSnapshot(): OAuthSessionSnapshot | undefined {
    return this.snapshot;
  }

  /**
   * Begin a new device-flow session. Cancels any in-flight session first.
   * Returns a promise that resolves when the session reaches a terminal
   * state (Authenticated, Cancelled, or Failed).
   */
  public async start(
    provider: RepositoryProviderKind,
    clientIds: OAuthClientIds
  ): Promise<OAuthSessionSnapshot> {
    this.cancel();
    this.cancelRequested = false;
    this.runId += 1;
    const myRunId: number = this.runId;
    // Reset any prior terminal snapshot so the state-machine guard doesn't
    // reject the fresh session.
    this.snapshot = undefined;

    const config: OAuthProviderConfig = buildOAuthProviderConfig(provider, clientIds);
    if (config.clientId.length === 0) {
      const failed: OAuthSessionSnapshot = this.transitionTo({
        provider: provider,
        state: OAuthSessionState.Failed,
        error: {
          kind: OAuthErrorKind.MissingClientId,
          message: 'No OAuth client_id configured for this provider. Add it under Settings → Connector.'
        } as OAuthError,
        pollIntervalSeconds: 0,
        updatedAtMs: this.clock.nowMs()
      });
      return failed;
    }

    this.transitionTo({
      provider: provider,
      state: OAuthSessionState.RequestingDeviceCode,
      pollIntervalSeconds: 0,
      updatedAtMs: this.clock.nowMs()
    });

    const result: DeviceCodeRequestResult = await this.requestDeviceCode(config);
    if (this.cancelRequested || myRunId !== this.runId) {
      return this.finalizeCancellation(provider);
    }
    if (result.error) {
      return this.transitionTo({
        provider: provider,
        state: OAuthSessionState.Failed,
        error: result.error,
        pollIntervalSeconds: 0,
        updatedAtMs: this.clock.nowMs()
      });
    }

    const validGrant: DeviceCodeGrant = result.grant as DeviceCodeGrant;
    this.transitionTo({
      provider: provider,
      state: OAuthSessionState.AwaitingUserAuthorization,
      grant: validGrant,
      pollIntervalSeconds: validGrant.intervalSeconds,
      updatedAtMs: this.clock.nowMs()
    });

    return this.pollUntilTerminal(config, validGrant, myRunId);
  }

  /**
   * Request cancellation of the current session. The state machine moves
   * to Cancelled at the next safe point (between HTTP requests / sleeps).
   */
  public cancel(): void {
    if (!this.snapshot) {
      return;
    }
    if (this.isTerminal(this.snapshot.state)) {
      return;
    }
    this.cancelRequested = true;
  }

  // --- internals -----------------------------------------------------

  private async requestDeviceCode(config: OAuthProviderConfig): Promise<DeviceCodeRequestResult> {
    const body: string = buildDeviceCodeRequestBody(config.clientId, config.scopes);
    let response: OAuthHttpResponse;
    try {
      response = await this.http.postForm(config.deviceCodeUrl, body);
    } catch (e) {
      const err: Error = e as Error;
      const failed: DeviceCodeRequestResult = {
        error: { kind: OAuthErrorKind.Network, message: err.message || 'Network failure' }
      };
      return failed;
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      const failed: DeviceCodeRequestResult = {
        error: {
          kind: OAuthErrorKind.Provider,
          message: `Device code endpoint returned status ${response.statusCode}`
        }
      };
      return failed;
    }
    const parsed: DeviceCodeGrant | undefined = parseDeviceCodeResponse(response.body);
    if (!parsed) {
      const failed: DeviceCodeRequestResult = {
        error: {
          kind: OAuthErrorKind.Malformed,
          message: 'Device code response was missing required fields'
        }
      };
      return failed;
    }
    const ok: DeviceCodeRequestResult = { grant: parsed };
    return ok;
  }

  private async pollUntilTerminal(
    config: OAuthProviderConfig,
    grant: DeviceCodeGrant,
    myRunId: number
  ): Promise<OAuthSessionSnapshot> {
    let intervalSeconds: number = grant.intervalSeconds;
    const deadlineMs: number = this.clock.nowMs() + grant.expiresInSeconds * 1000;

    while (true) {
      if (this.cancelRequested || myRunId !== this.runId) {
        return this.finalizeCancellation(config.provider);
      }

      await this.clock.sleep(intervalSeconds * 1000);

      if (this.cancelRequested || myRunId !== this.runId) {
        return this.finalizeCancellation(config.provider);
      }

      if (this.clock.nowMs() >= deadlineMs) {
        return this.transitionTo({
          provider: config.provider,
          state: OAuthSessionState.Failed,
          grant: grant,
          error: { kind: OAuthErrorKind.ExpiredToken, message: 'Device code expired before authorization' } as OAuthError,
          pollIntervalSeconds: intervalSeconds,
          updatedAtMs: this.clock.nowMs()
        });
      }

      this.transitionTo({
        provider: config.provider,
        state: OAuthSessionState.ExchangingToken,
        grant: grant,
        pollIntervalSeconds: intervalSeconds,
        updatedAtMs: this.clock.nowMs()
      });

      const outcome: TokenPollOutcome = await this.pollTokenOnce(config, grant);

      if (this.cancelRequested || myRunId !== this.runId) {
        return this.finalizeCancellation(config.provider);
      }

      if (outcome.kind === TokenPollOutcomeKind.Token) {
        const token: TokenGrant = outcome.token as TokenGrant;
        return this.transitionTo({
          provider: config.provider,
          state: OAuthSessionState.Authenticated,
          grant: grant,
          token: token,
          pollIntervalSeconds: intervalSeconds,
          updatedAtMs: this.clock.nowMs()
        });
      }
      if (outcome.kind === TokenPollOutcomeKind.AuthorizationPending) {
        this.transitionTo({
          provider: config.provider,
          state: OAuthSessionState.AwaitingUserAuthorization,
          grant: grant,
          pollIntervalSeconds: intervalSeconds,
          updatedAtMs: this.clock.nowMs()
        });
        continue;
      }
      if (outcome.kind === TokenPollOutcomeKind.SlowDown) {
        intervalSeconds = applySlowDown(intervalSeconds);
        this.transitionTo({
          provider: config.provider,
          state: OAuthSessionState.AwaitingUserAuthorization,
          grant: grant,
          pollIntervalSeconds: intervalSeconds,
          updatedAtMs: this.clock.nowMs()
        });
        continue;
      }
      // Failed
      return this.transitionTo({
        provider: config.provider,
        state: OAuthSessionState.Failed,
        grant: grant,
        error: outcome.error,
        pollIntervalSeconds: intervalSeconds,
        updatedAtMs: this.clock.nowMs()
      });
    }
  }

  private async pollTokenOnce(config: OAuthProviderConfig, grant: DeviceCodeGrant): Promise<TokenPollOutcome> {
    const body: string = buildTokenPollRequestBody(config.clientId, grant.deviceCode);
    let response: OAuthHttpResponse;
    try {
      response = await this.http.postForm(config.tokenUrl, body);
    } catch (e) {
      const err: Error = e as Error;
      const failed: TokenPollOutcome = {
        kind: TokenPollOutcomeKind.Failed,
        error: { kind: OAuthErrorKind.Network, message: err.message || 'Network failure' } as OAuthError
      };
      return failed;
    }
    return parseTokenPollResponse(response.body, response.statusCode);
  }

  private finalizeCancellation(provider: RepositoryProviderKind): OAuthSessionSnapshot {
    return this.transitionTo({
      provider: provider,
      state: OAuthSessionState.Cancelled,
      pollIntervalSeconds: 0,
      updatedAtMs: this.clock.nowMs()
    });
  }

  private transitionTo(next: OAuthSessionSnapshot): OAuthSessionSnapshot {
    if (this.snapshot && !this.isLegalTransition(this.snapshot.state, next.state)) {
      const failed: OAuthSessionSnapshot = {
        provider: next.provider,
        state: OAuthSessionState.Failed,
        error: {
          kind: OAuthErrorKind.IllegalTransition,
          message: `Illegal transition: ${this.snapshot.state} -> ${next.state}`
        } as OAuthError,
        pollIntervalSeconds: next.pollIntervalSeconds,
        updatedAtMs: next.updatedAtMs
      };
      this.snapshot = failed;
      this.emit(failed);
      return failed;
    }
    this.snapshot = next;
    this.emit(next);
    return next;
  }

  private emit(snapshot: OAuthSessionSnapshot): void {
    const copy: OAuthSessionListener[] = this.listeners.slice();
    for (let i = 0; i < copy.length; i++) {
      copy[i](snapshot);
    }
  }

  private isTerminal(state: OAuthSessionState): boolean {
    return state === OAuthSessionState.Authenticated
      || state === OAuthSessionState.Cancelled
      || state === OAuthSessionState.Failed;
  }

  private isLegalTransition(from: OAuthSessionState, to: OAuthSessionState): boolean {
    if (this.isTerminal(from)) {
      // Once terminal, only `start` can move us; that path resets snapshot.
      return false;
    }
    if (to === OAuthSessionState.Cancelled || to === OAuthSessionState.Failed) {
      return true;
    }
    if (from === OAuthSessionState.Idle) {
      return to === OAuthSessionState.RequestingDeviceCode;
    }
    if (from === OAuthSessionState.RequestingDeviceCode) {
      return to === OAuthSessionState.AwaitingUserAuthorization;
    }
    if (from === OAuthSessionState.AwaitingUserAuthorization) {
      return to === OAuthSessionState.ExchangingToken;
    }
    if (from === OAuthSessionState.ExchangingToken) {
      return to === OAuthSessionState.AwaitingUserAuthorization
        || to === OAuthSessionState.Authenticated;
    }
    return false;
  }
}
