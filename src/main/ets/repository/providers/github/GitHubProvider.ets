import {
  BranchSummary,
  CommitChangesRequest,
  CommitResult,
  CompareFileChange,
  CompareRefsRequest,
  CompareRefsResult,
  CreateBranchRequest,
  FileChangeKind,
  IssueSummary,
  ListBranchesParams,
  ListRepositoriesParams,
  ListTreeParams,
  PaginatedResult,
  ReadFileParams,
  RemoteEntryKind,
  RemoteFileContent,
  RemoteTreeEntry,
  RepositoryAccount,
  RepositoryAuthContext,
  RepositoryCapability,
  RepositoryCredential,
  RepositoryCredentialKind,
  RepositoryProviderKind,
  RepositoryRef,
  RepositorySummary,
  RepositoryVisibility,
  ReviewRequest,
  ReviewRequestDraft,
  ReviewRequestState,
  SearchFilesParams
} from '../../domain/RepositoryTypes';
import { RepositoryErrorCode, RepositoryException, repositoryErrorFromHttpStatus } from '../../domain/RepositoryErrors';
import { RepositoryProvider, RepositoryAuthenticationResult, RepositoryProviderMetadata, RepositorySessionStatus } from '../RepositoryProvider';
import { buildUrl, RepositoryHttpClient, RepositoryHttpResponse } from '../RepositoryHttpClient';

interface GitHubUserResponse {
  id: number;
  login: string;
  name?: string;
  avatar_url?: string;
  html_url?: string;
}

interface GitHubOwnerResponse {
  id: number;
  login: string;
  avatar_url?: string;
  html_url?: string;
}

interface GitHubRepositoryResponse {
  id: number;
  name: string;
  full_name: string;
  owner: GitHubOwnerResponse;
  private: boolean;
  visibility?: string;
  description?: string;
  html_url?: string;
  clone_url?: string;
  default_branch: string;
  language?: string;
  updated_at?: string;
  archived: boolean;
  fork: boolean;
}

interface GitHubBranchResponse {
  name: string;
  commit: { sha: string };
  protected: boolean;
}

interface GitHubContentResponse {
  name: string;
  path: string;
  sha?: string;
  type: string;
  size?: number;
  html_url?: string;
  content?: string;
  encoding?: string;
}

interface GitHubPullResponse {
  id: number;
  number: number;
  title: string;
  body?: string;
  state: string;
  draft?: boolean;
  html_url?: string;
  head: { ref: string };
  base: { ref: string };
}

interface GitHubIssueResponse {
  id: number;
  number: number;
  title: string;
  state: string;
  html_url?: string;
}

interface GitHubCompareResponse {
  ahead_by: number;
  behind_by: number;
  html_url?: string;
  files?: Array<{
    filename: string;
    status: string;
    additions: number;
    deletions: number;
    patch?: string;
  }>;
}

export class GitHubProvider implements RepositoryProvider {
  private readonly httpClient: RepositoryHttpClient;
  private readonly apiBaseUrl: string;

  public constructor(httpClient: RepositoryHttpClient, apiBaseUrl: string = 'https://api.github.com') {
    this.httpClient = httpClient;
    this.apiBaseUrl = apiBaseUrl;
  }

  public getMetadata(): RepositoryProviderMetadata {
    return {
      kind: RepositoryProviderKind.GitHub,
      displayName: 'GitHub',
      defaultApiBaseUrl: this.apiBaseUrl,
      webBaseUrl: 'https://github.com',
      supportedCredentialKinds: [RepositoryCredentialKind.PersonalAccessToken, RepositoryCredentialKind.OAuthToken],
      capabilities: [
        RepositoryCapability.PersonalAccessToken,
        RepositoryCapability.OAuth,
        RepositoryCapability.EnterpriseHost,
        RepositoryCapability.Issues,
        RepositoryCapability.PullRequests,
        RepositoryCapability.FileSearch,
        RepositoryCapability.BranchProtection,
        RepositoryCapability.RateLimit,
        RepositoryCapability.CompareRefs
      ]
    };
  }

