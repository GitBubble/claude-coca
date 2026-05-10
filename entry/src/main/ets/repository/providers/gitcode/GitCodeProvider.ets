import { RepositoryProvider } from '../RepositoryProvider';
import { RepositoryErrorCode, RepositoryException } from '../../domain/RepositoryErrors';

export function createGitCodeProviderPlaceholder(): RepositoryProvider {
  throw new RepositoryException({
    code: RepositoryErrorCode.UnsupportedCapability,
    message: 'GitCodeProvider is planned after the GitHub provider contract is validated.',
    operation: 'createGitCodeProviderPlaceholder'
  });
}
