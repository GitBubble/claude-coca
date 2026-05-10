import { ModelErrorCode, ModelException } from '../domain/ModelErrors';
import { ModelProviderKind } from '../domain/ModelTypes';
import { ModelProvider } from './ModelProvider';

export class ModelProviderRegistry {
  private readonly providers: Map<ModelProviderKind, ModelProvider> = new Map();

  public register(provider: ModelProvider): void {
    this.providers.set(provider.getMetadata().kind, provider);
  }

  public list(): ModelProvider[] {
    return Array.from(this.providers.values());
  }

  public require(kind: ModelProviderKind): ModelProvider {
    const provider = this.providers.get(kind);
    if (!provider) {
      throw new ModelException({
        code: ModelErrorCode.UnsupportedModel,
        message: `Model provider is not registered: ${kind}`,
        provider: kind
      });
    }
    return provider;
  }
}