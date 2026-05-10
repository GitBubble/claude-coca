import { describe, it, expect } from '@ohos/hypium';
import { RepositoryProviderKind } from '../../../main/ets/repository/domain/RepositoryTypes';
import { OAuthService } from '../../../main/ets/oauth/OAuthService';
import { OAuthHttpClient, OAuthHttpResponse } from '../../../main/ets/oauth/OAuthHttpAdapter';
import { OAuthClientIds } from '../../../main/ets/oauth/OAuthConfig';
import {
  OAuthErrorKind,
  OAuthSessionSnapshot,
  OAuthSessionState
} from '../../../main/ets/oauth/OAuthTypes';

const CLIENT_IDS: OAuthClientIds = { github: 'gh-test', gitcode: '', gitee: '' };

interface ScriptedResponse {
  status: number;
  body: string;
}

/**
 * A scripted HTTP client: returns successive responses in order, one per
 * postForm call. Tracks the request bodies so tests can assert URL/body
 * shape. Falls back to a pre-configured "default" once the script is
 * exhausted (used to simulate "keep returning authorization_pending").
 */
class ScriptedHttpClient implements OAuthHttpClient {
  public urls: string[] = [];
  public bodies: string[] = [];
  private queue: ScriptedResponse[] = [];
  private fallback: ScriptedResponse;

  constructor(queue: ScriptedResponse[], fallback: ScriptedResponse) {
    this.queue = queue;
    this.fallback = fallback;
  }

  public postForm(url: string, body: string): Promise<OAuthHttpResponse> {
    this.urls.push(url);
    this.bodies.push(body);
    const next: ScriptedResponse = this.queue.length > 0 ? this.queue.shift() as ScriptedResponse : this.fallback;
    const response: OAuthHttpResponse = { statusCode: next.status, body: next.body };
    return Promise.resolve(response);
  }
}

/**
 * Fake clock with controllable virtual time. sleep() resolves immediately
 * but advances `nowMs()` by the requested delay so the polling loop's
 * deadline check is exercised deterministically.
 */
class FakeClock {
  private currentMs: number = 0;

  public nowMs(): number {
    return this.currentMs;
  }

  public sleep(durationMs: number): Promise<void> {
    this.currentMs += durationMs;
    return Promise.resolve();
  }
}

const DEVICE_CODE_OK: string = '{"device_code":"DC","user_code":"WDJB-MJHT","verification_uri":"https://github.com/login/device","expires_in":900,"interval":5}';
const DEVICE_CODE_SHORT_TTL: string = '{"device_code":"DC","user_code":"X","verification_uri":"https://github.com/login/device","expires_in":1,"interval":5}';
const TOKEN_PENDING: string = '{"error":"authorization_pending"}';
const TOKEN_SLOW_DOWN: string = '{"error":"slow_down"}';
const TOKEN_OK: string = '{"access_token":"gho_token","token_type":"bearer","scope":"repo read:user"}';
const TOKEN_DENIED: string = '{"error":"access_denied"}';

/**
 * State-machine integration tests. Drive OAuthService with a scripted
 * HTTP client + fake clock and assert the snapshot stream / final state.
 */
