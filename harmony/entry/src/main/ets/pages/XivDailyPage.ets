import AppConstants from '../common/constants/AppConstants';
import Context from '@ohos.app.ability.application';
import ConfigurationConstant from '@ohos.app.ability.ConfigurationConstant';
import { resolveXivPalette } from '../common/theme/XivTheme';
import { AppViewModel } from '../viewmodel/AppViewModel';
import { ChatPage } from '../view/ChatPage';
import { HomePage } from '../view/HomePage';
import { LibraryPage } from '../view/LibraryPage';
import { SettingsPage } from '../view/SettingsPage';

@Entry
@Component
struct XivDailyPage {
  @State vm: AppViewModel = new AppViewModel();
  @State private localSelectedTab: number = 0;
  private homeScroller: Scroller = new Scroller();

  aboutToAppear(): void {
    this.applyThemeMode();
    this.localSelectedTab = this.vm.selectedTab;
    // 当 ViewModel 内部触发 tab 切换时（如从收藏库进入对话），同步更新本地状态
    this.vm.onTabChanged = (index: number) => {
      this.localSelectedTab = index;
    };
    this.vm.ensureBootstrapped();
  }

  private applyThemeMode(): void {
    const uiContext = this.getUIContext();
    const hostContext = uiContext.getHostContext();
    if (!hostContext) {
      return;
    }
    const abilityContext = hostContext as ContextWithColorMode;
    const themeMode = this.vm.settingsState.themeMode;
    if (themeMode === 'dark') {
      abilityContext.setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_DARK);
      return;
    }
    if (themeMode === 'light') {
      abilityContext.setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT);
      return;
    }
    abilityContext.setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
  }

  private readSystemColorMode(): string | number | undefined {
    try {
      const hostContext = this.getUIContext().getHostContext() as ContextWithColorMode | undefined;
      return hostContext?.config?.colorMode;
    } catch (error) {
      return undefined;
    }
  }

  private palette() {
    return resolveXivPalette(this.vm.settingsState.themeMode, this.readSystemColorMode());
  }

  private isTabSelected(index: number): boolean {
    return this.localSelectedTab === index;
  }

  private selectTab(index: number): void {
    if (this.localSelectedTab === index && this.vm.selectedTab === index) {
      return;
    }
    this.localSelectedTab = index;
    this.vm.selectTab(index);
  }

  @Builder
  private homeActionBanner() {
    if (this.vm.homeState.actionMessage) {
      Row() {
        Text(this.vm.homeState.actionMessage!.text)
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.palette().surface);
      }
      .padding({ left: 20, right: 20, top: 10, bottom: 10 })
      .backgroundColor(this.palette().textPrimary)
      .borderRadius(16)
      .shadow({
        radius: 18,
        color: '#33000000',
        offsetX: 0,
        offsetY: 8
      });
    }
  }

  @Builder
  private tabIcon(index: number) {
    if (index === 0) {
      SymbolGlyph($r(this.isTabSelected(index) ? 'sys.symbol.star_fill' : 'sys.symbol.star'))
        .fontSize(19)
        .fontColor([this.isTabSelected(index) ? this.palette().primary : this.palette().textSecondary]);
    } else if (index === 1) {
      SymbolGlyph($r(this.isTabSelected(index) ? 'sys.symbol.bookmark_book_fill' : 'sys.symbol.bookmark_book_closed'))
        .fontSize(19)
        .fontColor([this.isTabSelected(index) ? this.palette().primary : this.palette().textSecondary]);
    } else if (index === 2) {
      SymbolGlyph($r(this.isTabSelected(index) ? 'sys.symbol.paperplane_right_fill' : 'sys.symbol.paperplane_fill'))
        .fontSize(19)
        .fontColor([this.isTabSelected(index) ? this.palette().primary : this.palette().textSecondary]);
    } else {
      SymbolGlyph($r(this.isTabSelected(index) ? 'sys.symbol.slider_horizontal_2_square_fill' : 'sys.symbol.slider_horizontal_2'))
        .fontSize(19)
        .fontColor([this.isTabSelected(index) ? this.palette().primary : this.palette().textSecondary]);
    }
  }

  @Builder
  private tabLabel(index: number, label: string) {
    Column({ space: 5 }) {
      Stack({ alignContent: Alignment.Center }) {
        Row()
          .width(42)
          .height(30)
          .backgroundColor(this.isTabSelected(index) ? this.palette().primaryContainer : '#00000000')
          .borderRadius(15)
          .opacity(this.isTabSelected(index) ? 1 : 0);
        this.tabIcon(index);
      }
      .width(42)
      .height(30)
      .scale({ x: this.isTabSelected(index) ? 1.06 : 1, y: this.isTabSelected(index) ? 1.06 : 1 })
      .animation({ duration: 160, curve: Curve.EaseOut });
      Text(label)
        .fontSize(12)
        .fontWeight(this.isTabSelected(index) ? FontWeight.Bold : FontWeight.Medium)
        .fontColor(this.isTabSelected(index) ? this.palette().primary : this.palette().textSecondary)
        .opacity(this.isTabSelected(index) ? 1 : 0.78)
        .animation({ duration: 160, curve: Curve.EaseOut });
    }
    .width('100%')
    .height(AppConstants.TAB_BAR_HEIGHT)
    .justifyContent(FlexAlign.Center)
    // 自定义 tabBar 点击先更新本地选中态，再交给 Tabs onChange 兜底同步页面索引。
    .onClick(() => this.selectTab(index));
  }

  build() {
    Tabs({ barPosition: BarPosition.End, index: this.localSelectedTab }) {
      TabContent() {
        Stack({ alignContent: Alignment.TopStart }) {
          Scroll(this.homeScroller) {
            HomePage({ vm: this.vm });
          }
          .width('100%')
          .height('100%')
          .scrollBar(BarState.Off)
          .scrollable(ScrollDirection.Vertical)
          .backgroundColor(this.palette().background);

          if (this.vm.homeState.actionMessage) {
            Column() {
              this.homeActionBanner();
            }
            .width('100%')
            .padding({ left: AppConstants.PAGE_HORIZONTAL_PADDING, right: AppConstants.PAGE_HORIZONTAL_PADDING, top: 20 })
            .alignItems(HorizontalAlign.Center);
          }
        }
        .width('100%')
        .height('100%')
        .backgroundColor(this.palette().background);
      }
      .tabBar(this.tabLabel(0, '首页'));

      TabContent() {
        LibraryPage({ vm: this.vm })
        .backgroundColor(this.palette().background);
      }
      .tabBar(this.tabLabel(1, '收藏库'));

      TabContent() {
        ChatPage({ vm: this.vm })
        .backgroundColor(this.palette().background);
      }
      .tabBar(this.tabLabel(2, '对话'));

      TabContent() {
        SettingsPage({ vm: this.vm })
        .backgroundColor(this.palette().background);
      }
      .tabBar(this.tabLabel(3, '设置'));
    }
    .barHeight(AppConstants.TAB_BAR_HEIGHT)
    .barBackgroundColor(this.palette().surface)
    .scrollable(false)
    .onChange((index: number) => {
      this.selectTab(index);
    })
    .onAppear(() => {
      this.applyThemeMode();
    })
    .width('100%')
    .height('100%')
    .backgroundColor(this.palette().background);
  }
}

interface ColorModeConfig {
  colorMode?: string | number;
}

interface ContextWithColorMode extends Context {
  setColorMode(colorMode: number): void;
  config?: ColorModeConfig;
}
