import { ModelProviderKind } from './ModelTypes';

export enum ModelErrorCode {
  Unknown = 'unknown',
  InvalidApiKey = 'invalidApiKey',
  NetworkFailure = 'networkFailure',
  RateLimited = 'rateLimited',
  UnsupportedModel = 'unsupportedModel',
  Cancelled = 'cancelled',
  InvalidRequest = 'invalidRequest'
}

export interface ModelErrorDetails {
  code: ModelErrorCode;
  message: string;
  provider?: ModelProviderKind;
  statusCode?: number;
  retryAfterMs?: number;
}

export class ModelException extends Error {
  public readonly code: ModelErrorCode;
  public readonly provider?: ModelProviderKind;
  public readonly statusCode?: number;
  public readonly retryAfterMs?: number;

  public constructor(details: ModelErrorDetails) {
    super(details.message);
    this.name = 'ModelException';
    this.code = details.code;
    this.provider = details.provider;
    this.statusCode = details.statusCode;
    this.retryAfterMs = details.retryAfterMs;
  }
}

export function isRetryableModelError(code: ModelErrorCode): boolean {
  return code === ModelErrorCode.NetworkFailure || code === ModelErrorCode.RateLimited;
}