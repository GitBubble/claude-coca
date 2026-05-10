import { describe, it, expect } from '@ohos/hypium';
import { RepositoryProviderKind } from '../../../main/ets/repository/domain/RepositoryTypes';
import {
  applySlowDown,
  buildDeviceCodeRequestBody,
  buildTokenPollRequestBody,
  describeProvider,
  parseDeviceCodeResponse,
  parseTokenPollResponse
} from '../../../main/ets/oauth/OAuthParsing';
import {
  buildOAuthProviderConfig,
  EMPTY_OAUTH_CLIENT_IDS,
  OAuthClientIds
} from '../../../main/ets/oauth/OAuthConfig';
import { OAuthErrorKind, TokenPollOutcomeKind } from '../../../main/ets/oauth/OAuthTypes';

/**
 * Tests for the pure URL/body builders and response parsers in OAuthParsing.
 * These cover every documented response shape per RFC 8628 §3.5 plus the
 * malformed/non-JSON edge cases.
 */
export default function oauthParsingTest() {
  describe('OAuthParsing', () => {
    it('builds the device-code request with form-encoded client_id and space-separated scopes', 0, () => {
      const body: string = buildDeviceCodeRequestBody('abc123', ['repo', 'read:user']);
      expect(body).assertEqual('client_id=abc123&scope=repo%20read%3Auser');
    });

    it('builds the token-poll body with the RFC 8628 grant_type', 0, () => {
      const body: string = buildTokenPollRequestBody('abc123', 'dev-code-xyz');
      expect(body.indexOf('grant_type=urn%3Aietf%3Aparams%3Aoauth%3Agrant-type%3Adevice_code') >= 0).assertTrue();
      expect(body.indexOf('client_id=abc123') >= 0).assertTrue();
      expect(body.indexOf('device_code=dev-code-xyz') >= 0).assertTrue();
    });

    it('parses a well-formed device-code response with all fields', 0, () => {
      const raw = '{"device_code":"DC","user_code":"WDJB-MJHT","verification_uri":"https://example.com/device","verification_uri_complete":"https://example.com/device?user_code=WDJB-MJHT","expires_in":900,"interval":5}';
      const grant = parseDeviceCodeResponse(raw);
      expect(grant !== undefined).assertTrue();
      expect(grant!.deviceCode).assertEqual('DC');
      expect(grant!.userCode).assertEqual('WDJB-MJHT');
      expect(grant!.verificationUri).assertEqual('https://example.com/device');
      expect(grant!.verificationUriComplete).assertEqual('https://example.com/device?user_code=WDJB-MJHT');
      expect(grant!.expiresInSeconds).assertEqual(900);
      expect(grant!.intervalSeconds).assertEqual(5);
    });

    it('falls back to safe defaults when expires_in / interval are missing', 0, () => {
      const raw = '{"device_code":"DC","user_code":"X","verification_uri":"https://example.com/device"}';
      const grant = parseDeviceCodeResponse(raw);
      expect(grant !== undefined).assertTrue();
      expect(grant!.expiresInSeconds > 0).assertTrue();
      expect(grant!.intervalSeconds > 0).assertTrue();
    });

    it('returns undefined when device-code response is missing required fields', 0, () => {
      const raw = '{"device_code":"DC","verification_uri":"https://example.com/device"}'; // no user_code
      expect(parseDeviceCodeResponse(raw)).assertEqual(undefined);
    });

    it('returns undefined when device-code response is not JSON', 0, () => {
      expect(parseDeviceCodeResponse('not-json-at-all')).assertEqual(undefined);
    });

    it('parses a successful token-poll into a Token outcome', 0, () => {
      const raw = '{"access_token":"gho_xxx","token_type":"bearer","scope":"repo read:user"}';
      const outcome = parseTokenPollResponse(raw, 200);
      expect(outcome.kind).assertEqual(TokenPollOutcomeKind.Token);
      expect(outcome.token!.accessToken).assertEqual('gho_xxx');
      expect(outcome.token!.tokenType).assertEqual('bearer');
      expect(outcome.token!.scopes.length).assertEqual(2);
    });

    it('treats authorization_pending as a transient outcome', 0, () => {
      const raw = '{"error":"authorization_pending","error_description":"User has not yet entered the code"}';
      const outcome = parseTokenPollResponse(raw, 400);
      expect(outcome.kind).assertEqual(TokenPollOutcomeKind.AuthorizationPending);
    });

    it('treats slow_down as a transient outcome', 0, () => {
      const raw = '{"error":"slow_down"}';
      const outcome = parseTokenPollResponse(raw, 400);
      expect(outcome.kind).assertEqual(TokenPollOutcomeKind.SlowDown);
    });

    it('maps expired_token to a Failed outcome with ExpiredToken kind', 0, () => {
      const raw = '{"error":"expired_token"}';
      const outcome = parseTokenPollResponse(raw, 400);
      expect(outcome.kind).assertEqual(TokenPollOutcomeKind.Failed);
      expect(outcome.error!.kind).assertEqual(OAuthErrorKind.ExpiredToken);
    });

    it('maps access_denied to a Failed outcome with AccessDenied kind', 0, () => {
      const raw = '{"error":"access_denied"}';
      const outcome = parseTokenPollResponse(raw, 400);
      expect(outcome.kind).assertEqual(TokenPollOutcomeKind.Failed);
      expect(outcome.error!.kind).assertEqual(OAuthErrorKind.AccessDenied);
    });

    it('maps unknown OAuth error codes to a generic Provider failure', 0, () => {
      const raw = '{"error":"server_error","error_description":"oh no"}';
      const outcome = parseTokenPollResponse(raw, 500);
      expect(outcome.kind).assertEqual(TokenPollOutcomeKind.Failed);
      expect(outcome.error!.kind).assertEqual(OAuthErrorKind.Provider);
    });

    it('reports Malformed when token response has neither access_token nor error', 0, () => {
      const raw = '{"unrelated":"value"}';
      const outcome = parseTokenPollResponse(raw, 200);
      expect(outcome.kind).assertEqual(TokenPollOutcomeKind.Failed);
      expect(outcome.error!.kind).assertEqual(OAuthErrorKind.Malformed);
    });

    it('reports Provider failure on non-JSON, non-2xx token responses', 0, () => {
      const outcome = parseTokenPollResponse('<html>oops</html>', 502);
      expect(outcome.kind).assertEqual(TokenPollOutcomeKind.Failed);
      expect(outcome.error!.kind).assertEqual(OAuthErrorKind.Provider);
    });

    it('applySlowDown adds 5 seconds per RFC 8628 §3.5', 0, () => {
      expect(applySlowDown(5)).assertEqual(10);
      expect(applySlowDown(10)).assertEqual(15);
    });

    it('describeProvider returns user-facing names', 0, () => {
      expect(describeProvider(RepositoryProviderKind.GitHub)).assertEqual('GitHub');
      expect(describeProvider(RepositoryProviderKind.GitCode)).assertEqual('GitCode');
      expect(describeProvider(RepositoryProviderKind.Gitee)).assertEqual('Gitee');
    });
  });

  describe('OAuthConfig', () => {
    it('uses the configured client ID for each provider', 0, () => {
      const ids: OAuthClientIds = { github: 'GH_ID', gitcode: 'GC_ID', gitee: 'GE_ID' };
      expect(buildOAuthProviderConfig(RepositoryProviderKind.GitHub, ids).clientId).assertEqual('GH_ID');
      expect(buildOAuthProviderConfig(RepositoryProviderKind.GitCode, ids).clientId).assertEqual('GC_ID');
      expect(buildOAuthProviderConfig(RepositoryProviderKind.Gitee, ids).clientId).assertEqual('GE_ID');
    });

    it('returns an empty client ID when not configured (UI must guard)', 0, () => {
      const config = buildOAuthProviderConfig(RepositoryProviderKind.GitHub, EMPTY_OAUTH_CLIENT_IDS);
      expect(config.clientId).assertEqual('');
    });

    it('targets the documented endpoints for each provider', 0, () => {
      const ids: OAuthClientIds = { github: 'a', gitcode: 'b', gitee: 'c' };
      const gh = buildOAuthProviderConfig(RepositoryProviderKind.GitHub, ids);
      expect(gh.deviceCodeUrl).assertEqual('https://github.com/login/device/code');
      expect(gh.tokenUrl).assertEqual('https://github.com/login/oauth/access_token');
      const ge = buildOAuthProviderConfig(RepositoryProviderKind.Gitee, ids);
      expect(ge.deviceCodeUrl.indexOf('gitee.com') >= 0).assertTrue();
    });
  });
}
