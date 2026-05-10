import { common, Want } from '@kit.AbilityKit';
import { pasteboard } from '@kit.BasicServicesKit';
import { router } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { RepositoryProviderKind } from '../repository';
import { AppServices, getAppServices } from '../app/AppServices';
import {
  describeProvider,
  OAuthErrorKind,
  OAuthSessionSnapshot,
  OAuthSessionState
} from '../oauth';

const LOG_DOMAIN: number = 0x0000;
const LOG_TAG: string = 'ClaudeCocaLogin';

interface OssLoginOption {
  kind: RepositoryProviderKind;
  title: string;
  subtitle: string;
  badge: string;
  badgeColor: string;
  badgeTextColor: string;
  accent: string;
}

const LOGIN_OPTIONS: OssLoginOption[] = [
  {
    kind: RepositoryProviderKind.GitHub,
    title: 'Continue with GitHub',
    subtitle: 'Sign in with your GitHub account',
    badge: 'GH',
    badgeColor: '#1D2D2C',
    badgeTextColor: '#FFFFFF',
    accent: '#1D2D2C'
  },
  {
    kind: RepositoryProviderKind.GitCode,
    title: 'Continue with GitCode',
    subtitle: 'Sign in with your GitCode account',
    badge: 'GC',
    badgeColor: '#1F6FEB',
    badgeTextColor: '#FFFFFF',
    accent: '#1F6FEB'
  },
  {
    kind: RepositoryProviderKind.Gitee,
    title: 'Continue with Gitee',
    subtitle: 'Sign in with your Gitee account',
    badge: 'GE',
    badgeColor: '#C71D23',
    badgeTextColor: '#FFFFFF',
    accent: '#C71D23'
  }
];

@Entry
@Component
struct Index {
  @State private statusMessage: string = '';
  @State private modalVisible: boolean = false;
  @State private modalProvider: RepositoryProviderKind = RepositoryProviderKind.GitHub;
  @State private modalProviderName: string = 'GitHub';
  @State private modalState: OAuthSessionState = OAuthSessionState.Idle;
  @State private modalUserCode: string = '';
  @State private modalVerificationUri: string = '';
  @State private modalVerificationUriComplete: string = '';
  @State private modalStatusText: string = '';
  @State private modalErrorText: string = '';

  private readonly services: AppServices = getAppServices();
  private unsubscribe?: () => void;

  aboutToDisappear(): void {
    if (this.unsubscribe) {
      this.unsubscribe();
      this.unsubscribe = undefined;
    }
    this.services.oauthService.cancel();
  }

  private openOssLogin(option: OssLoginOption): void {
    this.services.settingsStore.update({ repositoryProvider: option.kind });
    this.modalProvider = option.kind;
    this.modalProviderName = describeProvider(option.kind);
    this.modalUserCode = '';
    this.modalVerificationUri = '';
    this.modalVerificationUriComplete = '';
    this.modalErrorText = '';
    this.modalStatusText = `Requesting device code from ${this.modalProviderName}...`;
    this.modalState = OAuthSessionState.RequestingDeviceCode;
    this.statusMessage = '';
    this.modalVisible = true;

    if (this.unsubscribe) {
      this.unsubscribe();
    }
    this.unsubscribe = this.services.oauthService.subscribe((snapshot: OAuthSessionSnapshot) => {
      this.applyOAuthSnapshot(snapshot);
    });

    const clientIds = this.services.settingsStore.getSnapshot().oauthClientIds;
    this.services.oauthService.start(option.kind, clientIds)
      .then((final: OAuthSessionSnapshot) => {
        this.applyOAuthSnapshot(final);
        if (final.state === OAuthSessionState.Authenticated && final.token) {
          this.services.repositoryCredentialStore.saveOAuthToken({
            provider: option.kind,
            accessToken: final.token.accessToken,
            refreshToken: final.token.refreshToken,
            scopes: final.token.scopes,
            expiresAt: final.token.expiresInSeconds !== undefined
              ? Date.now() + final.token.expiresInSeconds * 1000
              : undefined,
            displayName: `${this.modalProviderName} OAuth`
          }).then(() => {
            this.modalVisible = false;
            this.statusMessage = `Signed in to ${this.modalProviderName}`;
            this.goToWorkspace();
          }).catch((error: Error) => {
            this.modalErrorText = `Could not save credential: ${error.message}`;
          });
        }
      })
      .catch((error: Error) => {
        hilog.error(LOG_DOMAIN, LOG_TAG, 'OAuth session failed: %{public}s', error.message);
        this.modalErrorText = error.message;
      });
  }

