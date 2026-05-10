import { RepositoryProviderKind } from '../repository';
import { ModelProviderKind } from '../models';

export enum AppThemeMode {
  System = 'system',
  Light = 'light',
  Dark = 'dark'
}

export enum AppFontStyle {
  Compact = 'compact',
  Standard = 'standard',
  Comfortable = 'comfortable',
  Large = 'large'
}

export enum AppLanguage {
  System = 'system',
  English = 'en-US',
  ChineseSimplified = 'zh-CN',
  ChineseTraditional = 'zh-TW',
  Japanese = 'ja-JP'
}

export interface AppSettings {
  themeMode: AppThemeMode;
  defaultModelProvider: ModelProviderKind;
  defaultModelId: string;
  repositoryProvider: RepositoryProviderKind;
  streamResponses: boolean;
  fontStyle: AppFontStyle;
  language: AppLanguage;
  notificationsEnabled: boolean;
  notifyOnChatComplete: boolean;
  notifyOnRepositoryUpdates: boolean;
  notifyOnErrors: boolean;
  updatedAt: number;
}

export const DEFAULT_APP_SETTINGS: AppSettings = {
  themeMode: AppThemeMode.System,
  defaultModelProvider: ModelProviderKind.Mock,
  defaultModelId: 'mock-claude-coca-v1',
  repositoryProvider: RepositoryProviderKind.GitHub,
  streamResponses: true,
  fontStyle: AppFontStyle.Standard,
  language: AppLanguage.System,
  notificationsEnabled: true,
  notifyOnChatComplete: true,
  notifyOnRepositoryUpdates: false,
  notifyOnErrors: true,
  updatedAt: 0
};

export interface AppSettingsPatch {
  themeMode?: AppThemeMode;
  defaultModelProvider?: ModelProviderKind;
  defaultModelId?: string;
  repositoryProvider?: RepositoryProviderKind;
  streamResponses?: boolean;
  fontStyle?: AppFontStyle;
  language?: AppLanguage;
  notificationsEnabled?: boolean;
  notifyOnChatComplete?: boolean;
  notifyOnRepositoryUpdates?: boolean;
  notifyOnErrors?: boolean;
}

function cloneAppSettings(source: AppSettings): AppSettings {
  const copy: AppSettings = {
    themeMode: source.themeMode,
    defaultModelProvider: source.defaultModelProvider,
    defaultModelId: source.defaultModelId,
    repositoryProvider: source.repositoryProvider,
    streamResponses: source.streamResponses,
    fontStyle: source.fontStyle,
    language: source.language,
    notificationsEnabled: source.notificationsEnabled,
    notifyOnChatComplete: source.notifyOnChatComplete,
    notifyOnRepositoryUpdates: source.notifyOnRepositoryUpdates,
    notifyOnErrors: source.notifyOnErrors,
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
    if (patch.fontStyle !== undefined) {
      this.settings.fontStyle = patch.fontStyle;
    }
    if (patch.language !== undefined) {
      this.settings.language = patch.language;
    }
    if (patch.notificationsEnabled !== undefined) {
      this.settings.notificationsEnabled = patch.notificationsEnabled;
    }
    if (patch.notifyOnChatComplete !== undefined) {
      this.settings.notifyOnChatComplete = patch.notifyOnChatComplete;
    }
    if (patch.notifyOnRepositoryUpdates !== undefined) {
      this.settings.notifyOnRepositoryUpdates = patch.notifyOnRepositoryUpdates;
    }
    if (patch.notifyOnErrors !== undefined) {
      this.settings.notifyOnErrors = patch.notifyOnErrors;
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