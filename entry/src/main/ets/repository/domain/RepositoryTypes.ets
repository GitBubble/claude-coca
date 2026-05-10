export type RepositoryProviderId = string;
export type RepositoryAccountId = string;
export type RepositoryId = string;
export type RepositoryFullName = string;
export type BranchName = string;
export type CommitSha = string;
export type RemoteFilePath = string;
export type IssueId = string;
export type ReviewRequestId = string;
export type CodeSessionId = string;
export type CredentialId = string;
export type SecretRef = string;

export enum RepositoryProviderKind {
  GitHub = 'github',
  Gitee = 'gitee',
  GitCode = 'gitcode'
}

export enum RepositoryCredentialKind {
  PersonalAccessToken = 'personalAccessToken',
  OAuthToken = 'oauthToken'
}

export enum RepositoryVisibility {
  Public = 'public',
  Private = 'private',
  Internal = 'internal',
  Unknown = 'unknown'
}

export enum RemoteEntryKind {
  File = 'file',
  Directory = 'directory',
  Symlink = 'symlink',
  Submodule = 'submodule',
  Unknown = 'unknown'
}

export enum FileChangeKind {
  Added = 'added',
  Modified = 'modified',
  Deleted = 'deleted',
  Renamed = 'renamed'
}

export enum ReviewRequestState {
  Open = 'open',
  Closed = 'closed',
  Merged = 'merged',
  Draft = 'draft',
  Unknown = 'unknown'
}

export enum RepositoryCapability {
  OAuth = 'oauth',
  PersonalAccessToken = 'personalAccessToken',
  EnterpriseHost = 'enterpriseHost',
  Issues = 'issues',
  PullRequests = 'pullRequests',
  MergeRequests = 'mergeRequests',
  FileSearch = 'fileSearch',
  BranchProtection = 'branchProtection',
  RateLimit = 'rateLimit',
  CompareRefs = 'compareRefs'
}

export interface RepositoryCredential {
  id: CredentialId;
  provider: RepositoryProviderKind;
  kind: RepositoryCredentialKind;
  displayName: string;
  tokenRef: SecretRef;
  scopes: string[];
  accountLogin?: string;
  enterpriseBaseUrl?: string;
  expiresAt?: number;
}

export interface RepositoryAuthContext {
  credential: RepositoryCredential;
  accessToken: string;
}

export interface RepositoryAccount {
  id: RepositoryAccountId;
  provider: RepositoryProviderKind;
  login: string;
  displayName: string;
  avatarUrl?: string;
  webUrl?: string;
}

export interface RepositoryOwner {
  id: string;
  login: string;
  displayName?: string;
  avatarUrl?: string;
  webUrl?: string;
}

export interface RepositoryRef {
  provider: RepositoryProviderKind;
  id: RepositoryId;
  owner: string;
  name: string;
  fullName: RepositoryFullName;
}

export interface RepositorySummary {
  ref: RepositoryRef;
  owner: RepositoryOwner;
  defaultBranch: BranchName;
  visibility: RepositoryVisibility;
  description?: string;
  webUrl?: string;
  cloneUrl?: string;
  language?: string;
  updatedAt?: number;
  archived: boolean;
  fork: boolean;
}

export interface BranchSummary {
  name: BranchName;
  commitSha: CommitSha;
  protected: boolean;
  webUrl?: string;
}

export interface RemoteTreeEntry {
  path: RemoteFilePath;
  name: string;
  kind: RemoteEntryKind;
  sha?: CommitSha;
  size?: number;
  webUrl?: string;
}

export interface RemoteFileContent {
  repository: RepositoryRef;
  branch: BranchName;
  path: RemoteFilePath;
  commitSha?: CommitSha;
  content: string;
  encoding: 'utf8' | 'base64';
  size?: number;
  contentHash?: string;
}

export interface SelectedFileRange {
  startLine: number;
  endLine: number;
}

export interface RepositoryContextFile {
  provider: RepositoryProviderKind;
  repository: RepositoryRef;
  branch: BranchName;
  path: RemoteFilePath;
  commitSha?: CommitSha;
  language?: string;
  content: string;
  contentHash?: string;
  selectedRanges: SelectedFileRange[];
}

export interface RepositoryContextBundle {
  id: string;
  createdAt: number;
  files: RepositoryContextFile[];
}

export interface FileChange {
  path: RemoteFilePath;
  kind: FileChangeKind;
  content?: string;
  previousPath?: RemoteFilePath;
  baseContentHash?: string;
}

export interface CommitChangesRequest {
  repository: RepositoryRef;
  branch: BranchName;
  baseCommitSha: CommitSha;
  message: string;
  changes: FileChange[];
}

export interface CommitResult {
  repository: RepositoryRef;
  branch: BranchName;
  commitSha: CommitSha;
  webUrl?: string;
}

export interface CreateBranchRequest {
  repository: RepositoryRef;
  sourceBranch: BranchName;
  sourceCommitSha: CommitSha;
  newBranchName: BranchName;
}

export interface ReviewRequestDraft {
  repository: RepositoryRef;
  sourceBranch: BranchName;
  targetBranch: BranchName;
  title: string;
  body: string;
  draft: boolean;
  linkedIssueId?: IssueId;
}

export interface ReviewRequest {
  id: ReviewRequestId;
  provider: RepositoryProviderKind;
  repository: RepositoryRef;
  sourceBranch: BranchName;
  targetBranch: BranchName;
  title: string;
  body?: string;
  state: ReviewRequestState;
  webUrl?: string;
  number?: number;
}

export interface IssueSummary {
  id: IssueId;
  number?: number;
  title: string;
  state: string;
  webUrl?: string;
}

export interface PaginationCursor {
  page?: number;
  perPage?: number;
  cursor?: string;
}

export interface PaginatedResult<T> {
  items: T[];
  nextCursor?: PaginationCursor;
}

export interface ListRepositoriesParams {
  query?: string;
  visibility?: RepositoryVisibility;
  pagination?: PaginationCursor;
}

export interface ListBranchesParams {
  repository: RepositoryRef;
  query?: string;
  pagination?: PaginationCursor;
}

export interface ListTreeParams {
  repository: RepositoryRef;
  branch: BranchName;
  path?: RemoteFilePath;
}

export interface ReadFileParams {
  repository: RepositoryRef;
  branch: BranchName;
  path: RemoteFilePath;
}

export interface SearchFilesParams {
  repository: RepositoryRef;
  branch: BranchName;
  query: string;
  pagination?: PaginationCursor;
}

export interface CompareRefsRequest {
  repository: RepositoryRef;
  baseRef: BranchName | CommitSha;
  headRef: BranchName | CommitSha;
}

export interface CompareFileChange {
  path: RemoteFilePath;
  kind: FileChangeKind;
  additions: number;
  deletions: number;
  patch?: string;
}

export interface CompareRefsResult {
  aheadBy: number;
  behindBy: number;
  files: CompareFileChange[];
  webUrl?: string;
}