  private applyOAuthSnapshot(snapshot: OAuthSessionSnapshot): void {
    this.modalState = snapshot.state;
    if (snapshot.grant) {
      this.modalUserCode = snapshot.grant.userCode;
      this.modalVerificationUri = snapshot.grant.verificationUri;
      this.modalVerificationUriComplete = snapshot.grant.verificationUriComplete || '';
    }
    if (snapshot.state === OAuthSessionState.RequestingDeviceCode) {
      this.modalStatusText = 'Requesting device code...';
    } else if (snapshot.state === OAuthSessionState.AwaitingUserAuthorization) {
      this.modalStatusText = `Waiting for you to authorize on ${this.modalProviderName} (polling every ${snapshot.pollIntervalSeconds}s)...`;
    } else if (snapshot.state === OAuthSessionState.ExchangingToken) {
      this.modalStatusText = 'Checking authorization status...';
    } else if (snapshot.state === OAuthSessionState.Authenticated) {
      this.modalStatusText = 'Authorized.';
    } else if (snapshot.state === OAuthSessionState.Cancelled) {
      this.modalStatusText = 'Cancelled.';
    } else if (snapshot.state === OAuthSessionState.Failed) {
      this.modalStatusText = '';
      this.modalErrorText = snapshot.error
        ? this.describeError(snapshot.error.kind, snapshot.error.message)
        : 'Sign-in failed';
    }
  }

  private describeError(kind: OAuthErrorKind, message: string): string {
    if (kind === OAuthErrorKind.MissingClientId) {
      return 'No OAuth client ID is configured for this provider. Open Settings → Connector and paste the client ID issued by your OAuth app.';
    }
    if (kind === OAuthErrorKind.AccessDenied) {
      return 'Authorization was declined.';
    }
    if (kind === OAuthErrorKind.ExpiredToken) {
      return 'The device code expired before authorization was completed. Please try again.';
    }
    if (kind === OAuthErrorKind.Network) {
      return `Network error: ${message}`;
    }
    return message;
  }

  private cancelOAuth(): void {
    this.services.oauthService.cancel();
    this.modalVisible = false;
  }

  private openVerificationPage(): void {
    const url: string = this.modalVerificationUriComplete.length > 0
      ? this.modalVerificationUriComplete
      : this.modalVerificationUri;
    if (url.length === 0) {
      return;
    }
    const context = getContext(this) as common.UIAbilityContext;
    const want: Want = { action: 'ohos.want.action.viewData', uri: url };
    context.startAbility(want)
      .then(() => {
        hilog.info(LOG_DOMAIN, LOG_TAG, 'Opened verification page for %{public}s', this.modalProvider);
      })
      .catch((error: Error) => {
        hilog.error(LOG_DOMAIN, LOG_TAG, 'Failed to open verification page: %{public}s', error.message);
        this.modalErrorText = `Could not open browser: ${error.message}`;
      });
  }

