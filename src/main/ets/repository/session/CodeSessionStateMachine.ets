import {
  BranchName,
  CodeSessionId,
  CommitSha,
  FileChange,
  RemoteFilePath,
  RepositoryProviderKind,
  RepositoryRef,
  ReviewRequest
} from '../domain/RepositoryTypes';
import { RepositoryErrorDetails } from '../domain/RepositoryErrors';

export enum CodeSessionStatus {
  Unconnected = 'unconnected',
  ProviderConnected = 'providerConnected',
  RepoSelected = 'repoSelected',
  BranchSelected = 'branchSelected',
  ContextLoaded = 'contextLoaded',
  EditingPlan = 'editingPlan',
  ReviewingDiff = 'reviewingDiff',
  Committing = 'committing',
  ReviewRequestCreating = 'reviewRequestCreating',
  Complete = 'complete',
  Error = 'error'
}

export enum CodeSessionEventType {
  ProviderConnected = 'providerConnected',
  RepositorySelected = 'repositorySelected',
  BranchSelected = 'branchSelected',
  ContextLoaded = 'contextLoaded',
  EditingPlanStarted = 'editingPlanStarted',
  DiffReady = 'diffReady',
  CommitStarted = 'commitStarted',
  ReviewRequestStarted = 'reviewRequestStarted',
  ReviewRequestCreated = 'reviewRequestCreated',
  Failed = 'failed',
  Reset = 'reset'
}

export interface CodeSessionState {
  id: CodeSessionId;
  status: CodeSessionStatus;
  createdAt: number;
  updatedAt: number;
  provider?: RepositoryProviderKind;
  repository?: RepositoryRef;
  branch?: BranchName;
  baseCommitSha?: CommitSha;
  selectedPaths: RemoteFilePath[];
  pendingChanges: FileChange[];
  reviewRequest?: ReviewRequest;
  error?: RepositoryErrorDetails;
}

export interface CodeSessionEvent {
  type: CodeSessionEventType;
  occurredAt: number;
  provider?: RepositoryProviderKind;
  repository?: RepositoryRef;
  branch?: BranchName;
  baseCommitSha?: CommitSha;
  selectedPaths?: RemoteFilePath[];
  pendingChanges?: FileChange[];
  reviewRequest?: ReviewRequest;
  error?: RepositoryErrorDetails;
}

export function createInitialCodeSession(id: CodeSessionId, createdAt: number): CodeSessionState {
  return {
    id,
    status: CodeSessionStatus.Unconnected,
    createdAt,
    updatedAt: createdAt,
    selectedPaths: [],
    pendingChanges: []
  };
}

export function reduceCodeSessionState(state: CodeSessionState, event: CodeSessionEvent): CodeSessionState {
  switch (event.type) {
    case CodeSessionEventType.ProviderConnected:
      return { ...state, status: CodeSessionStatus.ProviderConnected, provider: event.provider, updatedAt: event.occurredAt, error: undefined };
    case CodeSessionEventType.RepositorySelected:
      return { ...state, status: CodeSessionStatus.RepoSelected, repository: event.repository, updatedAt: event.occurredAt, error: undefined };
    case CodeSessionEventType.BranchSelected:
      return { ...state, status: CodeSessionStatus.BranchSelected, branch: event.branch, baseCommitSha: event.baseCommitSha, updatedAt: event.occurredAt, error: undefined };
    case CodeSessionEventType.ContextLoaded:
      return { ...state, status: CodeSessionStatus.ContextLoaded, selectedPaths: event.selectedPaths || [], updatedAt: event.occurredAt, error: undefined };
    case CodeSessionEventType.EditingPlanStarted:
      return { ...state, status: CodeSessionStatus.EditingPlan, updatedAt: event.occurredAt, error: undefined };
    case CodeSessionEventType.DiffReady:
      return { ...state, status: CodeSessionStatus.ReviewingDiff, pendingChanges: event.pendingChanges || [], updatedAt: event.occurredAt, error: undefined };
    case CodeSessionEventType.CommitStarted:
      return { ...state, status: CodeSessionStatus.Committing, updatedAt: event.occurredAt, error: undefined };
    case CodeSessionEventType.ReviewRequestStarted:
      return { ...state, status: CodeSessionStatus.ReviewRequestCreating, updatedAt: event.occurredAt, error: undefined };
    case CodeSessionEventType.ReviewRequestCreated:
      return { ...state, status: CodeSessionStatus.Complete, reviewRequest: event.reviewRequest, updatedAt: event.occurredAt, error: undefined };
    case CodeSessionEventType.Failed:
      return { ...state, status: CodeSessionStatus.Error, error: event.error, updatedAt: event.occurredAt };
    case CodeSessionEventType.Reset:
      return createInitialCodeSession(state.id, event.occurredAt);
    default:
      return state;
  }
}
