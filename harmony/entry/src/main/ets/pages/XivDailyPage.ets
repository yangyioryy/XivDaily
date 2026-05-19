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
      SymbolGlyph($r(this.vm.selectedTab === index ? 'sys.symbol.house_fill' : 'sys.symbol.house'))
        .fontSize(19)
        .fontColor([this.vm.selectedTab === index ? '#2D6CE8' : '#6B7280']);
    } else if (index === 1) {
      SymbolGlyph($r(this.vm.selectedTab === index ? 'sys.symbol.bookmark_fill' : 'sys.symbol.bookmark'))
        .fontSize(19)
        .fontColor([this.vm.selectedTab === index ? '#2D6CE8' : '#6B7280']);
    } else if (index === 2) {
      SymbolGlyph($r(this.vm.selectedTab === index ? 'sys.symbol.paperplane_fill' : 'sys.symbol.paperplane'))
        .fontSize(19)
        .fontColor([this.vm.selectedTab === index ? '#2D6CE8' : '#6B7280']);
    } else {
      SymbolGlyph($r(this.vm.selectedTab === index ? 'sys.symbol.gearshape_fill' : 'sys.symbol.gearshape'))
        .fontSize(19)
        .fontColor([this.vm.selectedTab === index ? '#2D6CE8' : '#6B7280']);
    }
  }

  @Builder
  private tabLabel(index: number, label: string) {
    Column({ space: 5 }) {
      Stack({ alignContent: Alignment.Center }) {
        Row()
          .width(42)
          .height(30)
          .backgroundColor(this.vm.selectedTab === index ? '#DCEBFF' : '#00000000')
          .borderRadius(15);
        this.tabIcon(index);
      }
      .width(42)
      .height(30);
      Text(label)
        .fontSize(12)
        .fontWeight(this.vm.selectedTab === index ? FontWeight.Bold : FontWeight.Medium)
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
    .barBackgroundColor('#FFFFFF')
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
