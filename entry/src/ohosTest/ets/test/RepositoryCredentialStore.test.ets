import { describe, it, expect } from '@ohos/hypium';
import {
  RepositoryCredentialKind,
  RepositoryProviderKind
} from '../../../main/ets/repository/domain/RepositoryTypes';
import {
  InMemoryRepositoryCredentialStore
} from '../../../main/ets/security/RepositoryCredentialStore';

/**
 * Round-trip behaviour for the in-memory credential store. The same
 * lifecycle expectations are intended to hold for any future Asset Store
 * Kit-backed implementation.
 */
export default function repositoryCredentialStoreTest() {
  describe('InMemoryRepositoryCredentialStore', () => {
    it('stores and reads back the active OAuth credential per provider', 0, async () => {
      const store = new InMemoryRepositoryCredentialStore();
      const stored = await store.saveOAuthToken({
        provider: RepositoryProviderKind.GitHub,
        accessToken: 'gho_xyz',
        scopes: ['repo'],
        accountLogin: 'octocat'
      });

      expect(stored.credential.provider).assertEqual(RepositoryProviderKind.GitHub);
      expect(stored.credential.kind).assertEqual(RepositoryCredentialKind.OAuthToken);
      expect(stored.accessToken).assertEqual('gho_xyz');

      const active = await store.readActiveCredential(RepositoryProviderKind.GitHub);
      expect(active !== undefined).assertTrue();
      expect(active!.accessToken).assertEqual('gho_xyz');
    });

    it('replaces the previous active credential when a new token is saved for the same provider', 0, async () => {
      const store = new InMemoryRepositoryCredentialStore();
      const first = await store.saveOAuthToken({
        provider: RepositoryProviderKind.GitHub,
        accessToken: 'first',
        scopes: ['repo']
      });
      await store.saveOAuthToken({
        provider: RepositoryProviderKind.GitHub,
        accessToken: 'second',
        scopes: ['repo']
      });

      const active = await store.readActiveCredential(RepositoryProviderKind.GitHub);
      expect(active!.accessToken).assertEqual('second');
      // Old credential is no longer resolvable.
      const oldCtx = await store.resolveAuthContext(first.credential.id);
      expect(oldCtx).assertEqual(undefined);
    });

    it('keeps providers isolated', 0, async () => {
      const store = new InMemoryRepositoryCredentialStore();
      await store.saveOAuthToken({
        provider: RepositoryProviderKind.GitHub,
        accessToken: 'gh-token',
        scopes: ['repo']
      });
      await store.saveOAuthToken({
        provider: RepositoryProviderKind.Gitee,
        accessToken: 'ge-token',
        scopes: ['user_info']
      });

      const gh = await store.readActiveCredential(RepositoryProviderKind.GitHub);
      const ge = await store.readActiveCredential(RepositoryProviderKind.Gitee);
      expect(gh!.accessToken).assertEqual('gh-token');
      expect(ge!.accessToken).assertEqual('ge-token');
    });

    it('clearProvider removes the active credential', 0, async () => {
      const store = new InMemoryRepositoryCredentialStore();
      await store.saveOAuthToken({
        provider: RepositoryProviderKind.GitHub,
        accessToken: 'gho_xyz',
        scopes: ['repo']
      });
      await store.clearProvider(RepositoryProviderKind.GitHub);
      const active = await store.readActiveCredential(RepositoryProviderKind.GitHub);
      expect(active).assertEqual(undefined);
    });

    it('resolveAuthContext returns the bearer token for a known credential id', 0, async () => {
      const store = new InMemoryRepositoryCredentialStore();
      const stored = await store.saveOAuthToken({
        provider: RepositoryProviderKind.GitHub,
        accessToken: 'gho_xyz',
        scopes: ['repo']
      });

      const ctx = await store.resolveAuthContext(stored.credential.id);
      expect(ctx !== undefined).assertTrue();
      expect(ctx!.accessToken).assertEqual('gho_xyz');
      expect(ctx!.credential.kind).assertEqual(RepositoryCredentialKind.OAuthToken);
    });
  });
}