  public async authenticate(credential: RepositoryCredential, accessToken: string): Promise<RepositoryAuthenticationResult> {
    const auth: RepositoryAuthContext = { credential, accessToken };
    const response = await this.request<GitHubUserResponse>(auth, 'GET', '/user', undefined, undefined, 'GitHubProvider.authenticate');
    const account: RepositoryAccount = {
      id: String(response.data.id),
      provider: RepositoryProviderKind.GitHub,
      login: response.data.login,
      displayName: response.data.name || response.data.login,
      avatarUrl: response.data.avatar_url,
      webUrl: response.data.html_url
    };
    return { credential, account, sessionStatus: RepositorySessionStatus.Valid };
  }

  public async disconnect(_auth: RepositoryAuthContext): Promise<void> {
    return Promise.resolve();
  }

  public async validateSession(auth: RepositoryAuthContext): Promise<RepositorySessionStatus> {
    try {
      await this.request<GitHubUserResponse>(auth, 'GET', '/user', undefined, undefined, 'GitHubProvider.validateSession');
      return RepositorySessionStatus.Valid;
    } catch (_error) {
      return RepositorySessionStatus.Unknown;
    }
  }

  public async listAccountsOrNamespaces(auth: RepositoryAuthContext): Promise<RepositoryAccount[]> {
    const authentication = await this.authenticate(auth.credential, auth.accessToken);
    return [authentication.account];
  }

  public async listRepositories(auth: RepositoryAuthContext, params?: ListRepositoriesParams): Promise<PaginatedResult<RepositorySummary>> {
    const response = await this.request<GitHubRepositoryResponse[]>(auth, 'GET', '/user/repos', {
      per_page: params?.pagination?.perPage || 50,
      page: params?.pagination?.page || 1,
      sort: 'updated',
      direction: 'desc',
      visibility: params?.visibility && params.visibility !== RepositoryVisibility.Unknown ? params.visibility : undefined
    }, undefined, 'GitHubProvider.listRepositories');

    return {
      items: response.data.map((repository: GitHubRepositoryResponse) => this.mapRepository(repository)),
      nextCursor: undefined
    };
  }

  public async listBranches(auth: RepositoryAuthContext, params: ListBranchesParams): Promise<PaginatedResult<BranchSummary>> {
    const response = await this.request<GitHubBranchResponse[]>(auth, 'GET', `/repos/${params.repository.owner}/${params.repository.name}/branches`, {
      per_page: params.pagination?.perPage || 50,
      page: params.pagination?.page || 1,
      protected: undefined
    }, undefined, 'GitHubProvider.listBranches');
    const branches = response.data
      .filter((branch: GitHubBranchResponse) => !params.query || branch.name.includes(params.query))
      .map((branch: GitHubBranchResponse) => this.mapBranch(branch));
    return { items: branches, nextCursor: undefined };
  }

  public async getDefaultBranch(auth: RepositoryAuthContext, repository: RepositorySummary): Promise<BranchSummary> {
    const branches = await this.listBranches(auth, { repository: repository.ref, query: repository.defaultBranch });
    const branch = branches.items.find((candidate: BranchSummary) => candidate.name === repository.defaultBranch);
    if (!branch) {
      throw new RepositoryException({
        code: RepositoryErrorCode.NotFound,
        message: `Default branch was not found: ${repository.defaultBranch}`,
        provider: RepositoryProviderKind.GitHub,
        operation: 'GitHubProvider.getDefaultBranch'
      });
    }
    return branch;
  }

  public async listTree(auth: RepositoryAuthContext, params: ListTreeParams): Promise<RemoteTreeEntry[]> {
    const path = params.path ? `/contents/${params.path}` : '/contents';
    const response = await this.request<GitHubContentResponse[] | GitHubContentResponse>(auth, 'GET', `/repos/${params.repository.owner}/${params.repository.name}${path}`, {
      ref: params.branch
    }, undefined, 'GitHubProvider.listTree');
    const contentItems = Array.isArray(response.data) ? response.data : [response.data];
    return contentItems.map((item: GitHubContentResponse) => this.mapTreeEntry(item));
  }

