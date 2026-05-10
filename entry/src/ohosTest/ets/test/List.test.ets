import oauthParsingTest from './OAuthParsing.test';
import oauthServiceTest from './OAuthService.test';
import repositoryCredentialStoreTest from './RepositoryCredentialStore.test';

export default function testsuite() {
  oauthParsingTest();
  oauthServiceTest();
  repositoryCredentialStoreTest();
}
