import { router } from '@kit.ArkUI';
import { RepositoryProviderKind } from '../repository';
import { ModelProviderKind } from '../models';
import { AppServices, getAppServices } from '../app/AppServices';
import {
  AppFontStyle,
  AppLanguage,
  AppSettings,
  AppSettingsPatch,
  AppThemeMode
} from '../settings/AppSettingsStore';

interface SettingsTab {
  id: string;
  title: string;
  eyebrow: string;
}

const SETTINGS_TABS: SettingsTab[] = [
  { id: 'capability', title: 'Capability', eyebrow: 'Features & limits' },
  { id: 'profile', title: 'Profile', eyebrow: 'Account & identity' },
  { id: 'connector', title: 'Connector', eyebrow: 'Repositories & models' },
  { id: 'colorMode', title: 'Color Mode', eyebrow: 'Theme appearance' },
  { id: 'fontStyle', title: 'Font Style', eyebrow: 'Typography & density' },
  { id: 'languages', title: 'Languages', eyebrow: 'Locale preference' },
  { id: 'notifications', title: 'Notifications', eyebrow: 'Alerts & sounds' }
];

interface ThemeOption {
  value: AppThemeMode;
  title: string;
  subtitle: string;
}

interface FontOption {
  value: AppFontStyle;
  title: string;
  subtitle: string;
}

interface LanguageOption {
  value: AppLanguage;
  title: string;
  subtitle: string;
}

interface RepositoryOption {
  value: RepositoryProviderKind;
  title: string;
  subtitle: string;
}

interface ModelOption {
  value: ModelProviderKind;
  title: string;
  subtitle: string;
}

const THEME_OPTIONS: ThemeOption[] = [
  { value: AppThemeMode.System, title: 'Follow system', subtitle: 'Match the device color mode' },
  { value: AppThemeMode.Light, title: 'Light', subtitle: 'Bright surfaces, dark text' },
  { value: AppThemeMode.Dark, title: 'Dark', subtitle: 'Low-light optimized palette' }
];

const FONT_OPTIONS: FontOption[] = [
  { value: AppFontStyle.Compact, title: 'Compact', subtitle: 'Smaller type, denser layout' },
  { value: AppFontStyle.Standard, title: 'Standard', subtitle: 'Default Claude Coca typography' },
  { value: AppFontStyle.Comfortable, title: 'Comfortable', subtitle: 'Slightly larger, more spacing' },
  { value: AppFontStyle.Large, title: 'Large', subtitle: 'Accessibility-friendly large text' }
];

const LANGUAGE_OPTIONS: LanguageOption[] = [
  { value: AppLanguage.System, title: 'System default', subtitle: 'Use device locale' },
  { value: AppLanguage.English, title: 'English', subtitle: 'en-US' },
  { value: AppLanguage.ChineseSimplified, title: '简体中文', subtitle: 'zh-CN' },
  { value: AppLanguage.ChineseTraditional, title: '繁體中文', subtitle: 'zh-TW' },
  { value: AppLanguage.Japanese, title: '日本語', subtitle: 'ja-JP' }
];

const REPOSITORY_OPTIONS: RepositoryOption[] = [
  { value: RepositoryProviderKind.GitHub, title: 'GitHub', subtitle: 'github.com' },
  { value: RepositoryProviderKind.GitCode, title: 'GitCode', subtitle: 'gitcode.com' },
  { value: RepositoryProviderKind.Gitee, title: 'Gitee', subtitle: 'gitee.com' }
];

const MODEL_OPTIONS: ModelOption[] = [
  { value: ModelProviderKind.Mock, title: 'Mock Local', subtitle: 'Offline simulator' },
  { value: ModelProviderKind.OpenAICompatible, title: 'OpenAI Compatible', subtitle: 'OpenAI / compatible endpoints' }
];

@Entry
@Component
struct Settings {
  @State private selectedTabIndex: number = 0;
  @State private settings: AppSettings = getAppServices().settingsStore.getSnapshot();

  private readonly services: AppServices = getAppServices();

  aboutToAppear(): void {
    this.refreshSettings();
  }

  private refreshSettings(): void {
    this.settings = this.services.settingsStore.getSnapshot();
  }

  private updateSettings(patch: AppSettingsPatch): void {
    this.services.settingsStore.update(patch);
    this.refreshSettings();
  }

