import {
  CredentialId,
  RepositoryAuthContext,
  RepositoryCredential,
  RepositoryCredentialKind,
  RepositoryProviderKind
} from '../repository/domain/RepositoryTypes';

/**
 * Stored credential plus the bearer token used to authenticate API calls.
 *
 * The token lives alongside the credential record here for the in-memory
 * implementation. A future Asset Store Kit-backed implementation will
 * persist `accessToken` (and `refreshToken` if the provider supplies one)
 * in secure storage and only return the descriptor synchronously.
 */
export interface StoredRepositoryCredential {
  credential: RepositoryCredential;
  accessToken: string;
  refreshToken?: string;
}

export interface SaveOAuthTokenRequest {
  provider: RepositoryProviderKind;
  accessToken: string;
  refreshToken?: string;
  scopes: string[];
  accountLogin?: string;
  expiresAt?: number;
  displayName?: string;
}

/**
 * Persistence layer for repository credentials produced by the OAuth flow
 * (mirrors ModelCredentialStore in shape and lifecycle). Only OAuth tokens
 * are surfaced today; the interface is deliberately narrow so that
 * `Workspace.ets` can replace its hard-coded MOCK_CREDENTIAL with a real
 * lookup.
 */
export interface RepositoryCredentialStore {
  saveOAuthToken(request: SaveOAuthTokenRequest): Promise<StoredRepositoryCredential>;
  readActiveCredential(provider: RepositoryProviderKind): Promise<StoredRepositoryCredential | undefined>;
  resolveAuthContext(credentialId: CredentialId): Promise<RepositoryAuthContext | undefined>;
  deleteCredential(credentialId: CredentialId): Promise<void>;
  clearProvider(provider: RepositoryProviderKind): Promise<void>;
}

/**
 * In-memory implementation. Adequate for the OAuth flow's runtime needs in
 * a single session; persistence across launches is a follow-up that swaps
 * this class for an Asset Store Kit variant without touching call sites.
 */
export class InMemoryRepositoryCredentialStore implements RepositoryCredentialStore {
  private byId: Map<CredentialId, StoredRepositoryCredential> = new Map();
  private activeIdByProvider: Map<RepositoryProviderKind, CredentialId> = new Map();
  private idCounter: number = 0;

  public async saveOAuthToken(request: SaveOAuthTokenRequest): Promise<StoredRepositoryCredential> {
    this.idCounter += 1;
    const id: CredentialId = `oauth-${request.provider}-${this.idCounter}`;
    const displayName: string = request.displayName !== undefined && request.displayName.length > 0
      ? request.displayName
      : `${request.provider} OAuth token`;
    const credential: RepositoryCredential = {
      id: id,
      provider: request.provider,
      kind: RepositoryCredentialKind.OAuthToken,
      displayName: displayName,
      tokenRef: id,
      scopes: request.scopes.slice(),
      accountLogin: request.accountLogin,
      expiresAt: request.expiresAt
    };
    const stored: StoredRepositoryCredential = {
      credential: credential,
      accessToken: request.accessToken,
      refreshToken: request.refreshToken
    };
    // Replace any previous active credential for this provider.
    const previousId: CredentialId | undefined = this.activeIdByProvider.get(request.provider);
    if (previousId !== undefined) {
      this.byId.delete(previousId);
    }
    this.byId.set(id, stored);
    this.activeIdByProvider.set(request.provider, id);
    return stored;
  }

  public async readActiveCredential(provider: RepositoryProviderKind): Promise<StoredRepositoryCredential | undefined> {
    const activeId: CredentialId | undefined = this.activeIdByProvider.get(provider);
    if (activeId === undefined) {
      return undefined;
    }
    return this.byId.get(activeId);
  }

  public async resolveAuthContext(credentialId: CredentialId): Promise<RepositoryAuthContext | undefined> {
    const stored: StoredRepositoryCredential | undefined = this.byId.get(credentialId);
    if (!stored) {
      return undefined;
    }
    const ctx: RepositoryAuthContext = {
      credential: stored.credential,
      accessToken: stored.accessToken
    };
    return ctx;
  }

  public async deleteCredential(credentialId: CredentialId): Promise<void> {
    const stored: StoredRepositoryCredential | undefined = this.byId.get(credentialId);
    if (!stored) {
      return;
    }
    this.byId.delete(credentialId);
    const activeId: CredentialId | undefined = this.activeIdByProvider.get(stored.credential.provider);
    if (activeId === credentialId) {
      this.activeIdByProvider.delete(stored.credential.provider);
    }
  }

  public async clearProvider(provider: RepositoryProviderKind): Promise<void> {
    const activeId: CredentialId | undefined = this.activeIdByProvider.get(provider);
    if (activeId !== undefined) {
      this.byId.delete(activeId);
      this.activeIdByProvider.delete(provider);
    }
  }
}
