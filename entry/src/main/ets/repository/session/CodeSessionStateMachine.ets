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

function cloneCodeSessionState(state: CodeSessionState): CodeSessionState {
  const copy: CodeSessionState = {
    id: state.id,
    status: state.status,
    createdAt: state.createdAt,
    updatedAt: state.updatedAt,
    provider: state.provider,
    repository: state.repository,
    branch: state.branch,
    baseCommitSha: state.baseCommitSha,
    selectedPaths: state.selectedPaths,
    pendingChanges: state.pendingChanges,
    reviewRequest: state.reviewRequest,
    error: state.error
  };
  return copy;
}

export function reduceCodeSessionState(state: CodeSessionState, event: CodeSessionEvent): CodeSessionState {
  switch (event.type) {
    case CodeSessionEventType.ProviderConnected: {
      const next = cloneCodeSessionState(state);
      next.status = CodeSessionStatus.ProviderConnected;
      next.provider = event.provider;
      next.updatedAt = event.occurredAt;
      next.error = undefined;
      return next;
    }
    case CodeSessionEventType.RepositorySelected: {
      const next = cloneCodeSessionState(state);
      next.status = CodeSessionStatus.RepoSelected;
      next.repository = event.repository;
      next.updatedAt = event.occurredAt;
      next.error = undefined;
      return next;
    }
    case CodeSessionEventType.BranchSelected: {
      const next = cloneCodeSessionState(state);
      next.status = CodeSessionStatus.BranchSelected;
      next.branch = event.branch;
      next.baseCommitSha = event.baseCommitSha;
      next.updatedAt = event.occurredAt;
      next.error = undefined;
      return next;
    }
    case CodeSessionEventType.ContextLoaded: {
      const next = cloneCodeSessionState(state);
      next.status = CodeSessionStatus.ContextLoaded;
      next.selectedPaths = event.selectedPaths || [];
      next.updatedAt = event.occurredAt;
      next.error = undefined;
      return next;
    }
    case CodeSessionEventType.EditingPlanStarted: {
      const next = cloneCodeSessionState(state);
      next.status = CodeSessionStatus.EditingPlan;
      next.updatedAt = event.occurredAt;
      next.error = undefined;
      return next;
    }
    case CodeSessionEventType.DiffReady: {
      const next = cloneCodeSessionState(state);
      next.status = CodeSessionStatus.ReviewingDiff;
      next.pendingChanges = event.pendingChanges || [];
      next.updatedAt = event.occurredAt;
      next.error = undefined;
      return next;
    }
    case CodeSessionEventType.CommitStarted: {
      const next = cloneCodeSessionState(state);
      next.status = CodeSessionStatus.Committing;
      next.updatedAt = event.occurredAt;
      next.error = undefined;
      return next;
    }
    case CodeSessionEventType.ReviewRequestStarted: {
      const next = cloneCodeSessionState(state);
      next.status = CodeSessionStatus.ReviewRequestCreating;
      next.updatedAt = event.occurredAt;
      next.error = undefined;
      return next;
    }
    case CodeSessionEventType.ReviewRequestCreated: {
      const next = cloneCodeSessionState(state);
      next.status = CodeSessionStatus.Complete;
      next.reviewRequest = event.reviewRequest;
      next.updatedAt = event.occurredAt;
      next.error = undefined;
      return next;
    }
    case CodeSessionEventType.Failed: {
      const next = cloneCodeSessionState(state);
      next.status = CodeSessionStatus.Error;
      next.error = event.error;
      next.updatedAt = event.occurredAt;
      return next;
    }
    case CodeSessionEventType.Reset:
      return createInitialCodeSession(state.id, event.occurredAt);
    default:
      return state;
  }
}
