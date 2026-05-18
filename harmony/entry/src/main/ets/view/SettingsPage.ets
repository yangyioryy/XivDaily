import AppConstants from '../common/constants/AppConstants';
import { AppViewModel } from '../viewmodel/AppViewModel';

@Component
export struct SettingsPage {
  @ObjectLink vm: AppViewModel;

  @Builder
  private sectionCard(title: string, content: () => void) {
    Column({ space: 12 }) {
      Text(title)
        .fontSize(18)
        .fontWeight(FontWeight.Medium)
        .fontColor('#6B7280')
        .width('100%');
      Column({ space: 0 }) {
        content();
      }
      .width('100%')
      .backgroundColor('#FFFFFF')
      .borderRadius(20);
    }
    .width('100%');
  }

  @Builder
  private settingRow(icon: string, title: string, subtitle: string, value?: string, action?: () => void) {
    Row({ space: 12 }) {
      Text(icon)
        .fontSize(18)
        .width(32)
        .height(32)
        .textAlign(TextAlign.Center)
        .backgroundColor('#F1F4FA')
        .borderRadius(10);
      Column({ space: 2 }) {
        Text(title)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor('#111827');
        Text(subtitle)
          .fontSize(13)
          .fontColor('#6B7280');
      }
      .layoutWeight(1);
      if (value !== undefined) {
        Text(value)
          .fontSize(14)
          .fontColor('#6B7280');
      }
      Text('›')
        .fontSize(18)
        .fontColor('#6B7280');
    }
    .width('100%')
    .padding(16)
    .onClick(() => {
      if (action) {
        action();
      }
    });
  }

  build() {
    Column({ space: AppConstants.SECTION_SPACING }) {
      Text('设置')
        .fontSize(28)
        .fontWeight(FontWeight.Bold)
        .fontColor('#111827')
        .width('100%');

      Row({ space: 14 }) {
        Text(this.vm.settingsState.displayName.slice(0, 1))
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .fontColor('#FFFFFF')
          .width(56)
          .height(56)
          .textAlign(TextAlign.Center)
          .backgroundColor('#0F7A95')
          .borderRadius(28);
        Column({ space: 2 }) {
          Text(this.vm.settingsState.displayName)
            .fontSize(18)
            .fontWeight(FontWeight.Medium)
            .fontColor('#111827');
          Text('本地研究档案 · Harmony 前端正在持续完善')
            .fontSize(13)
            .fontColor('#6B7280');
        }
        .layoutWeight(1);
        Text('›')
          .fontSize(18)
          .fontColor('#6B7280');
      }
      .width('100%')
      .padding(16)
      .backgroundColor('#FFFFFF')
      .borderRadius(20);

      if (this.vm.settingsState.actionMessage) {
        Text(this.vm.settingsState.actionMessage!)
          .fontSize(13)
          .fontColor('#2D6CE8')
          .padding(12)
          .backgroundColor('#EAF2FF')
          .borderRadius(14);
      }

      if (this.vm.settingsState.errorMessage) {
        Text(this.vm.settingsState.errorMessage!)
          .fontSize(13)
          .fontColor('#B6544A')
          .padding(12)
          .backgroundColor('#FFEAEA')
          .borderRadius(14);
      }

      this.sectionCard('偏好设置', () => {
        this.settingRow('◧', '默认关注领域', '点击切换到下一个默认领域', this.vm.settingsState.defaultCategory, () => {
          const categories = ['cs.CV', 'cs.LG', 'cs.AI', 'cs.CL'];
          const currentIndex = categories.indexOf(this.vm.settingsState.defaultCategory);
          const nextIndex = currentIndex >= categories.length - 1 ? 0 : currentIndex + 1;
          this.vm.updateDefaultCategory(categories[nextIndex]);
        });
        this.settingRow('◷', '默认时间窗口', '点击切换时间窗口', `${this.vm.settingsState.defaultDays} 天`, () => {
          const options = [1, 3, 7, 30];
          const currentIndex = options.indexOf(this.vm.settingsState.defaultDays);
          const nextIndex = currentIndex >= options.length - 1 ? 0 : currentIndex + 1;
          this.vm.updateDefaultDays(options[nextIndex]);
        });
        this.settingRow('🌐', '语言', '文章摘要与界面默认语言', this.vm.settingsState.language);
      });

      this.sectionCard('集成配置', () => {
        this.settingRow(
          '⚗',
          'Zotero 配置',
          `归档到 Zotero Web 集合 ${this.vm.settingsState.zoteroTargetCollectionName}`,
          this.vm.settingsState.zoteroConfigured ? '已配置' : '未配置'
        );
        this.settingRow(
          '✦',
          '大模型配置',
          '摘要翻译与趋势总结能力',
          this.vm.settingsState.llmConfigured ? '已启用' : '未启用'
        );
      });

      this.sectionCard('外观', () => {
        this.settingRow('☾', '主题模式', '支持浅色、深色与跟随系统', this.vm.settingsState.themeMode);
        this.settingRow('A', '字体大小', '当前版本采用统一阅读字号体系', '标准');
      });
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding({ left: AppConstants.PAGE_HORIZONTAL_PADDING, right: AppConstants.PAGE_HORIZONTAL_PADDING, top: 20, bottom: 20 });
  }
}
