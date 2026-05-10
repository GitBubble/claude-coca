import {
  MockRepositoryProvider,
  RepositoryProviderRegistry
} from '../repository';
import {
  InMemoryModelCredentialStore,
  MockModelProvider,
  ModelCredentialStore,
  ModelProviderRegistry,
  OpenAICompatibleProvider
} from '../models';
import { AppSettingsStore } from '../settings/AppSettingsStore';

export interface AppServices {
  repositoryProviderRegistry: RepositoryProviderRegistry;
  modelProviderRegistry: ModelProviderRegistry;
  modelCredentialStore: ModelCredentialStore;
  settingsStore: AppSettingsStore;
}

export function createAppServices(): AppServices {
  const repositoryProviderRegistry = new RepositoryProviderRegistry();
  repositoryProviderRegistry.register(new MockRepositoryProvider());

  const modelProviderRegistry = new ModelProviderRegistry();
  modelProviderRegistry.register(new MockModelProvider());
  modelProviderRegistry.register(new OpenAICompatibleProvider());

  return {
    repositoryProviderRegistry,
    modelProviderRegistry,
    modelCredentialStore: new InMemoryModelCredentialStore(),
    settingsStore: new AppSettingsStore()
  };
}

let sharedServices: AppServices | undefined = undefined;

export function getAppServices(): AppServices {
  if (!sharedServices) {
    sharedServices = createAppServices();
  }
  return sharedServices;
}