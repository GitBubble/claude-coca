import { common, Want } from '@kit.AbilityKit';
import { router } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { RepositoryProviderKind } from '../repository';
import { AppServices, getAppServices } from '../app/AppServices';

const LOG_DOMAIN: number = 0x0000;
const LOG_TAG: string = 'ClaudeCocaLogin';

interface OssLoginOption {
  kind: RepositoryProviderKind;
  title: string;
  subtitle: string;
  authorizeUrl: string;
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
    authorizeUrl: 'https://github.com/login/oauth/authorize?client_id=claude-coca&scope=repo%20read%3Auser&redirect_uri=claude-coca%3A%2F%2Foauth%2Fgithub',
    badge: 'GH',
    badgeColor: '#1D2D2C',
    badgeTextColor: '#FFFFFF',
    accent: '#1D2D2C'
  },
  {
    kind: RepositoryProviderKind.GitCode,
    title: 'Continue with GitCode',
    subtitle: 'Sign in with your GitCode account',
    authorizeUrl: 'https://gitcode.com/oauth/authorize?client_id=claude-coca&scope=user_info%20projects&redirect_uri=claude-coca%3A%2F%2Foauth%2Fgitcode&response_type=code',
    badge: 'GC',
    badgeColor: '#1F6FEB',
    badgeTextColor: '#FFFFFF',
    accent: '#1F6FEB'
  },
  {
    kind: RepositoryProviderKind.Gitee,
    title: 'Continue with Gitee',
    subtitle: 'Sign in with your Gitee account',
    authorizeUrl: 'https://gitee.com/oauth/authorize?client_id=claude-coca&scope=user_info%20projects&redirect_uri=claude-coca%3A%2F%2Foauth%2Fgitee&response_type=code',
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

  private readonly services: AppServices = getAppServices();

  private openOssLogin(option: OssLoginOption): void {
    this.services.settingsStore.update({ repositoryProvider: option.kind });
    this.statusMessage = `Opening ${option.title.replace('Continue with ', '')} sign-in...`;

    const context = getContext(this) as common.UIAbilityContext;
    const want: Want = {
      action: 'ohos.want.action.viewData',
      uri: option.authorizeUrl
    };

    context.startAbility(want)
      .then(() => {
        hilog.info(LOG_DOMAIN, LOG_TAG, 'OAuth browser launched for %{public}s', option.kind);
      })
      .catch((error: Error) => {
        hilog.error(LOG_DOMAIN, LOG_TAG, 'Failed to launch browser: %{public}s', error.message);
        this.statusMessage = `Could not launch browser: ${error.message}`;
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
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#FAFAF6')
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
