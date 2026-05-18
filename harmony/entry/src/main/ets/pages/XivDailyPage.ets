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
  private tabLabel(index: number, icon: string, label: string) {
    Column({ space: 4 }) {
      Text(icon)
        .fontSize(20)
        .fontColor(this.vm.selectedTab === index ? '#2D6CE8' : '#6B7280');
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
        Scroll() {
          HomePage({ vm: this.vm });
        }
        .scrollBar(BarState.Off)
        .backgroundColor('#F7F9FD');
      }
      .tabBar(this.tabLabel(0, '✦', '首页'));

      TabContent() {
        Scroll() {
          LibraryPage({ vm: this.vm });
        }
        .scrollBar(BarState.Off)
        .backgroundColor('#F7F9FD');
      }
      .tabBar(this.tabLabel(1, '▣', '收藏库'));

      TabContent() {
        Scroll() {
          ChatPage({ vm: this.vm });
        }
        .scrollBar(BarState.Off)
        .backgroundColor('#F7F9FD');
      }
      .tabBar(this.tabLabel(2, '➤', '对话'));

      TabContent() {
        Scroll() {
          SettingsPage({ vm: this.vm });
        }
        .scrollBar(BarState.Off)
        .backgroundColor('#F7F9FD');
      }
      .tabBar(this.tabLabel(3, '☷', '设置'));
    }
    .barHeight(AppConstants.TAB_BAR_HEIGHT)
    .barBackgroundColor('#EAF2FF')
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