  private copyUserCode(): void {
    if (this.modalUserCode.length === 0) {
      return;
    }
    const data = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, this.modalUserCode);
    pasteboard.getSystemPasteboard().setData(data)
      .then(() => {
        this.modalStatusText = 'Code copied to clipboard';
      })
      .catch((error: Error) => {
        this.modalErrorText = `Could not copy code: ${error.message}`;
      });
  }

  private goToWorkspace(): void {
    router.pushUrl({ url: 'pages/Workspace' }).catch((error: Error) => {
      this.statusMessage = error.message;
    });
  }

  private goToSettings(): void {
    router.pushUrl({ url: 'pages/Settings' }).catch((error: Error) => {
      this.statusMessage = error.message;
    });
  }

  build() {
    Stack({ alignContent: Alignment.TopEnd }) {
      Scroll() {
        Column() {
          this.HeroSection();
          this.LoginButtons();
          this.SecondaryActions();
          this.LegalFootnote();
        }
        .width('100%')
        .alignItems(HorizontalAlign.Center)
        .padding({ left: 28, right: 28, top: 64, bottom: 32 })
      }
      .width('100%')
      .height('100%')

      Button('Settings')
        .fontSize(13)
        .fontColor('#1D2D2C')
        .backgroundColor('#EFEDE4')
        .borderRadius(18)
        .height(36)
        .margin({ top: 24, right: 20 })
        .onClick(() => {
          this.goToSettings();
        })

      if (this.modalVisible) {
        this.OAuthModal();
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#FAFAF6')
  }

  @Builder
  private OAuthModal() {
    Column() {
      Column() {
        Text(`Sign in to ${this.modalProviderName}`)
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1D2D2C')

        Text('Open the verification page on any device, then enter the code below.')
          .fontSize(13)
          .fontColor('#6F6A5F')
          .margin({ top: 8 })
          .textAlign(TextAlign.Start)

        if (this.modalUserCode.length > 0) {
          Column() {
            Text('Your code')
              .fontSize(11)
              .fontColor('#9A9486')
            Text(this.modalUserCode)
              .fontSize(28)
              .fontWeight(FontWeight.Bold)
              .fontColor('#245B57')
              .margin({ top: 4 })
          }
          .alignItems(HorizontalAlign.Start)
          .width('100%')
          .padding(16)
          .borderRadius(12)
          .backgroundColor('#EEF5F2')
          .margin({ top: 16 })

          Row({ space: 10 }) {
            Button('Copy code')
              .fontSize(13)
              .fontColor('#245B57')
              .backgroundColor('#E7F1EF')
              .borderRadius(10)
              .layoutWeight(1)
              .height(40)
              .onClick(() => {
                this.copyUserCode();
              })
            Button('Open verification page')
              .fontSize(13)
              .fontColor('#FAFAF6')
              .backgroundColor('#245B57')
              .borderRadius(10)
              .layoutWeight(1)
              .height(40)
              .onClick(() => {
                this.openVerificationPage();
              })
          }
          .width('100%')
          .margin({ top: 12 })

          if (this.modalVerificationUri.length > 0) {
            Text(this.modalVerificationUri)
              .fontSize(11)
              .fontColor('#6F6A5F')
              .margin({ top: 8 })
          }
        }

        if (this.modalStatusText.length > 0) {
          Text(this.modalStatusText)
            .fontSize(12)
            .fontColor('#5F6865')
            .margin({ top: 16 })
            .textAlign(TextAlign.Start)
            .width('100%')
        }

        if (this.modalErrorText.length > 0) {
          Text(this.modalErrorText)
            .fontSize(12)
            .fontColor('#C71D23')
            .margin({ top: 8 })
            .textAlign(TextAlign.Start)
            .width('100%')
        }

        Button(this.isModalTerminal() ? 'Close' : 'Cancel')
          .fontSize(14)
          .fontColor('#1D2D2C')
          .backgroundColor('#EFEDE4')
          .borderRadius(10)
          .width('100%')
          .height(44)
          .margin({ top: 20 })
          .onClick(() => {
            this.cancelOAuth();
          })
      }
      .width('100%')
      .constraintSize({ maxWidth: 420 })
      .padding(24)
      .borderRadius(20)
      .backgroundColor('#FFFFFF')
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .height('100%')
    .padding(24)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .backgroundColor('rgba(15, 26, 25, 0.55)')
  }

  private isModalTerminal(): boolean {
    return this.modalState === OAuthSessionState.Authenticated
      || this.modalState === OAuthSessionState.Cancelled
      || this.modalState === OAuthSessionState.Failed;
  }

  @Builder
  private HeroSection() {
    Column() {
      Column() {
        Text('C')
          .fontSize(40)
          .fontWeight(FontWeight.Bold)
          .fontColor('#FAFAF6')
      }
      .width(84)
      .height(84)
      .borderRadius(24)
      .backgroundColor('#245B57')
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)

      Text('Claude Coca')
        .fontSize(30)
        .fontWeight(FontWeight.Bold)
        .fontColor('#1D2D2C')
        .margin({ top: 24 })

      Text('Your coding companion on HarmonyOS')
        .fontSize(15)
        .fontColor('#6F6A5F')
        .textAlign(TextAlign.Center)
        .margin({ top: 8 })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
    .margin({ bottom: 40 })
  }

  @Builder
  private LoginButtons() {
    Column({ space: 12 }) {
      ForEach(LOGIN_OPTIONS, (option: OssLoginOption) => {
        Row() {
          Column() {
            Text(option.badge)
              .fontSize(15)
              .fontWeight(FontWeight.Bold)
              .fontColor(option.badgeTextColor)
          }
          .width(40)
          .height(40)
          .borderRadius(12)
          .backgroundColor(option.badgeColor)
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Center)

          Column() {
            Text(option.title)
              .fontSize(15)
              .fontWeight(FontWeight.Bold)
              .fontColor('#1D2D2C')
            Text(option.subtitle)
              .fontSize(12)
              .fontColor('#6F6A5F')
              .margin({ top: 3 })
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
          .margin({ left: 14 })

          Text('›')
            .fontSize(22)
            .fontColor(option.accent)
        }
        .width('100%')
        .padding({ left: 16, right: 18, top: 14, bottom: 14 })
        .borderRadius(14)
        .backgroundColor('#FFFFFF')
        .border({ width: 1, color: '#E6E2D6' })
        .onClick(() => {
          this.openOssLogin(option);
        })
      }, (option: OssLoginOption) => option.kind)
    }
    .width('100%')
    .constraintSize({ maxWidth: 480 })
  }

  @Builder
  private SecondaryActions() {
    Column({ space: 10 }) {
      if (this.statusMessage.length > 0) {
        Text(this.statusMessage)
          .fontSize(12)
          .fontColor('#5F6865')
          .textAlign(TextAlign.Center)
      }

      Row() {
        Divider().layoutWeight(1).color('#E6E2D6').strokeWidth(1)
        Text('or')
          .fontSize(12)
          .fontColor('#9A9486')
          .margin({ left: 12, right: 12 })
        Divider().layoutWeight(1).color('#E6E2D6').strokeWidth(1)
      }
      .width('100%')
      .constraintSize({ maxWidth: 480 })

      Button('Continue without signing in')
        .fontSize(14)
        .fontColor('#245B57')
        .backgroundColor('#E7F1EF')
        .borderRadius(12)
        .width('100%')
        .height(44)
        .onClick(() => {
          this.goToWorkspace();
        })
    }
    .width('100%')
    .constraintSize({ maxWidth: 480 })
    .margin({ top: 24 })
  }

  @Builder
  private LegalFootnote() {
    Text('By continuing you agree to the Claude Coca terms and acknowledge the privacy policy.')
      .fontSize(11)
      .fontColor('#9A9486')
      .textAlign(TextAlign.Center)
      .lineHeight(18)
      .constraintSize({ maxWidth: 360 })
      .margin({ top: 32 })
  }
}
