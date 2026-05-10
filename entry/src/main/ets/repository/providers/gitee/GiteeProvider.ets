import { RepositoryProvider } from '../RepositoryProvider';
import { RepositoryErrorCode, RepositoryException } from '../../domain/RepositoryErrors';

export function createGiteeProviderPlaceholder(): RepositoryProvider {
  throw new RepositoryException({
    code: RepositoryErrorCode.UnsupportedCapability,
    message: 'GiteeProvider is planned after the GitHub provider contract is validated.',
    operation: 'createGiteeProviderPlaceholder'
  });
}
