import { router } from '@kit.ArkUI';
import {
  BranchSummary,
  RemoteEntryKind,
  RemoteTreeEntry,
  RepositoryAuthContext,
  RepositoryCredential,
  RepositoryCredentialKind,
  RepositoryProviderKind,
  RepositorySummary
} from '../repository';
import {
  ChatAbortSignal,
  ChatMessage,
  ChatRequest,
  ModelErrorCode,
  ModelException,
  ModelMessageRole,
  ModelMetadata,
  ModelProviderKind,
  StreamEvent,
  StreamEventType,
  isRetryableModelError
} from '../models';
import { AppServices, getAppServices } from '../app/AppServices';
import { AppSettings } from '../settings/AppSettingsStore';

interface NavigationItem {
  title: string;
  eyebrow: string;
}

const NAVIGATION_ITEMS: NavigationItem[] = [
  { title: 'Chat', eyebrow: 'Conversation' },
  { title: 'Files', eyebrow: 'Workspace' },
  { title: 'Repositories', eyebrow: 'Remote code' },
  { title: 'Models', eyebrow: 'Providers' }
];

const MOCK_CREDENTIAL: RepositoryCredential = {
  id: 'mock-credential',
  provider: RepositoryProviderKind.GitHub,
  kind: RepositoryCredentialKind.PersonalAccessToken,
  displayName: 'Mock GitHub token',
  tokenRef: 'mock-token-ref',
  scopes: ['repo'],
  accountLogin: 'claude-coca'
};

@Entry
@Component
struct Workspace {
  @State private selectedTabIndex: number = 0;
  @State private repositoryName: string = 'claude-coca/demo';
  @State private branchName: string = 'main';
  @State private fileSummary: string = 'README.md';
  @State private statusText: string = 'Mock repository ready';
  @State private selectedModelProvider: ModelProviderKind = ModelProviderKind.Mock;
  @State private selectedModelId: string = 'mock-claude-coca-v1';
  @State private apiKeyInput: string = '';
  @State private apiKeyStatus: string = 'No API key required for Mock Local';
  @State private chatPrompt: string = '';
  @State private chatOutput: string = '';
  @State private chatStatus: string = 'Ready';
  @State private lastErrorMessage: string = '';
  @State private showRetry: boolean = false;
  @State private lastPrompt: string = '';
  @State private isSending: boolean = false;
  @State private modelProviders: ModelMetadata[] = [];

  private readonly services: AppServices = getAppServices();
  private chatAbortSignal?: ChatAbortSignal;
  private readonly authContext: RepositoryAuthContext = {
    credential: MOCK_CREDENTIAL,
    accessToken: 'mock-token'
  };

  aboutToAppear(): void {
    this.refreshRepositoryPreview();
    this.hydrateModelSettings();
  }

  private hydrateModelSettings(): void {
    const settings = this.services.settingsStore.getSnapshot();
    this.selectedModelProvider = settings.defaultModelProvider;
    this.selectedModelId = settings.defaultModelId;
    this.modelProviders = this.services.modelProviderRegistry.list().map((provider) => provider.getMetadata());
    this.loadSavedApiKey(this.selectedModelProvider).catch((error: Error) => {
      this.apiKeyStatus = error.message;
    });
  }

  private refreshRepositoryPreview(): void {
    this.loadRepositoryPreview().catch((error: Error) => {
      this.statusText = error.message;
    });
  }

  private async loadRepositoryPreview(): Promise<void> {
    const provider = this.services.repositoryProviderRegistry.require(RepositoryProviderKind.GitHub);
    const repositories = await provider.listRepositories(this.authContext);
    const repository: RepositorySummary | undefined = repositories.items[0];
    if (!repository) {
      this.statusText = 'No repositories available';
      return;
    }

    const defaultBranch: BranchSummary = await provider.getDefaultBranch(this.authContext, repository);
    const treeEntries: RemoteTreeEntry[] = await provider.listTree(this.authContext, {
      repository: repository.ref,
      branch: defaultBranch.name
    });

    this.repositoryName = repository.ref.fullName;
    this.branchName = defaultBranch.name;
    this.fileSummary = treeEntries.map((entry: RemoteTreeEntry) => {
      return entry.kind === RemoteEntryKind.Directory ? `${entry.name}/` : entry.name;
    }).join(', ');
    this.statusText = `${treeEntries.length} item loaded from the mock provider`;
  }