export default function oauthServiceTest() {
  describe('OAuthService', () => {
    it('reaches Authenticated after pending → success', 0, async () => {
      const http = new ScriptedHttpClient([
        { status: 200, body: DEVICE_CODE_OK },
        { status: 200, body: TOKEN_PENDING },
        { status: 200, body: TOKEN_OK }
      ], { status: 200, body: TOKEN_OK });
      const clock = new FakeClock();
      const states: OAuthSessionState[] = [];
      const service = new OAuthService({ http: http, clock: clock });
      service.subscribe((s: OAuthSessionSnapshot) => {
        states.push(s.state);
      });

      const final: OAuthSessionSnapshot = await service.start(RepositoryProviderKind.GitHub, CLIENT_IDS);

      expect(final.state).assertEqual(OAuthSessionState.Authenticated);
      expect(final.token!.accessToken).assertEqual('gho_token');
      // Two requests went out: device-code + at least one token poll.
      expect(http.urls[0]).assertEqual('https://github.com/login/device/code');
      expect(http.urls[1]).assertEqual('https://github.com/login/oauth/access_token');
      // The first request body carried the configured client_id.
      expect(http.bodies[0].indexOf('client_id=gh-test') >= 0).assertTrue();
    });

    it('honours slow_down by increasing the polling interval by 5s', 0, async () => {
      const http = new ScriptedHttpClient([
        { status: 200, body: DEVICE_CODE_OK },     // initial interval = 5
        { status: 200, body: TOKEN_SLOW_DOWN },    // -> interval becomes 10
        { status: 200, body: TOKEN_OK }
      ], { status: 200, body: TOKEN_OK });
      const clock = new FakeClock();
      const intervals: number[] = [];
      const service = new OAuthService({ http: http, clock: clock });
      service.subscribe((s: OAuthSessionSnapshot) => {
        if (s.state === OAuthSessionState.AwaitingUserAuthorization) {
          intervals.push(s.pollIntervalSeconds);
        }
      });

      await service.start(RepositoryProviderKind.GitHub, CLIENT_IDS);

      // First Awaiting at default 5; second Awaiting after slow_down at 10.
      expect(intervals[0]).assertEqual(5);
      expect(intervals[1]).assertEqual(10);
    });

    it('fails fast when no client_id is configured', 0, async () => {
      const http = new ScriptedHttpClient([], { status: 200, body: '' });
      const service = new OAuthService({ http: http, clock: new FakeClock() });

      const final = await service.start(RepositoryProviderKind.GitHub, { github: '', gitcode: '', gitee: '' });

      expect(final.state).assertEqual(OAuthSessionState.Failed);
      expect(final.error!.kind).assertEqual(OAuthErrorKind.MissingClientId);
      // No HTTP traffic should have been issued.
      expect(http.urls.length).assertEqual(0);
    });

    it('surfaces access_denied as a terminal Failed state', 0, async () => {
      const http = new ScriptedHttpClient([
        { status: 200, body: DEVICE_CODE_OK },
        { status: 400, body: TOKEN_DENIED }
      ], { status: 400, body: TOKEN_DENIED });
      const service = new OAuthService({ http: http, clock: new FakeClock() });

      const final = await service.start(RepositoryProviderKind.GitHub, CLIENT_IDS);

      expect(final.state).assertEqual(OAuthSessionState.Failed);
      expect(final.error!.kind).assertEqual(OAuthErrorKind.AccessDenied);
    });

    it('surfaces ExpiredToken when the device-code TTL elapses while polling', 0, async () => {
      // expires_in=1s, interval=5s → first sleep(5000ms) blows the deadline.
      const http = new ScriptedHttpClient([
        { status: 200, body: DEVICE_CODE_SHORT_TTL }
      ], { status: 200, body: TOKEN_PENDING });
      const service = new OAuthService({ http: http, clock: new FakeClock() });

      const final = await service.start(RepositoryProviderKind.GitHub, CLIENT_IDS);

      expect(final.state).assertEqual(OAuthSessionState.Failed);
      expect(final.error!.kind).assertEqual(OAuthErrorKind.ExpiredToken);
    });

    it('cancel() before completion ends the session in Cancelled', 0, async () => {
      const http = new ScriptedHttpClient([
        { status: 200, body: DEVICE_CODE_OK }
      ], { status: 200, body: TOKEN_PENDING });
      const service = new OAuthService({ http: http, clock: new FakeClock() });

      const promise = service.start(RepositoryProviderKind.GitHub, CLIENT_IDS);
      service.cancel();
      const final = await promise;

      expect(final.state).assertEqual(OAuthSessionState.Cancelled);
    });

    it('reports a Network failure when the HTTP layer throws', 0, async () => {
      class FailingHttp implements OAuthHttpClient {
        public postForm(_url: string, _body: string): Promise<OAuthHttpResponse> {
          return Promise.reject(new Error('connection refused'));
        }
      }
      const service = new OAuthService({ http: new FailingHttp(), clock: new FakeClock() });
      const final = await service.start(RepositoryProviderKind.GitHub, CLIENT_IDS);

      expect(final.state).assertEqual(OAuthSessionState.Failed);
      expect(final.error!.kind).assertEqual(OAuthErrorKind.Network);
    });

    it('starting a new session after a terminal one is permitted', 0, async () => {
      const http = new ScriptedHttpClient([
        // First session: access_denied
        { status: 200, body: DEVICE_CODE_OK },
        { status: 400, body: TOKEN_DENIED },
        // Second session: success
        { status: 200, body: DEVICE_CODE_OK },
        { status: 200, body: TOKEN_OK }
      ], { status: 200, body: TOKEN_OK });
      const service = new OAuthService({ http: http, clock: new FakeClock() });

      const first = await service.start(RepositoryProviderKind.GitHub, CLIENT_IDS);
      expect(first.state).assertEqual(OAuthSessionState.Failed);

      const second = await service.start(RepositoryProviderKind.GitHub, CLIENT_IDS);
      expect(second.state).assertEqual(OAuthSessionState.Authenticated);
    });
  });
}
