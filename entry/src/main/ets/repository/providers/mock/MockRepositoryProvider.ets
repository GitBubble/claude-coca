import {
  BranchName,
  BranchSummary,
  CommitChangesRequest,
  CommitResult,
  CompareRefsRequest,
  CompareRefsResult,
  CreateBranchRequest,
  FileChange,
  FileChangeKind,
  IssueSummary,
  ListBranchesParams,
  ListRepositoriesParams,
  ListTreeParams,
  PaginatedResult,
  ReadFileParams,
  RemoteEntryKind,
  RemoteFileContent,
  RemoteFilePath,
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
import { RepositoryErrorCode, RepositoryException } from '../../domain/RepositoryErrors';
import { RepositoryProvider, RepositoryAuthenticationResult, RepositoryProviderMetadata, RepositorySessionStatus } from '../RepositoryProvider';

export interface MockRepositoryProviderSeed {
  account?: RepositoryAccount;
  repositories?: RepositorySummary[];
  branchesByRepository?: Record<string, BranchSummary[]>;
  filesByRepositoryBranch?: Record<string, RemoteFileContent[]>;
  issuesByRepository?: Record<string, IssueSummary[]>;
  reviewRequestsByRepository?: Record<string, ReviewRequest[]>;
}

export class MockRepositoryProvider implements RepositoryProvider {
  private readonly account: RepositoryAccount;
  private readonly repositories: RepositorySummary[];
  private readonly branchesByRepository: Map<string, BranchSummary[]> = new Map();
  private readonly filesByRepositoryBranch: Map<string, RemoteFileContent[]> = new Map();
  private readonly issuesByRepository: Map<string, IssueSummary[]> = new Map();
  private readonly reviewRequestsByRepository: Map<string, ReviewRequest[]> = new Map();

  public constructor(seed?: MockRepositoryProviderSeed) {
    this.account = seed?.account || createDefaultAccount();
    this.repositories = seed?.repositories || [createDefaultRepository()];
    this.seedMap(this.branchesByRepository, seed?.branchesByRepository);
    this.seedMap(this.filesByRepositoryBranch, seed?.filesByRepositoryBranch);
    this.seedMap(this.issuesByRepository, seed?.issuesByRepository);
    this.seedMap(this.reviewRequestsByRepository, seed?.reviewRequestsByRepository);
    this.ensureDefaultRepositoryData();
  }

  public getMetadata(): RepositoryProviderMetadata {
    return {
      kind: RepositoryProviderKind.GitHub,
      displayName: 'Mock GitHub',
      defaultApiBaseUrl: 'mock://github',
      webBaseUrl: 'mock://github',
      supportedCredentialKinds: [RepositoryCredentialKind.PersonalAccessToken],
      capabilities: [
        RepositoryCapability.PersonalAccessToken,
        RepositoryCapability.Issues,
        RepositoryCapability.PullRequests,
        RepositoryCapability.FileSearch,
        RepositoryCapability.CompareRefs
      ]
    };
  }

  public async authenticate(credential: RepositoryCredential, _accessToken: string): Promise<RepositoryAuthenticationResult> {
    return { credential, account: this.account, sessionStatus: RepositorySessionStatus.Valid };
  }

  public async disconnect(_auth: RepositoryAuthContext): Promise<void> {
    return Promise.resolve();
  }

  public async validateSession(_auth: RepositoryAuthContext): Promise<RepositorySessionStatus> {
    return RepositorySessionStatus.Valid;
  }

  public async listAccountsOrNamespaces(_auth: RepositoryAuthContext): Promise<RepositoryAccount[]> {
    return [this.account];
  }

  public async listRepositories(_auth: RepositoryAuthContext, params?: ListRepositoriesParams): Promise<PaginatedResult<RepositorySummary>> {
    const filteredRepositories = this.repositories.filter((repository: RepositorySummary) => {
      const matchesQuery = !params?.query || repository.ref.fullName.includes(params.query) || (repository.description || '').includes(params.query);
      const matchesVisibility = !params?.visibility || params.visibility === RepositoryVisibility.Unknown || repository.visibility === params.visibility;
      return matchesQuery && matchesVisibility;
    });
    return { items: filteredRepositories, nextCursor: undefined };
  }

  public async listBranches(_auth: RepositoryAuthContext, params: ListBranchesParams): Promise<PaginatedResult<BranchSummary>> {
    const branches = this.getBranches(params.repository).filter((branch: BranchSummary) => !params.query || branch.name.includes(params.query));
    return { items: branches, nextCursor: undefined };
  }

  public async getDefaultBranch(_auth: RepositoryAuthContext, repository: RepositorySummary): Promise<BranchSummary> {
    const branches = this.getBranches(repository.ref);
    const branch = branches.find((candidate: BranchSummary) => candidate.name === repository.defaultBranch);
    if (!branch) {
      throw new RepositoryException({
        code: RepositoryErrorCode.NotFound,
        message: `Default branch not found: ${repository.defaultBranch}`,
        provider: RepositoryProviderKind.GitHub,
        operation: 'MockRepositoryProvider.getDefaultBranch'
      });
    }
    return branch;
  }

  public async listTree(_auth: RepositoryAuthContext, params: ListTreeParams): Promise<RemoteTreeEntry[]> {
    const files = this.getFiles(params.repository, params.branch);
    const prefix = params.path && params.path.length > 0 ? `${params.path}/` : '';
    const directoryNames: Set<string> = new Set();
    const entries: RemoteTreeEntry[] = [];

    files.forEach((file: RemoteFileContent) => {
      if (!file.path.startsWith(prefix)) {
        return;
      }
      const relativePath = file.path.substring(prefix.length);
      if (relativePath.length === 0) {
        return;
      }
      const separatorIndex = relativePath.indexOf('/');
      if (separatorIndex >= 0) {
        const directoryName = relativePath.substring(0, separatorIndex);
        directoryNames.add(directoryName);
        return;
      }
      entries.push({
        path: file.path,
        name: relativePath,
        kind: RemoteEntryKind.File,
        sha: file.commitSha,
        size: file.size
      });
    });

    directoryNames.forEach((directoryName: string) => {
      entries.push({
        path: `${prefix}${directoryName}`,
        name: directoryName,
        kind: RemoteEntryKind.Directory
      });
    });

    return entries.sort((left: RemoteTreeEntry, right: RemoteTreeEntry) => left.name.localeCompare(right.name));
  }

  public async readFile(_auth: RepositoryAuthContext, params: ReadFileParams): Promise<RemoteFileContent> {
    const file = this.getFiles(params.repository, params.branch).find((candidate: RemoteFileContent) => candidate.path === params.path);
    if (!file) {
      throw new RepositoryException({
        code: RepositoryErrorCode.NotFound,
        message: `File not found: ${params.path}`,
        provider: RepositoryProviderKind.GitHub,
        operation: 'MockRepositoryProvider.readFile'
      });
    }
    return file;
  }

  public async searchFiles(_auth: RepositoryAuthContext, params: SearchFilesParams): Promise<PaginatedResult<RemoteTreeEntry>> {
    const query = params.query.toLowerCase();
    const items = this.getFiles(params.repository, params.branch)
      .filter((file: RemoteFileContent) => file.path.toLowerCase().includes(query) || file.content.toLowerCase().includes(query))
      .map((file: RemoteFileContent) => {
        const entry: RemoteTreeEntry = {
          path: file.path,
          name: basename(file.path),
          kind: RemoteEntryKind.File,
          sha: file.commitSha,
          size: file.size
        };
        return entry;
      });
    const result: PaginatedResult<RemoteTreeEntry> = { items, nextCursor: undefined };
    return result;
  }

  public async compareRefs(_auth: RepositoryAuthContext, _params: CompareRefsRequest): Promise<CompareRefsResult> {
    const result: CompareRefsResult = { aheadBy: 0, behindBy: 0, files: [] };
    return result;
  }

  public async createBranch(_auth: RepositoryAuthContext, request: CreateBranchRequest): Promise<BranchSummary> {
    const branches = this.getBranches(request.repository);
    const existingBranch = branches.find((branch: BranchSummary) => branch.name === request.newBranchName);
    if (existingBranch) {
      throw new RepositoryException({
        code: RepositoryErrorCode.Conflict,
        message: `Branch already exists: ${request.newBranchName}`,
        provider: RepositoryProviderKind.GitHub,
        operation: 'MockRepositoryProvider.createBranch'
      });
    }
    const branch: BranchSummary = { name: request.newBranchName, commitSha: request.sourceCommitSha, protected: false };
    branches.push(branch);
    this.branchesByRepository.set(repositoryKey(request.repository), branches);
    const sourceFiles = this.getFiles(request.repository, request.sourceBranch);
    const copiedFiles = sourceFiles.map((file: RemoteFileContent) => {
      const copy: RemoteFileContent = {
        repository: file.repository,
        branch: request.newBranchName,
        path: file.path,
        commitSha: file.commitSha,
        content: file.content,
        encoding: file.encoding,
        size: file.size,
        contentHash: file.contentHash
      };
      return copy;
    });
    this.filesByRepositoryBranch.set(repositoryBranchKey(request.repository, request.newBranchName), copiedFiles);
    return branch;
  }

  public async commitChanges(_auth: RepositoryAuthContext, request: CommitChangesRequest): Promise<CommitResult> {
    const files = this.getFiles(request.repository, request.branch);
    request.changes.forEach((change: FileChange) => this.applyChange(files, request.repository, request.branch, request.baseCommitSha, change));
    this.filesByRepositoryBranch.set(repositoryBranchKey(request.repository, request.branch), files);
    return {
      repository: request.repository,
      branch: request.branch,
      commitSha: `mock-${Date.now()}`,
      webUrl: `${request.repository.fullName}/commit/mock`
    };
  }

  public async createPullOrMergeRequest(_auth: RepositoryAuthContext, draft: ReviewRequestDraft): Promise<ReviewRequest> {
    const requests = this.reviewRequestsByRepository.get(repositoryKey(draft.repository)) || [];
    const reviewRequest: ReviewRequest = {
      id: `mock-pr-${requests.length + 1}`,
      provider: draft.repository.provider,
      repository: draft.repository,
      sourceBranch: draft.sourceBranch,
      targetBranch: draft.targetBranch,
      title: draft.title,
      body: draft.body,
      state: draft.draft ? ReviewRequestState.Draft : ReviewRequestState.Open,
      number: requests.length + 1,
      webUrl: `${draft.repository.fullName}/pull/${requests.length + 1}`
    };
    requests.push(reviewRequest);
    this.reviewRequestsByRepository.set(repositoryKey(draft.repository), requests);
    return reviewRequest;
  }

  public async listIssues(_auth: RepositoryAuthContext, repository: RepositorySummary): Promise<PaginatedResult<IssueSummary>> {
    return { items: this.issuesByRepository.get(repositoryKey(repository.ref)) || [], nextCursor: undefined };
  }

  public async listPullOrMergeRequests(_auth: RepositoryAuthContext, repository: RepositorySummary): Promise<PaginatedResult<ReviewRequest>> {
    return { items: this.reviewRequestsByRepository.get(repositoryKey(repository.ref)) || [], nextCursor: undefined };
  }

  private applyChange(files: RemoteFileContent[], repository: RepositoryRef, branch: BranchName, commitSha: string, change: FileChange): void {
    const existingIndex = files.findIndex((file: RemoteFileContent) => file.path === change.path);
    if (change.kind === FileChangeKind.Deleted) {
      if (existingIndex >= 0) {
        files.splice(existingIndex, 1);
      }
      return;
    }
    const content = change.content || '';
    const updatedFile: RemoteFileContent = {
      repository,
      branch,
      path: change.path,
      commitSha,
      content,
      encoding: 'utf8',
      size: content.length,
      contentHash: `${commitSha}:${change.path}`
    };
    if (existingIndex >= 0) {
      files[existingIndex] = updatedFile;
    } else {
      files.push(updatedFile);
    }
  }

  private getBranches(repository: RepositoryRef): BranchSummary[] {
    const branches = this.branchesByRepository.get(repositoryKey(repository));
    if (!branches) {
      throw new RepositoryException({
        code: RepositoryErrorCode.NotFound,
        message: `Repository branches not found: ${repository.fullName}`,
        provider: repository.provider,
        operation: 'MockRepositoryProvider.getBranches'
      });
    }
    return branches;
  }

  private getFiles(repository: RepositoryRef, branch: BranchName): RemoteFileContent[] {
    return this.filesByRepositoryBranch.get(repositoryBranchKey(repository, branch)) || [];
  }

  private ensureDefaultRepositoryData(): void {
    this.repositories.forEach((repository: RepositorySummary) => {
      const key = repositoryKey(repository.ref);
      if (!this.branchesByRepository.has(key)) {
        this.branchesByRepository.set(key, [{ name: repository.defaultBranch, commitSha: 'mock-root', protected: false }]);
      }
      const branchKey = repositoryBranchKey(repository.ref, repository.defaultBranch);
      if (!this.filesByRepositoryBranch.has(branchKey)) {
        this.filesByRepositoryBranch.set(branchKey, [createDefaultFile(repository.ref, repository.defaultBranch)]);
      }
      if (!this.issuesByRepository.has(key)) {
        this.issuesByRepository.set(key, []);
      }
      if (!this.reviewRequestsByRepository.has(key)) {
        this.reviewRequestsByRepository.set(key, []);
      }
    });
  }

  private seedMap<T>(target: Map<string, T>, source?: Record<string, T>): void {
    if (!source) {
      return;
    }
    Object.keys(source).forEach((key: string) => target.set(key, source[key]));
  }
}

function createDefaultAccount(): RepositoryAccount {
  return {
    id: 'mock-account',
    provider: RepositoryProviderKind.GitHub,
    login: 'claude-coca',
    displayName: 'Claude Coca'
  };
}

function createDefaultRepository(): RepositorySummary {
  const ref: RepositoryRef = {
    provider: RepositoryProviderKind.GitHub,
    id: 'mock-repo',
    owner: 'claude-coca',
    name: 'demo',
    fullName: 'claude-coca/demo'
  };
  return {
    ref,
    owner: { id: 'mock-account', login: 'claude-coca', displayName: 'Claude Coca' },
    defaultBranch: 'main',
    visibility: RepositoryVisibility.Private,
    description: 'Mock repository for Claude Coca repository workflows.',
    webUrl: 'mock://github/claude-coca/demo',
    cloneUrl: 'mock://github/claude-coca/demo.git',
    language: 'ArkTS',
    updatedAt: Date.now(),
    archived: false,
    fork: false
  };
}

function createDefaultFile(repository: RepositoryRef, branch: BranchName): RemoteFileContent {
  const content = '# Claude Coca Demo\n\nThis mock file is available before live provider wiring.\n';
  return {
    repository,
    branch,
    path: 'README.md',
    commitSha: 'mock-root',
    content,
    encoding: 'utf8',
    size: content.length,
    contentHash: 'mock-root:README.md'
  };
}

function repositoryKey(repository: RepositoryRef): string {
  return `${repository.provider}:${repository.fullName}`;
}

function repositoryBranchKey(repository: RepositoryRef, branch: BranchName): string {
  return `${repositoryKey(repository)}#${branch}`;
}

function basename(path: RemoteFilePath): string {
  const separatorIndex = path.lastIndexOf('/');
  return separatorIndex >= 0 ? path.substring(separatorIndex + 1) : path;
}