  public async readFile(auth: RepositoryAuthContext, params: ReadFileParams): Promise<RemoteFileContent> {
    const response = await this.request<GitHubContentResponse>(auth, 'GET', `/repos/${params.repository.owner}/${params.repository.name}/contents/${params.path}`, {
      ref: params.branch
    }, undefined, 'GitHubProvider.readFile');
    if (response.data.type !== 'file') {
      throw new RepositoryException({
        code: RepositoryErrorCode.NotFound,
        message: `Remote path is not a file: ${params.path}`,
        provider: RepositoryProviderKind.GitHub,
        operation: 'GitHubProvider.readFile'
      });
    }
    return {
      repository: params.repository,
      branch: params.branch,
      path: params.path,
      commitSha: response.data.sha,
      content: response.data.content || '',
      encoding: response.data.encoding === 'base64' ? 'base64' : 'utf8',
      size: response.data.size,
      contentHash: response.data.sha
    };
  }

  public async searchFiles(_auth: RepositoryAuthContext, _params: SearchFilesParams): Promise<PaginatedResult<RemoteTreeEntry>> {
    throw new RepositoryException({
      code: RepositoryErrorCode.UnsupportedCapability,
      message: 'GitHub file search is not wired yet.',
      provider: RepositoryProviderKind.GitHub,
      operation: 'GitHubProvider.searchFiles'
    });
  }

  public async compareRefs(auth: RepositoryAuthContext, params: CompareRefsRequest): Promise<CompareRefsResult> {
    const response = await this.request<GitHubCompareResponse>(auth, 'GET', `/repos/${params.repository.owner}/${params.repository.name}/compare/${params.baseRef}...${params.headRef}`, undefined, undefined, 'GitHubProvider.compareRefs');
    return {
      aheadBy: response.data.ahead_by,
      behindBy: response.data.behind_by,
      webUrl: response.data.html_url,
      files: (response.data.files || []).map((file: { filename: string; status: string; additions: number; deletions: number; patch?: string }) => {
        const change: CompareFileChange = {
          path: file.filename,
          kind: file.status === 'added' ? FileChangeKind.Added : file.status === 'removed' ? FileChangeKind.Deleted : FileChangeKind.Modified,
          additions: file.additions,
          deletions: file.deletions,
          patch: file.patch
        };
        return change;
      })
    };
  }

  public async createBranch(auth: RepositoryAuthContext, request: CreateBranchRequest): Promise<BranchSummary> {
    await this.request<Object>(auth, 'POST', `/repos/${request.repository.owner}/${request.repository.name}/git/refs`, undefined, {
      ref: `refs/heads/${request.newBranchName}`,
      sha: request.sourceCommitSha
    }, 'GitHubProvider.createBranch');
    return {
      name: request.newBranchName,
      commitSha: request.sourceCommitSha,
      protected: false
    };
  }

  public async commitChanges(_auth: RepositoryAuthContext, _request: CommitChangesRequest): Promise<CommitResult> {
    throw new RepositoryException({
      code: RepositoryErrorCode.UnsupportedCapability,
      message: 'GitHub multi-file commit creation is queued for the next implementation slice.',
      provider: RepositoryProviderKind.GitHub,
      operation: 'GitHubProvider.commitChanges'
    });
  }

  public async createPullOrMergeRequest(auth: RepositoryAuthContext, draft: ReviewRequestDraft): Promise<ReviewRequest> {
    const response = await this.request<GitHubPullResponse>(auth, 'POST', `/repos/${draft.repository.owner}/${draft.repository.name}/pulls`, undefined, {
      title: draft.title,
      body: draft.body,
      head: draft.sourceBranch,
      base: draft.targetBranch,
      draft: draft.draft
    }, 'GitHubProvider.createPullOrMergeRequest');
    return this.mapPullRequest(draft.repository, response.data);
  }

  public async listIssues(auth: RepositoryAuthContext, repository: RepositorySummary): Promise<PaginatedResult<IssueSummary>> {
    const response = await this.request<GitHubIssueResponse[]>(auth, 'GET', `/repos/${repository.ref.owner}/${repository.ref.name}/issues`, {
      state: 'open',
      per_page: 50
    }, undefined, 'GitHubProvider.listIssues');
    return {
      items: response.data.map((issue: GitHubIssueResponse) => ({
        id: String(issue.id),
        number: issue.number,
        title: issue.title,
        state: issue.state,
        webUrl: issue.html_url
      })),
      nextCursor: undefined
    };
  }

