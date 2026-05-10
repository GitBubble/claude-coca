import { RepositoryProviderKind } from '../repository/domain/RepositoryTypes';

/**
 * Per-provider OAuth Device Flow configuration.
 *
 * `clientId` is intentionally NOT baked into source. It is supplied at
 * runtime from `AppSettingsStore.oauthClientIds` (Settings -> Connector),
 * keeping public IDs out of the repo and letting different builds /
 * forks point at their own OAuth applications without code changes.
 *
 * Endpoints below are documented:
 *  - GitHub:  https://docs.github.com/en/apps/oauth-apps/building-oauth-apps/authorizing-oauth-apps#device-flow
 *  - Gitee:   https://gitee.com/api/v5/oauth_doc#/list-item-3 (device code grant)
 *  - GitCode: follows the standard device flow on its OAuth server; the
 *             exact spelling of the endpoints should be verified on the
 *             provider's developer console (see docs/OAUTH_TESTING.md).
 */
export interface OAuthProviderConfig {
  provider: RepositoryProviderKind;
  /** Resolved at runtime from settings; may be empty (UI must guard). */
  clientId: string;
  scopes: string[];
  deviceCodeUrl: string;
  tokenUrl: string;
}

const GITHUB_DEVICE_CODE_URL: string = 'https://github.com/login/device/code';
const GITHUB_TOKEN_URL: string = 'https://github.com/login/oauth/access_token';
const GITHUB_SCOPES: string[] = ['repo', 'read:user'];

const GITEE_DEVICE_CODE_URL: string = 'https://gitee.com/oauth/device/code';
const GITEE_TOKEN_URL: string = 'https://gitee.com/oauth/token';
const GITEE_SCOPES: string[] = ['user_info', 'projects'];

const GITCODE_DEVICE_CODE_URL: string = 'https://gitcode.com/oauth/device/code';
const GITCODE_TOKEN_URL: string = 'https://gitcode.com/oauth/token';
const GITCODE_SCOPES: string[] = ['user_info', 'projects'];

/**
 * Settings-shaped value object holding the three user-editable client IDs.
 * Stored as a plain interface (no Map) so it round-trips through ArkTS
 * AppStorage / persistent settings without surprises.
 */
export interface OAuthClientIds {
  github: string;
  gitcode: string;
  gitee: string;
}

export const EMPTY_OAUTH_CLIENT_IDS: OAuthClientIds = {
  github: '',
  gitcode: '',
  gitee: ''
};

export function cloneOAuthClientIds(source: OAuthClientIds): OAuthClientIds {
  const copy: OAuthClientIds = {
    github: source.github,
    gitcode: source.gitcode,
    gitee: source.gitee
  };
  return copy;
}

/**
 * Build an OAuthProviderConfig by combining the static endpoint table with
 * the user-supplied client ID. Returns a config with empty `clientId` if
 * the user hasn't filled it in yet — callers must check before using.
 */
export function buildOAuthProviderConfig(
  provider: RepositoryProviderKind,
  clientIds: OAuthClientIds
): OAuthProviderConfig {
  if (provider === RepositoryProviderKind.GitHub) {
    const cfg: OAuthProviderConfig = {
      provider: provider,
      clientId: clientIds.github,
      scopes: GITHUB_SCOPES,
      deviceCodeUrl: GITHUB_DEVICE_CODE_URL,
      tokenUrl: GITHUB_TOKEN_URL
    };
    return cfg;
  }
  if (provider === RepositoryProviderKind.GitCode) {
    const cfg: OAuthProviderConfig = {
      provider: provider,
      clientId: clientIds.gitcode,
      scopes: GITCODE_SCOPES,
      deviceCodeUrl: GITCODE_DEVICE_CODE_URL,
      tokenUrl: GITCODE_TOKEN_URL
    };
    return cfg;
  }
  const cfg: OAuthProviderConfig = {
    provider: provider,
    clientId: clientIds.gitee,
    scopes: GITEE_SCOPES,
    deviceCodeUrl: GITEE_DEVICE_CODE_URL,
    tokenUrl: GITEE_TOKEN_URL
  };
  return cfg;
}
