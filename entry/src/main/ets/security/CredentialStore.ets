import {
  CredentialId,
  RepositoryAuthContext,
  RepositoryCredential,
  RepositoryCredentialKind,
  RepositoryProviderKind
} from '../repository/domain/RepositoryTypes';

export interface SaveRepositoryCredentialRequest {
  provider: RepositoryProviderKind;
  kind: RepositoryCredentialKind;
  displayName: string;
  accessToken: string;
  scopes: string[];
  accountLogin?: string;
  enterpriseBaseUrl?: string;
  expiresAt?: number;
}

export interface CredentialStore {
  saveRepositoryCredential(request: SaveRepositoryCredentialRequest): Promise<RepositoryCredential>;

  listRepositoryCredentials(provider?: RepositoryProviderKind): Promise<RepositoryCredential[]>;

  resolveRepositoryAuthContext(credentialId: CredentialId): Promise<RepositoryAuthContext>;

  deleteRepositoryCredential(credentialId: CredentialId): Promise<void>;
}
