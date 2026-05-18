import AppConstants from '../common/constants/AppConstants';
import Context from '@ohos.app.ability.application';
import ConfigurationConstant from '@ohos.app.ability.ConfigurationConstant';
import { AppViewModel } from '../viewmodel/AppViewModel';

@Component
export struct SettingsPage {
  @ObjectLink vm: AppViewModel;
  @State private isProfileEditorVisible: boolean = false;
  @State private profileNameDraft: string = '';
  @State private profileAvatarDraft: string = 'study';

  private applyThemeMode(themeMode: string): void {
    const uiContext = this.getUIContext();
    const hostContext = uiContext.getHostContext();
    if (!hostContext) {
      return;
    }
    const abilityContext = hostContext as ContextWithColorMode;
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

  private themeModeLabel(): string {
    if (this.vm.settingsState.themeMode === 'dark') {
      return '深色';
    }
    if (this.vm.settingsState.themeMode === 'light') {
      return '浅色';
    }
    return '跟随系统';
  }

  private languageLabel(): string {
    if (this.vm.settingsState.language === 'en-US') {
      return 'English';
    }
    return '简体中文';
  }

  private zoteroSubtitle(): string {
    if (this.vm.settingsState.zoteroConfigured) {
      return `归档到 Zotero Web 集合 ${this.vm.settingsState.zoteroTargetCollectionName}`;
    }
    return '归档到 Zotero Web 集合';
  }

  private zoteroValue(): string {
    return this.vm.settingsState.zoteroConfigured ? '已配置' : '未配置';
  }

  private llmSubtitle(): string {
    return this.vm.settingsState.llmConfigured
      ? '摘要翻译与趋势总结可用'
      : '摘要翻译和总结暂不可用';
  }

  private llmValue(): string {
    return this.vm.settingsState.llmConfigured ? '已启用' : '未启用';
  }

  private avatarPresetLabel(value: string): string {
    if (value === 'spark') {
      return '灵感';
    }
    if (value === 'orbit') {
      return '探索';
    }
    return '学者';
  }

  private profileSubtitle(): string {
    if (this.vm.settingsState.avatarImageUri && this.vm.settingsState.avatarImageUri.length > 0) {
      return '本地研究档案 · 已使用本地图片头像';
    }
    return `本地研究档案 · ${this.avatarPresetLabel(this.vm.settingsState.avatarPreset)}`;
  }

  private showProfileEditor(): void {
    this.profileNameDraft = this.vm.settingsState.displayName;
    this.profileAvatarDraft = this.vm.settingsState.avatarPreset;
    this.isProfileEditorVisible = true;
  }

  private hideProfileEditor(): void {
    this.isProfileEditorVisible = false;
  }

  private saveProfileEditor(): void {
    this.vm.updateProfile(this.profileNameDraft, this.profileAvatarDraft);
    this.isProfileEditorVisible = false;
  }

  @Builder
  private sectionTitle(title: string) {
    Text(title)
      .fontSize(18)
      .fontWeight(FontWeight.Medium)
      .fontColor('#6B7280')
      .width('100%');
  }

  @Builder
  private profileCard() {
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
        Row({ space: 6 }) {
          Text(this.vm.settingsState.displayName)
            .fontSize(18)
            .fontWeight(FontWeight.Medium)
            .fontColor('#111827');
          Text('✎')
            .fontSize(14)
            .fontColor('#6B7280');
        }
        Text(this.profileSubtitle())
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
    .borderRadius(20)
    .onClick(() => this.showProfileEditor());
  }

  @Builder
  private chipGroup(values: string[], selectedValue: string, onSelect: (value: string) => void) {
    Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start, alignItems: ItemAlign.Center }) {
      ForEach(values, (value: string) => {
        Text(value)
          .fontSize(14)
          .fontWeight(selectedValue === value ? FontWeight.Medium : FontWeight.Regular)
          .fontColor(selectedValue === value ? '#1F2937' : '#6B7280')
          .padding({ left: 16, right: 16, top: 8, bottom: 8 })
          .margin({ right: 8, bottom: 8 })
          .backgroundColor(selectedValue === value ? '#F1F4FA' : '#FFFFFF')
          .borderRadius(12)
          .border({ width: 1, color: '#D7DEE9' })
          .onClick(() => onSelect(value));
      }, (value: string) => value);
    }
    .width('100%');
  }

  @Builder
  private numberChipGroup(values: number[], selectedValue: number, onSelect: (value: number) => void) {
    Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start, alignItems: ItemAlign.Center }) {
      ForEach(values, (value: number) => {
        Text(value === 1 ? '24h' : `${value} 天`)
          .fontSize(14)
          .fontWeight(selectedValue === value ? FontWeight.Medium : FontWeight.Regular)
          .fontColor(selectedValue === value ? '#1F2937' : '#6B7280')
          .padding({ left: 16, right: 16, top: 8, bottom: 8 })
          .margin({ right: 8, bottom: 8 })
          .backgroundColor(selectedValue === value ? '#F1F4FA' : '#FFFFFF')
          .borderRadius(12)
          .border({ width: 1, color: '#D7DEE9' })
          .onClick(() => onSelect(value));
      }, (value: number) => `${value}`);
    }
    .width('100%');
  }

  @Builder
  private settingRow(icon: string, title: string, subtitle: string, value?: string, action?: () => void, disabled: boolean = false) {
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
        .fontColor('#2D6CE8');
    }
    .width('100%')
    .opacity(disabled ? 0.55 : 1)
    .padding(16)
    .onClick(() => {
      if (!disabled && action) {
        action();
      }
    });
  }

  @Builder
  private formInput(label: string, text: string, placeholder: string, onChange: (value: string) => void) {
    Column({ space: 6 }) {
      Text(label)
        .fontSize(13)
        .fontColor('#6B7280')
        .width('100%');
      TextInput({
        placeholder: placeholder,
        text: text
      })
        .fontSize(15)
        .backgroundColor('#FFFFFF')
        .borderRadius(14)
        .border({ width: 1, color: '#D7DEE9' })
        .padding({ left: 14, right: 14, top: 12, bottom: 12 })
        .onChange((value: string) => onChange(value));
    }
    .width('100%');
  }

  @Builder
  private formActionButton(label: string, primary: boolean, disabled: boolean, action: () => void) {
    Text(label)
      .fontSize(14)
      .fontWeight(FontWeight.Medium)
      .fontColor(primary ? '#FFFFFF' : '#2D6CE8')
      .padding({ left: 18, right: 18, top: 10, bottom: 10 })
      .backgroundColor(primary ? '#2D6CE8' : '#EAF2FF')
      .borderRadius(14)
      .opacity(disabled ? 0.6 : 1)
      .onClick(() => {
        if (!disabled) {
          action();
        }
      });
  }

  @Builder
  private preferenceSection() {
    Column({ space: 16 }) {
      Column({ space: 12 }) {
        Row({ space: 12 }) {
          Text('◧')
            .fontSize(18)
            .width(32)
            .height(32)
            .textAlign(TextAlign.Center)
            .backgroundColor('#F1F4FA')
            .borderRadius(10);
          Column({ space: 2 }) {
            Text('默认关注领域')
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .fontColor('#111827');
            Text(this.vm.settingsState.defaultCategory)
              .fontSize(13)
              .fontColor('#6B7280');
          }
        }
        this.chipGroup(['cs.CV', 'cs.LG', 'cs.AI', 'cs.CL', 'nlp'], this.vm.settingsState.defaultCategory, (value: string) => {
          if (value !== 'nlp') {
            this.vm.updateDefaultCategory(value);
          }
        });
      }

      Divider().color('#EEF2F7');

      Column({ space: 12 }) {
        Row({ space: 12 }) {
          Text('◷')
            .fontSize(18)
            .width(32)
            .height(32)
            .textAlign(TextAlign.Center)
            .backgroundColor('#F1F4FA')
            .borderRadius(10);
          Column({ space: 2 }) {
            Text('默认时间窗口')
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .fontColor('#111827');
            Text(this.vm.settingsState.defaultDays === 1 ? '24h' : `${this.vm.settingsState.defaultDays} 天`)
              .fontSize(13)
              .fontColor('#6B7280');
          }
        }
        this.numberChipGroup([1, 3, 7, 30], this.vm.settingsState.defaultDays, (value: number) => this.vm.updateDefaultDays(value));
      }

      Divider().color('#EEF2F7');
      this.settingRow('🌐', '语言', '文章摘要与界面默认语言', this.languageLabel(), () => this.vm.showLanguagePicker());
    }
    .width('100%')
    .padding(16)
    .backgroundColor('#FFFFFF')
    .borderRadius(20);
  }

  @Builder
  private integrationSection() {
    Column({ space: 0 }) {
      this.settingRow('⚗', 'Zotero 配置', this.zoteroSubtitle(), this.zoteroValue(), () => this.vm.showZoteroDetailDialog());
      Divider().color('#EEF2F7');
      this.settingRow('✦', '大模型配置', this.llmSubtitle(), this.llmValue(), () => this.vm.showLlmDetailDialog());
    }
    .width('100%')
    .backgroundColor('#FFFFFF')
    .borderRadius(20);
  }

  @Builder
  private appearanceSection() {
    Column({ space: 0 }) {
      this.settingRow('☾', '主题模式', '支持浅色、深色与跟随系统', this.themeModeLabel(), () => this.vm.showThemePicker());
      Divider().color('#EEF2F7');
      this.settingRow('A', '字体大小', '当前版本采用统一阅读字号体系', '标准', undefined, true);
    }
    .width('100%')
    .backgroundColor('#FFFFFF')
    .borderRadius(20);
  }

  @Builder
  private otherSection() {
    Column({ space: 0 }) {
      this.settingRow('▣', '清除缓存', '清理本地缓存的列表与摘要内容', this.vm.settingsState.cacheStatusText, () => this.vm.showClearCacheDialog());
      Divider().color('#EEF2F7');
      this.settingRow('↻', '检查更新', '查看当前版本与后续更新说明', 'v0.1.0', () => this.vm.showUpdateDialog());
      Divider().color('#EEF2F7');
      this.settingRow('i', '关于我们', '了解 XivDaily 的定位与版本信息', undefined, () => this.vm.showAboutDialog());
    }
    .width('100%')
    .backgroundColor('#FFFFFF')
    .borderRadius(20);
  }

  @Builder
  private themePickerCard() {
    if (this.vm.settingsState.isThemePickerVisible) {
      Column({ space: 10 }) {
        Text('选择主题模式')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor('#111827');
        this.settingRow('✦', '跟随系统', '当前已选中则不会主动覆盖系统主题', undefined, () => {
          this.vm.selectThemeMode('system');
          this.applyThemeMode('system');
        });
        Divider().color('#EEF2F7');
        this.settingRow('☀', '浅色', '点击切换到浅色主题', undefined, () => {
          this.vm.selectThemeMode('light');
          this.applyThemeMode('light');
        });
        Divider().color('#EEF2F7');
        this.settingRow('☾', '深色', '点击切换到深色主题', undefined, () => {
          this.vm.selectThemeMode('dark');
          this.applyThemeMode('dark');
        });
        Row() {
          Blank();
          this.formActionButton('关闭', false, false, () => this.vm.hideThemePicker());
        }
        .width('100%');
      }
      .width('100%')
      .padding(16)
      .backgroundColor('#FFFFFF')
      .borderRadius(20);
    }
  }

  @Builder
  private languagePickerCard() {
    if (this.vm.settingsState.isLanguagePickerVisible) {
      Column({ space: 10 }) {
        Text('选择语言')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor('#111827');
        this.settingRow('🌐', '简体中文', '点击切换到简体中文', undefined, () => this.vm.selectLanguage('zh-CN'));
        Row() {
          Blank();
          this.formActionButton('关闭', false, false, () => this.vm.hideLanguagePicker());
        }
        .width('100%');
      }
      .width('100%')
      .padding(16)
      .backgroundColor('#FFFFFF')
      .borderRadius(20);
    }
  }

  @Builder
  private zoteroDialogCard() {
    if (this.vm.settingsState.isZoteroDetailDialogVisible) {
      Column({ space: 12 }) {
        Text('Zotero 配置')
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .fontColor('#111827');
        Text(`当前集合：${this.vm.settingsState.zoteroTargetCollectionName}`)
          .fontSize(13)
          .fontColor('#6B7280');
        this.formInput('User ID / Group ID', this.vm.settingsState.zoteroUserIdDraft, '输入用户或群组 ID', (value: string) => {
          this.vm.updateZoteroUserIdDraft(value);
        });
        this.formInput('Library Type', this.vm.settingsState.zoteroLibraryTypeDraft, 'user / group', (value: string) => {
          this.vm.updateZoteroLibraryTypeDraft(value);
        });
        this.formInput('API Key', this.vm.settingsState.zoteroApiKeyDraft, this.vm.settingsState.zoteroApiKeyMasked ?? '保存后仅脱敏显示', (value: string) => {
          this.vm.updateZoteroApiKeyDraft(value);
        });
        this.formInput('目标集合名称', this.vm.settingsState.zoteroTargetCollectionNameDraft, 'XivDaily', (value: string) => {
          this.vm.updateZoteroCollectionDraft(value);
        });
        Row({ space: 8 }) {
          this.formActionButton('测试', false, this.vm.settingsState.isConfigBusy, () => {
            void this.vm.testZoteroConfig();
          });
          this.formActionButton(this.vm.settingsState.isConfigBusy ? '保存中...' : '保存', true, this.vm.settingsState.isConfigBusy, () => {
            void this.vm.saveZoteroConfig();
          });
          Blank();
          this.formActionButton('取消', false, false, () => this.vm.hideZoteroDetailDialog());
        }
        .width('100%');
      }
      .width('100%')
      .padding(16)
      .backgroundColor('#FFFFFF')
      .borderRadius(20);
    }
  }

  @Builder
  private llmDialogCard() {
    if (this.vm.settingsState.isLlmDetailDialogVisible) {
      Column({ space: 12 }) {
        Text('大模型 API 配置')
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .fontColor('#111827');
        this.formInput('Base URL', this.vm.settingsState.llmBaseUrlDraft, 'https://...', (value: string) => {
          this.vm.updateLlmBaseUrlDraft(value);
        });
        this.formInput('Model', this.vm.settingsState.llmModelDraft, 'grok-4.20-0309-non-reasoning', (value: string) => {
          this.vm.updateLlmModelDraft(value);
        });
        this.formInput('API Key', this.vm.settingsState.llmApiKeyDraft, this.vm.settingsState.llmApiKeyMasked ?? '保存后仅脱敏显示', (value: string) => {
          this.vm.updateLlmApiKeyDraft(value);
        });
        Row({ space: 8 }) {
          this.formActionButton('测试', false, this.vm.settingsState.isConfigBusy, () => {
            void this.vm.testLlmConfig();
          });
          this.formActionButton(this.vm.settingsState.isConfigBusy ? '保存中...' : '保存', true, this.vm.settingsState.isConfigBusy, () => {
            void this.vm.saveLlmConfig();
          });
          Blank();
          this.formActionButton('取消', false, false, () => this.vm.hideLlmDetailDialog());
        }
        .width('100%');
      }
      .width('100%')
      .padding(16)
      .backgroundColor('#FFFFFF')
      .borderRadius(20);
    }
  }

  @Builder
  private otherDialogs() {
    if (this.isProfileEditorVisible) {
      Column({ space: 12 }) {
        Text('编辑个人资料')
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .fontColor('#111827');
        this.formInput('用户名', this.profileNameDraft, 'XivDaily Reader', (value: string) => {
          this.profileNameDraft = value;
        });
        Text('头像预设')
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor('#374151')
          .width('100%');
        this.chipGroup(['study', 'spark', 'orbit'], this.profileAvatarDraft, (value: string) => {
          this.profileAvatarDraft = value;
        });
        Text('当前版本先支持预设头像；本地图片上传仍待补齐。')
          .fontSize(13)
          .fontColor('#6B7280');
        Row({ space: 8 }) {
          this.formActionButton('保存', true, false, () => this.saveProfileEditor());
          this.formActionButton('取消', false, false, () => this.hideProfileEditor());
        }
        .width('100%');
      }
      .width('100%')
      .padding(16)
      .backgroundColor('#FFFFFF')
      .borderRadius(20);
    }

    if (this.vm.settingsState.isAboutDialogVisible) {
      Column({ space: 10 }) {
        Text('关于 XivDaily')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor('#111827');
        Text('XivDaily 是面向研究阅读场景的每日论文工作台。当前版本聚焦首页流、收藏同步和趋势摘要体验。')
          .fontSize(14)
          .lineHeight(22)
          .fontColor('#374151');
        Row() {
          Blank();
          this.formActionButton('关闭', false, false, () => this.vm.hideAboutDialog());
        }
        .width('100%');
      }
      .width('100%')
      .padding(16)
      .backgroundColor('#FFFFFF')
      .borderRadius(20);
    }

    if (this.vm.settingsState.isUpdateDialogVisible) {
      Column({ space: 10 }) {
        Text('检查更新')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor('#111827');
        Text('当前版本：v0.1.0\n最新版本：v0.1.0\n更新时间：今天\n当前已经是最新版本。')
          .fontSize(14)
          .lineHeight(22)
          .fontColor('#374151');
        Row() {
          Blank();
          this.formActionButton('关闭', false, false, () => this.vm.hideUpdateDialog());
        }
        .width('100%');
      }
      .width('100%')
      .padding(16)
      .backgroundColor('#FFFFFF')
      .borderRadius(20);
    }

    if (this.vm.settingsState.isClearCacheDialogVisible) {
      Column({ space: 10 }) {
        Text('确认清理缓存')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor('#111827');
        Text('将清理首页列表与趋势提示缓存反馈，不影响收藏库与偏好设置。')
          .fontSize(14)
          .lineHeight(22)
          .fontColor('#374151');
        Row({ space: 8 }) {
          this.formActionButton('开始清理', true, false, () => this.vm.clearCache());
          this.formActionButton('取消', false, false, () => this.vm.hideClearCacheDialog());
        }
        .width('100%');
      }
      .width('100%')
      .padding(16)
      .backgroundColor('#FFFFFF')
      .borderRadius(20);
    }
  }

  build() {
    Column({ space: AppConstants.SECTION_SPACING }) {
      Text('设置')
        .fontSize(28)
        .fontWeight(FontWeight.Bold)
        .fontColor('#111827')
        .width('100%');

      this.profileCard();

      this.sectionTitle('偏好设置');
      this.preferenceSection();

      this.sectionTitle('集成配置');
      this.integrationSection();

      this.sectionTitle('外观');
      this.appearanceSection();

      this.sectionTitle('其他');
      this.otherSection();

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

      Text('刷新配置状态')
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor('#2D6CE8')
        .width('100%')
        .textAlign(TextAlign.Center)
        .padding({ top: 14, bottom: 14 })
        .backgroundColor('#FFFFFF')
        .borderRadius(16)
        .onClick(() => {
          void this.vm.refreshIntegrationStatusAction();
        });

      this.themePickerCard();
      this.languagePickerCard();
      this.zoteroDialogCard();
      this.llmDialogCard();
      this.otherDialogs();
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding({ left: AppConstants.PAGE_HORIZONTAL_PADDING, right: AppConstants.PAGE_HORIZONTAL_PADDING, top: 20, bottom: 20 });
  }
}

interface ColorModeHostContext {
  setColorMode(colorMode: number): void;
}

interface ContextWithColorMode extends Context {
  setColorMode(colorMode: number): void;
}
