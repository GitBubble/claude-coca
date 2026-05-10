import { RepositoryProviderKind } from './RepositoryTypes';

export enum RepositoryErrorCode {
  Unknown = 'unknown',
  NotAuthenticated = 'notAuthenticated',
  InvalidCredential = 'invalidCredential',
  MissingScope = 'missingScope',
  RateLimited = 'rateLimited',
  Forbidden = 'forbidden',
  NotFound = 'notFound',
  Conflict = 'conflict',
  BranchProtected = 'branchProtected',
  LargeFile = 'largeFile',
  BinaryFile = 'binaryFile',
  NetworkUnavailable = 'networkUnavailable',
  UnsupportedCapability = 'unsupportedCapability',
  ProviderUnavailable = 'providerUnavailable'
}

export interface RepositoryErrorDetails {
  code: RepositoryErrorCode;
  message: string;
  provider?: RepositoryProviderKind;
  retryAfterMs?: number;
  statusCode?: number;
  operation?: string;
}

export class RepositoryException extends Error {
  public readonly code: RepositoryErrorCode;
  public readonly provider?: RepositoryProviderKind;
  public readonly retryAfterMs?: number;
  public readonly statusCode?: number;
  public readonly operation?: string;

  public constructor(details: RepositoryErrorDetails) {
    super(details.message);
    this.name = 'RepositoryException';
    this.code = details.code;
    this.provider = details.provider;
    this.retryAfterMs = details.retryAfterMs;
    this.statusCode = details.statusCode;
    this.operation = details.operation;
  }
}

export function isRetryableRepositoryError(code: RepositoryErrorCode): boolean {
  return code === RepositoryErrorCode.RateLimited ||
    code === RepositoryErrorCode.NetworkUnavailable ||
    code === RepositoryErrorCode.ProviderUnavailable;
}

export function repositoryErrorFromHttpStatus(statusCode: number, message: string, operation: string, provider?: RepositoryProviderKind): RepositoryException {
  if (statusCode === 401) {
    return new RepositoryException({ code: RepositoryErrorCode.InvalidCredential, message, provider, statusCode, operation });
  }
  if (statusCode === 403) {
    return new RepositoryException({ code: RepositoryErrorCode.Forbidden, message, provider, statusCode, operation });
  }
  if (statusCode === 404) {
    return new RepositoryException({ code: RepositoryErrorCode.NotFound, message, provider, statusCode, operation });
  }
  if (statusCode === 409 || statusCode === 412) {
    return new RepositoryException({ code: RepositoryErrorCode.Conflict, message, provider, statusCode, operation });
  }
  if (statusCode === 429) {
    return new RepositoryException({ code: RepositoryErrorCode.RateLimited, message, provider, statusCode, operation });
  }
  return new RepositoryException({ code: RepositoryErrorCode.Unknown, message, provider, statusCode, operation });
}

export function redactSecret(value: string): string {
  if (value.length <= 8) {
    return '***';
  }
  return `${value.substring(0, 4)}...${value.substring(value.length - 4)}`;
}
