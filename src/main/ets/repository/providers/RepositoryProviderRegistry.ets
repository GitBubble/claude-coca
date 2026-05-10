import { RepositoryProviderKind } from '../domain/RepositoryTypes';
import { RepositoryErrorCode, RepositoryException } from '../domain/RepositoryErrors';
import { RepositoryProvider } from './RepositoryProvider';

export class RepositoryProviderRegistry {
  private readonly providers: Map<RepositoryProviderKind, RepositoryProvider> = new Map();

  public register(provider: RepositoryProvider): void {
    this.providers.set(provider.getMetadata().kind, provider);
  }

  public has(kind: RepositoryProviderKind): boolean {
    return this.providers.has(kind);
  }

  public list(): RepositoryProvider[] {
    return Array.from(this.providers.values());
  }

  public require(kind: RepositoryProviderKind): RepositoryProvider {
    const provider = this.providers.get(kind);
    if (!provider) {
      throw new RepositoryException({
        code: RepositoryErrorCode.UnsupportedCapability,
        message: `Repository provider is not registered: ${kind}`,
        provider: kind,
        operation: 'RepositoryProviderRegistry.require'
      });
    }
    return provider;
  }
}
