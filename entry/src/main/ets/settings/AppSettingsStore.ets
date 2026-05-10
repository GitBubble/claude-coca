import { RepositoryProviderKind } from '../repository';
import { ModelProviderKind } from '../models';

export enum AppThemeMode {
  System = 'system',
  Light = 'light',
  Dark = 'dark'
}

export interface AppSettings {
  themeMode: AppThemeMode;
  defaultModelProvider: ModelProviderKind;
  defaultModelId: string;
  repositoryProvider: RepositoryProviderKind;
  streamResponses: boolean;
  updatedAt: number;
}

export const DEFAULT_APP_SETTINGS: AppSettings = {
  themeMode: AppThemeMode.System,
  defaultModelProvider: ModelProviderKind.Mock,
  defaultModelId: 'mock-claude-coca-v1',
  repositoryProvider: RepositoryProviderKind.GitHub,
  streamResponses: true,
  updatedAt: 0
};

export interface AppSettingsPatch {
  themeMode?: AppThemeMode;
  defaultModelProvider?: ModelProviderKind;
  defaultModelId?: string;
  repositoryProvider?: RepositoryProviderKind;
  streamResponses?: boolean;
}

function cloneAppSettings(source: AppSettings): AppSettings {
  const copy: AppSettings = {
    themeMode: source.themeMode,
    defaultModelProvider: source.defaultModelProvider,
    defaultModelId: source.defaultModelId,
    repositoryProvider: source.repositoryProvider,
    streamResponses: source.streamResponses,
    updatedAt: source.updatedAt
  };
  return copy;
}

export class AppSettingsStore {
  private settings: AppSettings = cloneAppSettings(DEFAULT_APP_SETTINGS);

  public getSnapshot(): AppSettings {
    return cloneAppSettings(this.settings);
  }

  public update(patch: AppSettingsPatch): AppSettings {
    if (patch.themeMode !== undefined) {
      this.settings.themeMode = patch.themeMode;
    }
    if (patch.defaultModelProvider !== undefined) {
      this.settings.defaultModelProvider = patch.defaultModelProvider;
    }
    if (patch.defaultModelId !== undefined) {
      this.settings.defaultModelId = patch.defaultModelId;
    }
    if (patch.repositoryProvider !== undefined) {
      this.settings.repositoryProvider = patch.repositoryProvider;
    }
    if (patch.streamResponses !== undefined) {
      this.settings.streamResponses = patch.streamResponses;
    }
    this.settings.updatedAt = Date.now();
    return this.getSnapshot();
  }

  public reset(): AppSettings {
    this.settings = cloneAppSettings(DEFAULT_APP_SETTINGS);
    this.settings.updatedAt = Date.now();
    return this.getSnapshot();
  }
}