  private async loadSavedApiKey(providerKind: ModelProviderKind): Promise<void> {
    const key = await this.services.modelCredentialStore.readApiKey(providerKind);
    this.apiKeyInput = key || '';
    if (providerKind === ModelProviderKind.Mock) {
      this.apiKeyStatus = 'No API key required for Mock Local';
      return;
    }
    this.apiKeyStatus = key ? `Saved key: ${maskApiKey(key)}` : 'No saved API key';
  }

  private async selectModelProvider(providerKind: ModelProviderKind): Promise<void> {
    const provider = this.services.modelProviderRegistry.require(providerKind);
    const metadata = provider.getMetadata();
    this.selectedModelProvider = providerKind;
    this.selectedModelId = metadata.defaultModelId;
    this.services.settingsStore.update({
      defaultModelProvider: providerKind,
      defaultModelId: metadata.defaultModelId
    });
    await this.loadSavedApiKey(providerKind);
  }

  private async saveApiKey(): Promise<void> {
    const provider = this.services.modelProviderRegistry.require(this.selectedModelProvider);
    const metadata = provider.getMetadata();
    if (!metadata.requiresApiKey) {
      this.apiKeyStatus = `${metadata.displayName} does not require an API key`;
      return;
    }
    const valid = await provider.validateApiKey(this.apiKeyInput);
    if (!valid) {
      this.apiKeyStatus = 'API key format appears invalid';
      return;
    }
    await this.services.modelCredentialStore.saveApiKey(this.selectedModelProvider, this.apiKeyInput);
    this.apiKeyStatus = `Saved key: ${maskApiKey(this.apiKeyInput)}`;
  }

  private async clearApiKey(): Promise<void> {
    await this.services.modelCredentialStore.deleteApiKey(this.selectedModelProvider);
    this.apiKeyInput = '';
    this.apiKeyStatus = 'API key cleared';
  }

  private async sendChat(promptOverride?: string): Promise<void> {
    if (this.isSending) {
      return;
    }
    const prompt = (promptOverride || this.chatPrompt).trim();
    if (prompt.length === 0) {
      this.chatStatus = 'Enter a prompt to start chat';
      return;
    }

    this.lastPrompt = prompt;
    this.lastErrorMessage = '';
    this.showRetry = false;
    this.chatOutput = '';
    this.chatStatus = 'Sending request...';
    this.isSending = true;

    const provider = this.services.modelProviderRegistry.require(this.selectedModelProvider);
    const metadata = provider.getMetadata();
    const apiKey = metadata.requiresApiKey ? await this.services.modelCredentialStore.readApiKey(this.selectedModelProvider) : undefined;
    this.chatAbortSignal = new ChatAbortSignal();

    const request: ChatRequest = {
      modelId: this.selectedModelId,
      messages: [{ role: ModelMessageRole.User, content: prompt } as ChatMessage],
      temperature: 0.2
    };

    try {
      await provider.streamChat(request, apiKey, (event: StreamEvent) => {
        if (event.type === StreamEventType.Started) {
          this.chatStatus = `Streaming from ${metadata.displayName}...`;
          return;
        }
        if (event.type === StreamEventType.Delta) {
          this.chatOutput += event.textDelta || '';
          return;
        }
        if (event.type === StreamEventType.Completed) {
          this.chatOutput = event.fullText || this.chatOutput;
          this.chatStatus = 'Completed';
        }
      }, this.chatAbortSignal);
      this.chatPrompt = '';
    } catch (error) {
      this.handleChatError(error);
    } finally {
      this.isSending = false;
      this.chatAbortSignal = undefined;
    }
  }

