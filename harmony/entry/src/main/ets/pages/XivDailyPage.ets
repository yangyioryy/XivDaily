import AppConstants from '../common/constants/AppConstants';
import Context from '@ohos.app.ability.application';
import ConfigurationConstant from '@ohos.app.ability.ConfigurationConstant';
import { AppViewModel } from '../viewmodel/AppViewModel';
import { ChatPage } from '../view/ChatPage';
import { HomePage } from '../view/HomePage';
import { LibraryPage } from '../view/LibraryPage';
import { SettingsPage } from '../view/SettingsPage';

@Entry
@Component
struct XivDailyPage {
  @State vm: AppViewModel = new AppViewModel();
  private homeScroller: Scroller = new Scroller();
  private libraryScroller: Scroller = new Scroller();
  private chatScroller: Scroller = new Scroller();

  aboutToAppear(): void {
    this.applyThemeMode();
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

  @Builder
  private tabIcon(index: number) {
    if (index === 0) {
      SymbolGlyph($r('sys.symbol.house'))
        .fontSize(20)
        .fontColor([this.vm.selectedTab === index ? '#2D6CE8' : '#6B7280']);
    } else if (index === 1) {
      SymbolGlyph($r('sys.symbol.bookmark'))
        .fontSize(20)
        .fontColor([this.vm.selectedTab === index ? '#2D6CE8' : '#6B7280']);
    } else if (index === 2) {
      SymbolGlyph($r('sys.symbol.paperplane'))
        .fontSize(20)
        .fontColor([this.vm.selectedTab === index ? '#2D6CE8' : '#6B7280']);
    } else {
      SymbolGlyph($r('sys.symbol.square_grid_2x2'))
        .fontSize(20)
        .fontColor([this.vm.selectedTab === index ? '#2D6CE8' : '#6B7280']);
    }
  }

  @Builder
  private tabLabel(index: number, label: string) {
    Column({ space: 4 }) {
      Stack({ alignContent: Alignment.Center }) {
        Row()
          .width(38)
          .height(28)
          .backgroundColor(this.vm.selectedTab === index ? '#DCEBFF' : '#00000000')
          .borderRadius(14);
        this.tabIcon(index);
      }
      .width(38)
      .height(28);
      Text(label)
        .fontSize(12)
        .fontWeight(this.vm.selectedTab === index ? FontWeight.Medium : FontWeight.Regular)
        .fontColor(this.vm.selectedTab === index ? '#2D6CE8' : '#6B7280');
    }
    .width('100%')
    .height(AppConstants.TAB_BAR_HEIGHT)
    .justifyContent(FlexAlign.Center);
  }

  build() {
    Tabs({ barPosition: BarPosition.End, index: this.vm.selectedTab }) {
      TabContent() {
        Scroll(this.homeScroller) {
          HomePage({ vm: this.vm });
        }
        .scrollBar(BarState.Off)
        .scrollable(ScrollDirection.Vertical)
        .backgroundColor('#F7F9FD');
      }
      .tabBar(this.tabLabel(0, '首页'));

      TabContent() {
        Scroll(this.libraryScroller) {
          LibraryPage({ vm: this.vm });
        }
        .scrollBar(BarState.Off)
        .scrollable(ScrollDirection.Vertical)
        .backgroundColor('#F7F9FD');
      }
      .tabBar(this.tabLabel(1, '收藏库'));

      TabContent() {
        Scroll(this.chatScroller) {
          ChatPage({ vm: this.vm });
        }
        .scrollBar(BarState.Off)
        .scrollable(ScrollDirection.Vertical)
        .backgroundColor('#F7F9FD');
      }
      .tabBar(this.tabLabel(2, '对话'));

      TabContent() {
        SettingsPage({ vm: this.vm })
        .backgroundColor('#F7F9FD');
      }
      .tabBar(this.tabLabel(3, '设置'));
    }
    .barHeight(AppConstants.TAB_BAR_HEIGHT)
    .barBackgroundColor('#F4F8FF')
    .scrollable(false)
    .onChange((index: number) => {
      this.vm.selectTab(index);
    })
    .onAppear(() => {
      this.applyThemeMode();
    })
    .width('100%')
    .height('100%')
    .backgroundColor('#F7F9FD');
  }
}

interface ColorModeHostContext {
  setColorMode(colorMode: number): void;
}

interface ContextWithColorMode extends Context {
  setColorMode(colorMode: number): void;
}