  public async listPullOrMergeRequests(auth: RepositoryAuthContext, repository: RepositorySummary): Promise<PaginatedResult<ReviewRequest>> {
    const response = await this.request<GitHubPullResponse[]>(auth, 'GET', `/repos/${repository.ref.owner}/${repository.ref.name}/pulls`, {
      state: 'open',
      per_page: 50
    }, undefined, 'GitHubProvider.listPullOrMergeRequests');
    return {
      items: response.data.map((pullRequest: GitHubPullResponse) => this.mapPullRequest(repository.ref, pullRequest)),
      nextCursor: undefined
    };
  }

  private async request<T>(auth: RepositoryAuthContext, method: 'GET' | 'POST' | 'PATCH' | 'PUT' | 'DELETE', path: string, query: Record<string, string | number | boolean | undefined> | undefined, body: Record<string, Object | string | number | boolean | null> | undefined, operation: string): Promise<RepositoryHttpResponse<T>> {
    const response = await this.httpClient.send<T>({
      method,
      url: buildUrl(this.apiBaseUrl, path, query),
      headers: {
        Accept: 'application/vnd.github+json',
        Authorization: `Bearer ${auth.accessToken}`,
        'X-GitHub-Api-Version': '2022-11-28'
      },
      body
    });
    if (response.statusCode >= 400) {
      throw repositoryErrorFromHttpStatus(response.statusCode, `GitHub request failed: ${operation}`, operation, RepositoryProviderKind.GitHub);
    }
    return response;
  }

  private mapRepository(repository: GitHubRepositoryResponse): RepositorySummary {
    const visibility = repository.private ? RepositoryVisibility.Private : RepositoryVisibility.Public;
    return {
      ref: {
        provider: RepositoryProviderKind.GitHub,
        id: String(repository.id),
        owner: repository.owner.login,
        name: repository.name,
        fullName: repository.full_name
      },
      owner: {
        id: String(repository.owner.id),
        login: repository.owner.login,
        displayName: repository.owner.login,
        avatarUrl: repository.owner.avatar_url,
        webUrl: repository.owner.html_url
      },
      defaultBranch: repository.default_branch,
      visibility,
      description: repository.description,
      webUrl: repository.html_url,
      cloneUrl: repository.clone_url,
      language: repository.language,
      updatedAt: repository.updated_at ? new Date(repository.updated_at).getTime() : undefined,
      archived: repository.archived,
      fork: repository.fork
    };
  }

  private mapBranch(branch: GitHubBranchResponse): BranchSummary {
    return {
      name: branch.name,
      commitSha: branch.commit.sha,
      protected: branch.protected
    };
  }

  private mapTreeEntry(item: GitHubContentResponse): RemoteTreeEntry {
    return {
      path: item.path,
      name: item.name,
      kind: this.mapEntryKind(item.type),
      sha: item.sha,
      size: item.size,
      webUrl: item.html_url
    };
  }

  private mapEntryKind(type: string): RemoteEntryKind {
    if (type === 'file') {
      return RemoteEntryKind.File;
    }
    if (type === 'dir') {
      return RemoteEntryKind.Directory;
    }
    if (type === 'symlink') {
      return RemoteEntryKind.Symlink;
    }
    if (type === 'submodule') {
      return RemoteEntryKind.Submodule;
    }
    return RemoteEntryKind.Unknown;
  }

  private mapPullRequest(repository: RepositoryRef, pullRequest: GitHubPullResponse): ReviewRequest {
    return {
      id: String(pullRequest.id),
      provider: RepositoryProviderKind.GitHub,
      repository,
      sourceBranch: pullRequest.head.ref,
      targetBranch: pullRequest.base.ref,
      title: pullRequest.title,
      body: pullRequest.body,
      number: pullRequest.number,
      state: pullRequest.draft ? ReviewRequestState.Draft : pullRequest.state === 'closed' ? ReviewRequestState.Closed : ReviewRequestState.Open,
      webUrl: pullRequest.html_url
    };
  }
}