  private cancelChat(): void {
    if (!this.chatAbortSignal) {
      return;
    }
    this.chatAbortSignal.cancel();
    this.chatStatus = 'Cancelling...';
  }

  private retryChat(): void {
    this.sendChat(this.lastPrompt).catch((error: Error) => {
      this.chatStatus = error.message;
    });
  }

  private handleChatError(error: Object): void {
    if (error instanceof ModelException) {
      this.chatStatus = mapErrorCodeToStatus(error.code);
      this.lastErrorMessage = error.message;
      this.showRetry = isRetryableModelError(error.code);
      return;
    }
    const message = (error as Error).message || 'Unknown error';
    this.chatStatus = message;
    this.lastErrorMessage = message;
    this.showRetry = false;
  }

  build() {
    Row() {
      Column() {
        this.BrandHeader();
        this.NavigationRail();
        Blank().layoutWeight(1)
        this.SettingsLink();
      }
      .width(196)
      .height('100%')
      .padding({ left: 16, right: 12, top: 20, bottom: 20 })
      .backgroundColor('#F4F0E8')

      Column() {
        this.TopBar();
        Divider().color('#D9D6CC')
        Scroll() {
          Column() {
            this.CurrentPage();
          }
          .width('100%')
          .padding(24)
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
  private BrandHeader() {
    Column() {
      Text('Claude Coca')
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .fontColor('#1D2D2C')
      Text('Workspace')
        .fontSize(12)
        .fontColor('#6F6A5F')
        .margin({ top: 4 })
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
    .margin({ bottom: 28 })
  }

  @Builder
  private NavigationRail() {
    Column({ space: 8 }) {
      ForEach(NAVIGATION_ITEMS, (item: NavigationItem, index: number) => {
        Column() {
          Text(item.title)
            .fontSize(15)
            .fontWeight(this.selectedTabIndex === index ? FontWeight.Bold : FontWeight.Medium)
            .fontColor(this.selectedTabIndex === index ? '#FFFFFF' : '#223231')
          Text(item.eyebrow)
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
      }, (item: NavigationItem) => item.title)
    }
    .width('100%')
  }

  @Builder
  private SettingsLink() {
    Column() {
      Text('Settings')
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor('#1D2D2C')
      Text('Capability, profile, theme...')
        .fontSize(11)
        .fontColor('#716B62')
        .margin({ top: 3 })
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
    .padding({ left: 12, right: 12, top: 10, bottom: 10 })
    .borderRadius(8)
    .backgroundColor('#FFFFFF')
    .onClick(() => {
      router.pushUrl({ url: 'pages/Settings' }).catch((error: Error) => {
        this.statusText = error.message;
      });
    })
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
        Text(NAVIGATION_ITEMS[this.selectedTabIndex].title)
          .fontSize(26)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1D2D2C')
        Text(this.statusText)
          .fontSize(13)
          .fontColor('#6F6A5F')
          .margin({ top: 4 })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      .margin({ left: 16 })

      Button('Refresh')
        .fontSize(14)
        .fontColor('#FFFFFF')
        .backgroundColor('#245B57')
        .borderRadius(8)
        .height(38)
        .onClick(() => {
          this.refreshRepositoryPreview();
        })
    }
    .width('100%')
    .padding({ left: 24, right: 24, top: 20, bottom: 18 })
    .backgroundColor('#FAFAF6')
  }

  @Builder
  private CurrentPage() {
    if (this.selectedTabIndex === 0) {
      this.ChatPanel()
    } else if (this.selectedTabIndex === 1) {
      this.EmptyPanel('Files', 'No local workspace selected', 'Workspace access is not connected yet.')
    } else if (this.selectedTabIndex === 2) {
      this.RepositoryPanel()
    } else {
      this.ModelsPanel()
    }
  }

  @Builder
  private ChatPanel() {
    Column({ space: 16 }) {
      this.InfoRow('Provider', this.selectedModelProvider)
      this.InfoRow('Model', this.selectedModelId)
      this.InfoRow('Status', this.chatStatus)

      if (this.lastErrorMessage.length > 0) {
        Column() {
          Text('Error')
            .fontSize(13)
            .fontWeight(FontWeight.Bold)
            .fontColor('#7A2B2B')
          Text(this.lastErrorMessage)
            .fontSize(13)
            .fontColor('#7A2B2B')
            .margin({ top: 6 })
        }
        .alignItems(HorizontalAlign.Start)
        .width('100%')
        .padding(14)
        .borderRadius(8)
        .backgroundColor('#FFEDEE')
      }

      Column() {
        Text('Prompt')
          .fontSize(13)
          .fontColor('#716B62')
        TextInput({ text: this.chatPrompt, placeholder: 'Describe a coding task...' })
          .width('100%')
          .height(44)
          .backgroundColor('#FFFFFF')
          .borderRadius(8)
          .onChange((value: string) => {
            this.chatPrompt = value;
          })
      }
      .alignItems(HorizontalAlign.Start)
      .width('100%')

      Row({ space: 10 }) {
        Button(this.isSending ? 'Sending...' : 'Send')
          .fontSize(14)
          .fontColor('#FFFFFF')
          .backgroundColor('#245B57')
          .borderRadius(8)
          .enabled(!this.isSending)
          .onClick(() => {
            this.sendChat().catch((error: Error) => {
              this.chatStatus = error.message;
            });
          })

        Button('Cancel')
          .fontSize(14)
          .fontColor('#245B57')
          .backgroundColor('#E7F1EF')
          .borderRadius(8)
          .enabled(this.isSending)
          .onClick(() => {
            this.cancelChat();
          })

        if (this.showRetry) {
          Button('Retry')
            .fontSize(14)
            .fontColor('#245B57')
            .backgroundColor('#EFEDE4')
            .borderRadius(8)
            .onClick(() => {
              this.retryChat();
            })
        }
      }

      Column() {
        Text('Response stream')
          .fontSize(13)
          .fontColor('#716B62')
        Text(this.chatOutput.length > 0 ? this.chatOutput : 'No output yet.')
          .fontSize(14)
          .fontColor('#1D2D2C')
          .lineHeight(22)
          .margin({ top: 8 })
      }
      .alignItems(HorizontalAlign.Start)
      .width('100%')
      .padding(18)
      .borderRadius(8)
      .backgroundColor('#FFFFFF')
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
  }

  @Builder
  private RepositoryPanel() {
    Column({ space: 16 }) {
      this.InfoRow('Provider', 'Mock GitHub')
      this.InfoRow('Repository', this.repositoryName)
      this.InfoRow('Branch', this.branchName)
      this.InfoRow('Tree', this.fileSummary)

      Column() {
        Text('Repository Workflow')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1D2D2C')
        Text('Mock provider connected. Repository state is loaded through the provider contract.')
          .fontSize(14)
          .fontColor('#5F6865')
          .lineHeight(22)
          .margin({ top: 8 })
      }
      .alignItems(HorizontalAlign.Start)
      .width('100%')
      .padding(18)
      .borderRadius(8)
      .backgroundColor('#EEF5F2')
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
  }

  @Builder
  private ModelsPanel() {
    Column({ space: 16 }) {
      Column({ space: 8 }) {
        Text('Provider')
          .fontSize(13)
          .fontColor('#716B62')
        ForEach(this.modelProviders, (provider: ModelMetadata) => {
          Row() {
            Text(provider.displayName)
              .fontSize(14)
              .fontWeight(this.selectedModelProvider === provider.kind ? FontWeight.Bold : FontWeight.Medium)
              .fontColor(this.selectedModelProvider === provider.kind ? '#FFFFFF' : '#1D2D2C')
            Blank().layoutWeight(1)
            Text(provider.defaultModelId)
              .fontSize(12)
              .fontColor(this.selectedModelProvider === provider.kind ? '#E4FAF7' : '#6F6A5F')
          }
          .width('100%')
          .padding({ left: 12, right: 12, top: 10, bottom: 10 })
          .borderRadius(8)
          .backgroundColor(this.selectedModelProvider === provider.kind ? '#245B57' : '#FFFFFF')
          .onClick(() => {
            this.selectModelProvider(provider.kind).catch((error: Error) => {
              this.apiKeyStatus = error.message;
            });
          })
        }, (provider: ModelMetadata) => provider.kind)
      }
      .width('100%')

      Column() {
        Text('Model ID')
          .fontSize(13)
          .fontColor('#716B62')
        TextInput({ text: this.selectedModelId, placeholder: 'Model ID' })
          .width('100%')
          .height(44)
          .backgroundColor('#FFFFFF')
          .borderRadius(8)
          .onChange((value: string) => {
            this.selectedModelId = value;
            this.services.settingsStore.update({ defaultModelId: value });
          })
      }
      .alignItems(HorizontalAlign.Start)
      .width('100%')

      Column() {
        Text('API Key')
          .fontSize(13)
          .fontColor('#716B62')
        TextInput({ text: this.apiKeyInput, placeholder: 'Enter provider API key' })
          .width('100%')
          .height(44)
          .backgroundColor('#FFFFFF')
          .borderRadius(8)
          .onChange((value: string) => {
            this.apiKeyInput = value;
          })
        Text(this.apiKeyStatus)
          .fontSize(12)
          .fontColor('#6F6A5F')
          .margin({ top: 8 })
      }
      .alignItems(HorizontalAlign.Start)
      .width('100%')

      Row({ space: 10 }) {
        Button('Save Key')
          .fontSize(14)
          .fontColor('#FFFFFF')
          .backgroundColor('#245B57')
          .borderRadius(8)
          .onClick(() => {
            this.saveApiKey().catch((error: Error) => {
              this.apiKeyStatus = error.message;
            });
          })
        Button('Clear Key')
          .fontSize(14)
          .fontColor('#245B57')
          .backgroundColor('#E7F1EF')
          .borderRadius(8)
          .onClick(() => {
            this.clearApiKey().catch((error: Error) => {
              this.apiKeyStatus = error.message;
            });
          })
      }

      Column() {
        Text('Test commands')
          .fontSize(13)
          .fontColor('#716B62')
        Text('/error invalid-key | /error network | /error rate-limit | /error unsupported')
          .fontSize(12)
          .fontColor('#6F6A5F')
          .lineHeight(20)
          .margin({ top: 6 })
      }
      .alignItems(HorizontalAlign.Start)
      .width('100%')
      .padding(14)
      .borderRadius(8)
      .backgroundColor('#F1F4EE')
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
  }

  @Builder
  private EmptyPanel(title: string, headline: string, detail: string) {
    Column() {
      Text(title)
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor('#245B57')
      Text(headline)
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .fontColor('#1D2D2C')
        .margin({ top: 14 })
      Text(detail)
        .fontSize(14)
        .fontColor('#5F6865')
        .lineHeight(22)
        .margin({ top: 8 })
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
    .padding(22)
    .borderRadius(8)
    .backgroundColor('#FFFFFF')
  }

  @Builder
  private InfoRow(label: string, value: string) {
    Row() {
      Text(label)
        .fontSize(13)
        .fontColor('#716B62')
        .width(130)
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
}

function mapErrorCodeToStatus(code: ModelErrorCode): string {
  if (code === ModelErrorCode.InvalidApiKey) {
    return 'Invalid API key';
  }
  if (code === ModelErrorCode.NetworkFailure) {
    return 'Network failure';
  }
  if (code === ModelErrorCode.RateLimited) {
    return 'Rate limit reached';
  }
  if (code === ModelErrorCode.UnsupportedModel) {
    return 'Unsupported model or provider wiring missing';
  }
  if (code === ModelErrorCode.Cancelled) {
    return 'Cancelled';
  }
  if (code === ModelErrorCode.InvalidRequest) {
    return 'Invalid request';
  }
  return 'Unknown model error';
}

function maskApiKey(apiKey: string): string {
  if (apiKey.length <= 8) {
    return '***';
  }
  return `${apiKey.substring(0, 4)}...${apiKey.substring(apiKey.length - 4)}`;
}