  build() {
    Row() {
      Column() {
        this.SidebarHeader();
        this.TabList();
      }
      .width(220)
      .height('100%')
      .padding({ left: 16, right: 12, top: 20, bottom: 20 })
      .backgroundColor('#F4F0E8')

      Column() {
        this.TopBar();
        Divider().color('#D9D6CC')
        Scroll() {
          Column() {
            this.CurrentTab();
          }
          .width('100%')
          .padding(24)
          .alignItems(HorizontalAlign.Start)
        }
        .layoutWeight(1)
      }
      .layoutWeight(1)
      .height('100%')
      .backgroundColor('#FAFAF6')
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  private SidebarHeader() {
    Column() {
      Text('Settings')
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .fontColor('#1D2D2C')
      Text('Tune Claude Coca')
        .fontSize(12)
        .fontColor('#6F6A5F')
        .margin({ top: 4 })
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
    .margin({ bottom: 24 })
  }

  @Builder
  private TabList() {
    Column({ space: 6 }) {
      ForEach(SETTINGS_TABS, (tab: SettingsTab, index: number) => {
        Column() {
          Text(tab.title)
            .fontSize(15)
            .fontWeight(this.selectedTabIndex === index ? FontWeight.Bold : FontWeight.Medium)
            .fontColor(this.selectedTabIndex === index ? '#FFFFFF' : '#223231')
          Text(tab.eyebrow)
            .fontSize(11)
            .fontColor(this.selectedTabIndex === index ? '#D8F2EE' : '#716B62')
            .margin({ top: 3 })
        }
        .alignItems(HorizontalAlign.Start)
        .width('100%')
        .padding({ left: 12, right: 12, top: 10, bottom: 10 })
        .borderRadius(8)
        .backgroundColor(this.selectedTabIndex === index ? '#245B57' : '#00000000')
        .onClick(() => {
          this.selectedTabIndex = index;
        })
      }, (tab: SettingsTab) => tab.id)
    }
    .width('100%')
  }

  @Builder
  private TopBar() {
    Row() {
      Button('Back')
        .fontSize(13)
        .fontColor('#245B57')
        .backgroundColor('#E7F1EF')
        .borderRadius(8)
        .height(34)
        .onClick(() => {
          router.back();
        })

      Column() {
        Text(SETTINGS_TABS[this.selectedTabIndex].title)
          .fontSize(26)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1D2D2C')
        Text(SETTINGS_TABS[this.selectedTabIndex].eyebrow)
          .fontSize(13)
          .fontColor('#6F6A5F')
          .margin({ top: 4 })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      .margin({ left: 16 })
    }
    .width('100%')
    .padding({ left: 24, right: 24, top: 20, bottom: 18 })
    .backgroundColor('#FAFAF6')
  }

  @Builder
  private CurrentTab() {
    if (this.selectedTabIndex === 0) {
      this.CapabilityTab();
    } else if (this.selectedTabIndex === 1) {
      this.ProfileTab();
    } else if (this.selectedTabIndex === 2) {
      this.ConnectorTab();
    } else if (this.selectedTabIndex === 3) {
      this.ColorModeTab();
    } else if (this.selectedTabIndex === 4) {
      this.FontStyleTab();
    } else if (this.selectedTabIndex === 5) {
      this.LanguagesTab();
    } else {
      this.NotificationsTab();
    }
  }

  @Builder
  private CapabilityTab() {
    Column({ space: 16 }) {
      this.SectionTitle('Conversation', 'Tune how Claude Coca generates responses')
      this.ToggleRow(
        'Stream responses',
        'Show tokens as they arrive from the model',
        this.settings.streamResponses,
        (value: boolean) => {
          this.updateSettings({ streamResponses: value });
        }
      )
      this.InfoRow('Default model provider', this.settings.defaultModelProvider)
      this.InfoRow('Default model id', this.settings.defaultModelId)
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
  }

  @Builder
  private ProfileTab() {
    Column({ space: 16 }) {
      this.SectionTitle('Profile', 'Identity used when calling Git providers')
      this.InfoRow('Display name', 'Claude Coca user')
      this.InfoRow('Account login', 'claude-coca')
      this.InfoRow('Active provider', this.settings.repositoryProvider)
      this.HintCard('Sign in from the welcome screen to populate your real profile via OAuth.')
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
  }

  @Builder
  private ConnectorTab() {
    Column({ space: 20 }) {
      this.SectionTitle('Repository connector', 'Choose which Git platform to use')
      this.RepositoryChoiceList()

      this.SectionTitle('Model connector', 'Pick the default model provider')
      this.ModelChoiceList()
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
  }

  @Builder
  private ColorModeTab() {
    Column({ space: 16 }) {
      this.SectionTitle('Color mode', 'Choose the appearance of the app')
      this.ThemeChoiceList()
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
  }

  @Builder
  private FontStyleTab() {
    Column({ space: 16 }) {
      this.SectionTitle('Font style', 'Adjust typography density')
      this.FontChoiceList()
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
  }

  @Builder
  private LanguagesTab() {
    Column({ space: 16 }) {
      this.SectionTitle('Language', 'Choose your interface language')
      this.LanguageChoiceList()
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
  }

  @Builder
  private NotificationsTab() {
    Column({ space: 16 }) {
      this.SectionTitle('Notifications', 'Control alerts and background activity')
      this.ToggleRow(
        'Enable notifications',
        'Master switch for all Claude Coca alerts',
        this.settings.notificationsEnabled,
        (value: boolean) => {
          this.updateSettings({ notificationsEnabled: value });
        }
      )
      this.ToggleRow(
        'Chat completion',
        'Notify when a long response finishes',
        this.settings.notifyOnChatComplete,
        (value: boolean) => {
          this.updateSettings({ notifyOnChatComplete: value });
        }
      )
      this.ToggleRow(
        'Repository updates',
        'Alerts about new commits or pull requests',
        this.settings.notifyOnRepositoryUpdates,
        (value: boolean) => {
          this.updateSettings({ notifyOnRepositoryUpdates: value });
        }
      )
      this.ToggleRow(
        'Errors and warnings',
        'Surface critical issues even when the app is in the background',
        this.settings.notifyOnErrors,
        (value: boolean) => {
          this.updateSettings({ notifyOnErrors: value });
        }
      )
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
  }

  @Builder
  private ThemeChoiceList() {
    Column({ space: 8 }) {
      ForEach(THEME_OPTIONS, (option: ThemeOption) => {
        this.ChoiceRow(option.title, option.subtitle, option.value === this.settings.themeMode, () => {
          this.updateSettings({ themeMode: option.value });
        })
      }, (option: ThemeOption) => option.value)
    }
    .width('100%')
  }

  @Builder
  private FontChoiceList() {
    Column({ space: 8 }) {
      ForEach(FONT_OPTIONS, (option: FontOption) => {
        this.ChoiceRow(option.title, option.subtitle, option.value === this.settings.fontStyle, () => {
          this.updateSettings({ fontStyle: option.value });
        })
      }, (option: FontOption) => option.value)
    }
    .width('100%')
  }

  @Builder
  private LanguageChoiceList() {
    Column({ space: 8 }) {
      ForEach(LANGUAGE_OPTIONS, (option: LanguageOption) => {
        this.ChoiceRow(option.title, option.subtitle, option.value === this.settings.language, () => {
          this.updateSettings({ language: option.value });
        })
      }, (option: LanguageOption) => option.value)
    }
    .width('100%')
  }

  @Builder
  private RepositoryChoiceList() {
    Column({ space: 8 }) {
      ForEach(REPOSITORY_OPTIONS, (option: RepositoryOption) => {
        this.ChoiceRow(option.title, option.subtitle, option.value === this.settings.repositoryProvider, () => {
          this.updateSettings({ repositoryProvider: option.value });
        })
      }, (option: RepositoryOption) => option.value)
    }
    .width('100%')
  }

  @Builder
  private ModelChoiceList() {
    Column({ space: 8 }) {
      ForEach(MODEL_OPTIONS, (option: ModelOption) => {
        this.ChoiceRow(option.title, option.subtitle, option.value === this.settings.defaultModelProvider, () => {
          this.updateSettings({ defaultModelProvider: option.value });
        })
      }, (option: ModelOption) => option.value)
    }
    .width('100%')
  }

  @Builder
  private SectionTitle(title: string, subtitle: string) {
    Column() {
      Text(title)
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor('#1D2D2C')
      Text(subtitle)
        .fontSize(13)
        .fontColor('#6F6A5F')
        .margin({ top: 4 })
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
  }

  @Builder
  private ChoiceRow(title: string, subtitle: string, selected: boolean, onSelect: () => void) {
    Row() {
      Column() {
        Text(title)
          .fontSize(14)
          .fontWeight(selected ? FontWeight.Bold : FontWeight.Medium)
          .fontColor(selected ? '#FFFFFF' : '#1D2D2C')
        Text(subtitle)
          .fontSize(12)
          .fontColor(selected ? '#E4FAF7' : '#6F6A5F')
          .margin({ top: 3 })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      if (selected) {
        Text('✓')
          .fontSize(16)
          .fontColor('#FFFFFF')
      }
    }
    .width('100%')
    .padding({ left: 14, right: 14, top: 12, bottom: 12 })
    .borderRadius(8)
    .backgroundColor(selected ? '#245B57' : '#FFFFFF')
    .onClick(() => {
      onSelect();
    })
  }

  @Builder
  private ToggleRow(title: string, subtitle: string, value: boolean, onChange: (value: boolean) => void) {
    Row() {
      Column() {
        Text(title)
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor('#1D2D2C')
        Text(subtitle)
          .fontSize(12)
          .fontColor('#6F6A5F')
          .margin({ top: 3 })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Toggle({ type: ToggleType.Switch, isOn: value })
        .selectedColor('#245B57')
        .onChange((isOn: boolean) => {
          onChange(isOn);
        })
    }
    .width('100%')
    .padding(16)
    .borderRadius(8)
    .backgroundColor('#FFFFFF')
  }

  @Builder
  private InfoRow(label: string, value: string) {
    Row() {
      Text(label)
        .fontSize(13)
        .fontColor('#716B62')
        .width(160)
      Text(value)
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor('#1D2D2C')
        .layoutWeight(1)
    }
    .width('100%')
    .padding(16)
    .borderRadius(8)
    .backgroundColor('#FFFFFF')
  }

  @Builder
  private HintCard(message: string) {
    Text(message)
      .fontSize(13)
      .fontColor('#5F6865')
      .lineHeight(20)
      .width('100%')
      .padding(14)
      .borderRadius(8)
      .backgroundColor('#EEF5F2')
  }
}
