import {
  BranchSummary,
  CommitChangesRequest,
  CommitResult,
  CompareRefsRequest,
  CompareRefsResult,
  CreateBranchRequest,
  IssueSummary,
  ListBranchesParams,
  ListRepositoriesParams,
  ListTreeParams,
  PaginatedResult,
  ReadFileParams,
  RemoteFileContent,
  RemoteTreeEntry,
  RepositoryAccount,
  RepositoryAuthContext,
  RepositoryCapability,
  RepositoryCredential,
  RepositoryCredentialKind,
  RepositoryProviderKind,
  RepositorySummary,
  ReviewRequest,
  ReviewRequestDraft,
  SearchFilesParams
} from '../domain/RepositoryTypes';

export enum RepositorySessionStatus {
  Valid = 'valid',
  Expired = 'expired',
  Revoked = 'revoked',
  MissingScope = 'missingScope',
  Unknown = 'unknown'
}

export interface RepositoryProviderMetadata {
  kind: RepositoryProviderKind;
  displayName: string;
  defaultApiBaseUrl: string;
  webBaseUrl: string;
  supportedCredentialKinds: RepositoryCredentialKind[];
  capabilities: RepositoryCapability[];
}

export interface RepositoryAuthenticationResult {
  credential: RepositoryCredential;
  account: RepositoryAccount;
  sessionStatus: RepositorySessionStatus;
}

export interface RepositoryProvider {
  getMetadata(): RepositoryProviderMetadata;

  authenticate(credential: RepositoryCredential, accessToken: string): Promise<RepositoryAuthenticationResult>;

  disconnect(auth: RepositoryAuthContext): Promise<void>;

  validateSession(auth: RepositoryAuthContext): Promise<RepositorySessionStatus>;

  listAccountsOrNamespaces(auth: RepositoryAuthContext): Promise<RepositoryAccount[]>;

  listRepositories(auth: RepositoryAuthContext, params?: ListRepositoriesParams): Promise<PaginatedResult<RepositorySummary>>;

  listBranches(auth: RepositoryAuthContext, params: ListBranchesParams): Promise<PaginatedResult<BranchSummary>>;

  getDefaultBranch(auth: RepositoryAuthContext, repository: RepositorySummary): Promise<BranchSummary>;

  listTree(auth: RepositoryAuthContext, params: ListTreeParams): Promise<RemoteTreeEntry[]>;

  readFile(auth: RepositoryAuthContext, params: ReadFileParams): Promise<RemoteFileContent>;

  searchFiles(auth: RepositoryAuthContext, params: SearchFilesParams): Promise<PaginatedResult<RemoteTreeEntry>>;

  compareRefs(auth: RepositoryAuthContext, params: CompareRefsRequest): Promise<CompareRefsResult>;

  createBranch(auth: RepositoryAuthContext, request: CreateBranchRequest): Promise<BranchSummary>;

  commitChanges(auth: RepositoryAuthContext, request: CommitChangesRequest): Promise<CommitResult>;

  createPullOrMergeRequest(auth: RepositoryAuthContext, draft: ReviewRequestDraft): Promise<ReviewRequest>;

  listIssues(auth: RepositoryAuthContext, repository: RepositorySummary): Promise<PaginatedResult<IssueSummary>>;

  listPullOrMergeRequests(auth: RepositoryAuthContext, repository: RepositorySummary): Promise<PaginatedResult<ReviewRequest>>;
}
