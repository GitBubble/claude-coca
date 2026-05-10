import { ModelProviderKind } from '../domain/ModelTypes';

export interface ModelCredentialStore {
  saveApiKey(provider: ModelProviderKind, apiKey: string): Promise<void>;
  readApiKey(provider: ModelProviderKind): Promise<string | undefined>;
  deleteApiKey(provider: ModelProviderKind): Promise<void>;
}

export class InMemoryModelCredentialStore implements ModelCredentialStore {
  private readonly apiKeys: Map<ModelProviderKind, string> = new Map();

  public async saveApiKey(provider: ModelProviderKind, apiKey: string): Promise<void> {
    this.apiKeys.set(provider, apiKey);
  }

  public async readApiKey(provider: ModelProviderKind): Promise<string | undefined> {
    return this.apiKeys.get(provider);
  }

  public async deleteApiKey(provider: ModelProviderKind): Promise<void> {
    this.apiKeys.delete(provider);
  }
}