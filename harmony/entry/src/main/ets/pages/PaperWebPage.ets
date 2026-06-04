import router from '@ohos.router';
import { webview } from '@kit.ArkWeb';

interface PaperWebRouteParams {
  url?: string;
  title?: string;
}

@Entry
@Component
struct PaperWebPage {
  private controller: webview.WebviewController = new webview.WebviewController();
  @State private targetUrl: string = '';
  @State private pageTitle: string = '论文原文';
  @State private isLoading: boolean = true;
  @State private errorMessage: string = '';

  aboutToAppear(): void {
    const params = router.getParams() as PaperWebRouteParams;
    this.targetUrl = params.url ?? '';
    this.pageTitle = params.title ?? '论文原文';
  }

  private goBack(): void {
    try {
      if (this.controller.accessBackward()) {
        this.controller.backward();
        return;
      }
    } catch (error) {
    }
    router.back();
  }

  @Builder
  private pageToolbar() {
    Row({ space: 12 }) {
      Button({ type: ButtonType.Circle }) {
        SymbolGlyph($r('sys.symbol.chevron_left'))
          .fontSize(22)
          .fontColor(['#111827']);
      }
      .width(44)
      .height(44)
      .backgroundColor('#EEF2F7')
      .onClick(() => this.goBack());

      Column({ space: 2 }) {
        Text(this.pageTitle)
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
          .fontColor('#111827')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis });
        Text(this.targetUrl)
          .fontSize(11)
          .fontColor('#6B7280')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis });
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start);
    }
    .width('100%')
    .height(64)
    .padding({ left: 12, right: 16 })
    .backgroundColor('#FFFFFF');
  }

  build() {
    Column() {
      this.pageToolbar();

      if (this.errorMessage.length > 0) {
        Column({ space: 10 }) {
          Text('页面加载失败')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor('#111827');
          Text(this.errorMessage)
            .fontSize(13)
            .fontColor('#6B7280')
            .textAlign(TextAlign.Center);
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
        .padding({ left: 24, right: 24 });
      } else if (this.targetUrl.length === 0) {
        Column() {
          Text('论文链接暂不可用')
            .fontSize(16)
            .fontColor('#6B7280');
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center);
      } else {
        Stack({ alignContent: Alignment.Top }) {
          Web({
            src: this.targetUrl,
            controller: this.controller
          })
            .javaScriptAccess(true)
            .domStorageAccess(true)
            .onlineImageAccess(true)
            .width('100%')
            .height('100%')
            .onPageBegin(() => {
              this.isLoading = true;
              this.errorMessage = '';
            })
            .onPageEnd(() => {
              this.isLoading = false;
            })
            .onErrorReceive((event) => {
              this.isLoading = false;
              this.errorMessage = event?.error?.getErrorInfo() ?? 'Web 页面未能完成加载';
            });

          if (this.isLoading) {
            Row({ space: 8 }) {
              LoadingProgress()
                .width(18)
                .height(18)
                .color('#2D6CE8');
              Text('加载中...')
                .fontSize(13)
                .fontColor('#374151');
            }
            .padding({ left: 14, right: 14, top: 8, bottom: 8 })
            .backgroundColor('#F8FAFC')
            .borderRadius(16)
            .margin({ top: 12 });
          }
        }
        .width('100%')
        .layoutWeight(1)
        .backgroundColor('#FFFFFF');
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F7F9FD');
  }
}
