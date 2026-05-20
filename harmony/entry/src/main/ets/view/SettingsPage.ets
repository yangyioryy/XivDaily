import AppConstants from '../common/constants/AppConstants';
import Context from '@ohos.app.ability.application';
import ConfigurationConstant from '@ohos.app.ability.ConfigurationConstant';
import bundleManager from '@ohos.bundle.bundleManager';
import photoAccessHelper from '@ohos.file.photoAccessHelper';
import { resolveXivPalette, XivThemePalette } from '../common/theme/XivTheme';
import { AppViewModel } from '../viewmodel/AppViewModel';

const FALLBACK_APP_VERSION_NAME: string = '0.1.0';

function resolveAppVersionName(): string {
  try {
    return bundleManager.getBundleInfoForSelfSync(bundleManager.BundleFlag.GET_BUNDLE_INFO_DEFAULT).versionName;
  } catch (error) {
    return FALLBACK_APP_VERSION_NAME;
  }
}

@Component
export struct SettingsPage {
  @ObjectLink vm: AppViewModel;
  private pageScroller: Scroller = new Scroller();
  private readonly appVersionName: string = resolveAppVersionName();
  @State private isProfileEditorVisible: boolean = false;
  @State private profileNameDraft: string = '';
  @State private profileAvatarDraft: string = 'study';
  @State private profileAvatarImageUriDraft?: string = undefined;

  private readSystemColorMode(): string | number | undefined {
    try {
      const hostContext = this.getUIContext().getHostContext() as ContextWithColorMode | undefined;
      return hostContext?.config?.colorMode;
    } catch (error) {
      return undefined;
    }
  }

  private palette(): XivThemePalette {
    return resolveXivPalette(this.vm.settingsState.themeMode, this.readSystemColorMode());
  }

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
    return this.integrationSubtitle(
      this.vm.settingsState.zoteroConfigured,
      `归档到 Zotero Web 集合 ${this.vm.settingsState.zoteroTargetCollectionName}`,
      '尚未连接参考文献库'
    );
  }

  private zoteroValue(): string {
    return this.zoteroCollectionBadge();
  }

  private llmSubtitle(): string {
    return this.integrationSubtitle(
      this.vm.settingsState.llmConfigured,
      '摘要翻译与趋势总结可用',
      '摘要翻译和总结暂不可用'
    );
  }

  private llmValue(): string {
    return this.vm.settingsState.llmConfigured ? '已启用' : '未启用';
  }

  private integrationSubtitle(configured: boolean, successText: string, idleText: string): string {
    if (this.vm.settingsState.integrationStatusFailed) {
      return '状态刷新异常，请稍后重试';
    }
    return configured ? successText : idleText;
  }

  private zoteroCollectionBadge(): string {
    if (this.vm.settingsState.zoteroTargetCollectionStatus === 'created') {
      return '已创建';
    }
    if (this.vm.settingsState.zoteroTargetCollectionStatus === 'ready') {
      return '已就绪';
    }
    if (this.vm.settingsState.zoteroTargetCollectionStatus === 'error') {
      return '异常';
    }
    if (this.vm.settingsState.zoteroTargetCollectionStatus === 'not_configured') {
      return '未配置';
    }
    return '待确认';
  }

  private integrationStatusText(configured: boolean): string {
    if (this.vm.settingsState.integrationStatusFailed) {
      return '异常';
    }
    return configured ? '已配置' : '未配置';
  }

  private integrationStatusColor(configured: boolean): string {
    if (this.vm.settingsState.integrationStatusFailed) {
      return this.palette().danger;
    }
    return configured ? this.palette().success : this.palette().warning;
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

  private avatarPresetGlyph(value: string): string {
    if (value === 'spark') {
      return '灵';
    }
    if (value === 'orbit') {
      return '研';
    }
    return '学';
  }

  private avatarPresetSubtitle(value: string): string {
    if (value === 'spark') {
      return '保持研究灵感在线';
    }
    if (value === 'orbit') {
      return '围绕主题持续追踪';
    }
    return '保持每日研究敏感度';
  }

  private zoteroLibraryTypeLabel(value?: string): string {
    if (value === 'group') {
      return '群组库';
    }
    if (value === 'user') {
      return '个人库';
    }
    return '未知';
  }

  private zoteroDetailMessage(): string {
    let message = `配置状态：${this.integrationStatusText(this.vm.settingsState.zoteroConfigured)}\n同步位置：Zotero Web API 集合，不是本机 D:\\Zotero 文件夹\n目标集合：${this.vm.settingsState.zoteroTargetCollectionName}\n集合状态：${this.zoteroCollectionBadge()}\n库类型：${this.zoteroLibraryTypeLabel(this.vm.settingsState.zoteroLibraryType)}\n用户 ID：${this.vm.settingsState.zoteroUserId ?? '未提供'}`;
    if (this.vm.settingsState.zoteroTargetCollectionKey && this.vm.settingsState.zoteroTargetCollectionKey.length > 0) {
      message = `${message}\n集合 Key：${this.vm.settingsState.zoteroTargetCollectionKey}`;
    }
    return message;
  }

  private defaultCategoryOptions(): string[] {
    const options = ['cs.CV', 'cs.LG', 'cs.AI', 'cs.CL'].concat(this.vm.settingsState.customTags);
    return Array.from(new Set(options));
  }

  private profileSubtitle(): string {
    if (this.vm.settingsState.avatarImageUri && this.vm.settingsState.avatarImageUri.length > 0) {
      return '本地研究档案 · 已使用本地图片头像';
    }
    return `本地研究档案 · ${this.avatarPresetSubtitle(this.vm.settingsState.avatarPreset)}`;
  }

  private appVersionLabel(): string {
    return `v${this.appVersionName}`;
  }

  private updateDialogMessage(): string {
    return `当前版本：${this.appVersionLabel()}\n最新版本：${this.appVersionLabel()}\n更新时间：今天\n当前已经是最新版本。`;
  }

  private aboutDialogMessage(): string {
    return 'XivDaily 是面向研究阅读场景的每日论文工作台。\n当前版本聚焦首页流、收藏同步和趋势摘要体验。';
  }

  private showProfileEditor(): void {
    this.profileNameDraft = this.vm.settingsState.displayName;
    this.profileAvatarDraft = this.vm.settingsState.avatarPreset;
    this.profileAvatarImageUriDraft = this.vm.settingsState.avatarImageUri;
    this.isProfileEditorVisible = true;
  }

  private hideProfileEditor(): void {
    this.isProfileEditorVisible = false;
  }

  private saveProfileEditor(): void {
    this.vm.updateProfile(this.profileNameDraft, this.profileAvatarDraft, this.profileAvatarImageUriDraft);
    this.isProfileEditorVisible = false;
  }

  private showToast(message: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({
        message: message
      });
    } catch (error) {
    }
  }

  private async pickProfileAvatar(): Promise<void> {
    try {
      const photoPicker = new photoAccessHelper.PhotoViewPicker();
      const options = new photoAccessHelper.PhotoSelectOptions();
      options.MIMEType = photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE;
      options.maxSelectNumber = 1;
      const result = await photoPicker.select(options);
      const nextUri = result.photoUris[0];
      if (!nextUri) {
        return;
      }
      this.profileAvatarImageUriDraft = nextUri;
      this.showToast('已选择本地图片头像');
    } catch (error) {
      this.showToast('选择头像图片失败');
    }
  }

  private removeProfileAvatarImage(): void {
    this.profileAvatarImageUriDraft = undefined;
  }

  @Builder
  private leadingIcon(iconText: string, highlighted: boolean = false) {
    Text(iconText)
      .fontSize(16)
      .fontWeight(FontWeight.Medium)
      .fontColor(highlighted ? this.palette().primary : this.palette().textSecondary)
      .width(32)
      .height(32)
      .textAlign(TextAlign.Center)
      .backgroundColor(highlighted ? this.palette().primaryContainer : this.palette().secondaryContainer)
      .borderRadius(10);
  }

  @Builder
  private dialogBackdrop(onDismiss: () => void) {
    Row()
      .width('100%')
      .height('100%')
      .backgroundColor(this.palette().overlay)
      .onClick(() => onDismiss());
  }

  @Builder
  private sectionTitle(title: string) {
    Text(title)
      .fontSize(16)
      .fontWeight(FontWeight.Medium)
      .fontColor(this.palette().textSecondary)
      .width('100%');
  }

  @Builder
  private statusTag(label: string, color: string) {
    Row({ space: 6 }) {
      Row()
        .width(8)
        .height(8)
        .borderRadius(4)
        .backgroundColor(color);
      Text(label)
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.palette().textSecondary);
    }
    .padding({ left: 10, right: 10, top: 7, bottom: 7 })
    .backgroundColor(this.palette().surfaceSubtle)
    .borderRadius(12);
  }

  @Builder
  private profileCard() {
    Row({ space: 14 }) {
      Stack({ alignContent: Alignment.Center }) {
        if (this.vm.settingsState.avatarImageUri && this.vm.settingsState.avatarImageUri.length > 0) {
          Image(this.vm.settingsState.avatarImageUri)
            .width(56)
            .height(56)
            .borderRadius(28)
            .objectFit(ImageFit.Cover);
        } else {
          // 头像预设直接复用主色容器文字色，和 Android 端 ProfileCard 的 fallback 表现保持一致。
          Text(this.avatarPresetGlyph(this.vm.settingsState.avatarPreset))
            .fontSize(24)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.palette().onPrimaryContainer)
            .width(56)
            .height(56)
            .textAlign(TextAlign.Center)
            .borderRadius(28);
        }
      }
      .width(64)
      .height(64)
      .backgroundColor(this.palette().primaryContainer)
      .borderRadius(32)
      .border({ width: 1, color: this.palette().outline });

      Column({ space: 2 }) {
        Row({ space: 6 }) {
          Text(this.vm.settingsState.displayName)
            .fontSize(18)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.palette().textPrimary);
          Text('✎')
            .fontSize(14)
            .fontColor(this.palette().textSecondary);
        }
        Text(this.profileSubtitle())
          .fontSize(13)
          .fontColor(this.palette().textSecondary);
      }
      .layoutWeight(1);
      Text('›')
        .fontSize(18)
        .fontColor(this.palette().textSecondary);
    }
    .width('100%')
    .padding(16)
    .backgroundColor(this.palette().surface)
    .borderRadius(24)
    .border({ width: 1, color: this.palette().outline })
    .onClick(() => this.showProfileEditor());
  }

  @Builder
  private chipGroup(values: string[], selectedValue: string, onSelect: (value: string) => void,
    labelMapper: (value: string) => string = (value: string) => value) {
    Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start, alignItems: ItemAlign.Center }) {
      ForEach(values, (value: string) => {
        Text(labelMapper(value))
          .fontSize(14)
          .fontWeight(selectedValue === value ? FontWeight.Medium : FontWeight.Regular)
          .fontColor(selectedValue === value ? this.palette().textPrimary : this.palette().textSecondary)
          .padding({ left: 16, right: 16, top: 8, bottom: 8 })
          .margin({ right: 8, bottom: 8 })
          .backgroundColor(selectedValue === value ? this.palette().secondaryContainer : this.palette().surface)
          .borderRadius(12)
          .border({ width: 1, color: this.palette().outline })
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
          .fontColor(selectedValue === value ? this.palette().textPrimary : this.palette().textSecondary)
          .padding({ left: 16, right: 16, top: 8, bottom: 8 })
          .margin({ right: 8, bottom: 8 })
          .backgroundColor(selectedValue === value ? this.palette().secondaryContainer : this.palette().surface)
          .borderRadius(12)
          .border({ width: 1, color: this.palette().outline })
          .onClick(() => onSelect(value));
      }, (value: number) => `${value}`);
    }
    .width('100%');
  }

  @Builder
  private settingRow(icon: string, title: string, subtitle: string, value?: string, action?: () => void, disabled: boolean = false,
    highlighted: boolean = false) {
    Row({ space: 12 }) {
      this.leadingIcon(icon, highlighted);
      Column({ space: 2 }) {
        Text(title)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.palette().textPrimary);
        Text(subtitle)
          .fontSize(13)
          .fontColor(this.palette().textSecondary);
      }
      .layoutWeight(1);
      if (value !== undefined) {
        Text(value)
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.palette().textSecondary);
      }
      if (!disabled) {
        Text('›')
          .fontSize(18)
          .fontColor(action ? this.palette().primary : this.palette().textSecondary);
      }
    }
    .width('100%')
    .opacity(disabled ? 0.55 : 1)
    .padding({ left: 16, right: 16, top: 14, bottom: 14 })
    .onClick(() => {
      if (!disabled && action) {
        action();
      }
    });
  }

  @Builder
  private integrationSettingRow(icon: string, title: string, subtitle: string, value: string, configured: boolean, action: () => void) {
    Row({ space: 12 }) {
      this.leadingIcon(icon);
      Column({ space: 2 }) {
        Text(title)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.palette().textPrimary);
        Text(subtitle)
          .fontSize(13)
          .fontColor(this.palette().textSecondary);
      }
      .layoutWeight(1);

      Text(value)
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.palette().textSecondary);

      this.statusTag(this.integrationStatusText(configured), this.integrationStatusColor(configured));

      Text('›')
        .fontSize(18)
        .fontColor(this.palette().textSecondary);
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 14, bottom: 14 })
    .onClick(() => action());
  }

  @Builder
  private formInput(label: string, text: string, placeholder: string, onChange: (value: string) => void,
    isPassword: boolean = false) {
    Column({ space: 6 }) {
      Text(label)
        .fontSize(13)
        .fontColor(this.palette().textSecondary)
        .width('100%');
      TextInput({
        placeholder: placeholder,
        text: text
      })
        .fontSize(15)
        .fontColor(this.palette().textPrimary)
        .placeholderColor(this.palette().textSecondary)
        // API Key 输入要和 Android 一样默认遮蔽，避免在设置弹窗里直接明文暴露凭据。
        .type(isPassword ? InputType.Password : InputType.Normal)
        .showPasswordIcon(false)
        .showPassword(false)
        .backgroundColor(this.palette().surface)
        .borderRadius(14)
        .border({ width: 1, color: this.palette().outline })
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
      .fontColor(primary ? this.palette().onPrimary : this.palette().primary)
      .padding({ left: 18, right: 18, top: 10, bottom: 10 })
      .backgroundColor(primary ? this.palette().primary : this.palette().primaryContainer)
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
          this.leadingIcon('◧');
          Column({ space: 2 }) {
            Text('默认关注领域')
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.palette().textPrimary);
            Text(this.vm.settingsState.defaultCategory)
              .fontSize(13)
              .fontColor(this.palette().textSecondary);
          }
        }
        this.chipGroup(this.defaultCategoryOptions(), this.vm.settingsState.defaultCategory, (value: string) => {
          this.vm.updateDefaultCategory(value);
        });
      }

      Divider().color(this.palette().divider);

      Column({ space: 12 }) {
        Row({ space: 12 }) {
          this.leadingIcon('◷');
          Column({ space: 2 }) {
            Text('默认时间窗口')
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.palette().textPrimary);
            Text(this.vm.settingsState.defaultDays === 1 ? '24h' : `${this.vm.settingsState.defaultDays} 天`)
              .fontSize(13)
              .fontColor(this.palette().textSecondary);
          }
        }
        this.numberChipGroup([1, 3, 7, 30], this.vm.settingsState.defaultDays, (value: number) => this.vm.updateDefaultDays(value));
      }

      Divider().color(this.palette().divider);
      this.settingRow('🌐', '语言', '文章摘要与界面默认语言', this.languageLabel(), () => this.vm.showLanguagePicker());
    }
    .width('100%')
    .padding(18)
    .backgroundColor(this.palette().surface)
    .borderRadius(24)
    .border({ width: 1, color: this.palette().outline });
  }

  @Builder
  private integrationSection() {
    Column({ space: 0 }) {
      this.integrationSettingRow('⚗', 'Zotero 配置', this.zoteroSubtitle(), this.zoteroValue(),
        this.vm.settingsState.zoteroConfigured, () => this.vm.showZoteroDetailDialog());
      Divider().color(this.palette().divider);
      this.integrationSettingRow('✦', '大模型配置', this.llmSubtitle(), this.llmValue(),
        this.vm.settingsState.llmConfigured, () => this.vm.showLlmDetailDialog());
    }
    .width('100%')
    .backgroundColor(this.palette().surface)
    .borderRadius(24)
    .border({ width: 1, color: this.palette().outline });
  }

  @Builder
  private appearanceSection() {
    Column({ space: 0 }) {
      this.settingRow('☾', '主题模式', '支持浅色、深色与跟随系统', this.themeModeLabel(), () => this.vm.showThemePicker(), false, true);
      Divider().color(this.palette().divider);
      this.settingRow('A', '字体大小', '当前版本采用统一阅读字号体系', '标准', undefined, true);
    }
    .width('100%')
    .backgroundColor(this.palette().surface)
    .borderRadius(24)
    .border({ width: 1, color: this.palette().outline });
  }

  @Builder
  private otherSection() {
    Column({ space: 0 }) {
      this.settingRow('▣', '清除缓存', '清理本地缓存的列表与摘要内容', this.vm.settingsState.cacheStatusText, () => this.vm.showClearCacheDialog());
      Divider().color(this.palette().divider);
      this.settingRow('↻', '检查更新', '查看当前版本与后续更新说明', this.appVersionLabel(), () => this.vm.showUpdateDialog());
      Divider().color(this.palette().divider);
      this.settingRow('i', '关于我们', '了解 XivDaily 的定位与版本信息', undefined, () => this.vm.showAboutDialog());
    }
    .width('100%')
    .backgroundColor(this.palette().surface)
    .borderRadius(24)
    .border({ width: 1, color: this.palette().outline });
  }

  @Builder
  private themePickerCard() {
    if (this.vm.settingsState.isThemePickerVisible) {
      Stack({ alignContent: Alignment.Center }) {
        this.dialogBackdrop(() => this.vm.hideThemePicker());
        Column({ space: 10 }) {
          Text('选择主题模式')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.palette().textPrimary);
          this.settingRow(this.vm.settingsState.themeMode === 'system' ? '✦' : '›', '跟随系统',
            this.vm.settingsState.themeMode === 'system' ? '当前已选中' : '点击切换到该选项', undefined, () => {
            this.vm.selectThemeMode('system');
            this.applyThemeMode('system');
          }, false, this.vm.settingsState.themeMode === 'system');
          Divider().color(this.palette().divider);
          this.settingRow(this.vm.settingsState.themeMode === 'light' ? '✦' : '›', '浅色',
            this.vm.settingsState.themeMode === 'light' ? '当前已选中' : '点击切换到该选项', undefined, () => {
            this.vm.selectThemeMode('light');
            this.applyThemeMode('light');
          }, false, this.vm.settingsState.themeMode === 'light');
          Divider().color(this.palette().divider);
          this.settingRow(this.vm.settingsState.themeMode === 'dark' ? '✦' : '›', '深色',
            this.vm.settingsState.themeMode === 'dark' ? '当前已选中' : '点击切换到该选项', undefined, () => {
            this.vm.selectThemeMode('dark');
            this.applyThemeMode('dark');
          }, false, this.vm.settingsState.themeMode === 'dark');
          Row() {
            Blank();
            this.formActionButton('关闭', false, false, () => this.vm.hideThemePicker());
          }
          .width('100%');
        }
        .width('88%')
        .padding(16)
        .backgroundColor(this.palette().surface)
        .borderRadius(20)
        .border({ width: 1, color: this.palette().outline });
      }
      .width('100%')
      .height('100%');
    }
  }

  @Builder
  private languagePickerCard() {
    if (this.vm.settingsState.isLanguagePickerVisible) {
      Stack({ alignContent: Alignment.Center }) {
        this.dialogBackdrop(() => this.vm.hideLanguagePicker());
        Column({ space: 10 }) {
          Text('选择语言')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.palette().textPrimary);
          this.settingRow('✦', '简体中文', '当前已选中', undefined, () => this.vm.selectLanguage('zh-CN'), false, true);
          Row() {
            Blank();
            this.formActionButton('关闭', false, false, () => this.vm.hideLanguagePicker());
          }
          .width('100%');
        }
        .width('88%')
        .padding(16)
        .backgroundColor(this.palette().surface)
        .borderRadius(20)
        .border({ width: 1, color: this.palette().outline });
      }
      .width('100%')
      .height('100%');
    }
  }

  @Builder
  private zoteroDialogCard() {
    if (this.vm.settingsState.isZoteroDetailDialogVisible) {
      Stack({ alignContent: Alignment.Center }) {
        this.dialogBackdrop(() => this.vm.hideZoteroDetailDialog());
        Column({ space: 12 }) {
          Text('Zotero 配置')
            .fontSize(18)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.palette().textPrimary);
          Text(this.zoteroDetailMessage())
            .fontSize(13)
            .lineHeight(20)
            .fontColor(this.palette().onSecondaryContainer)
            .width('100%')
            .padding({ left: 12, right: 12, top: 10, bottom: 10 })
            .backgroundColor(this.palette().secondaryContainer)
            .borderRadius(16);
          Text(`当前集合：${this.vm.settingsState.zoteroTargetCollectionName}`)
            .fontSize(13)
            .fontColor(this.palette().textSecondary);
          this.formInput('User ID / Group ID', this.vm.settingsState.zoteroUserIdDraft, '输入用户或群组 ID', (value: string) => {
            this.vm.updateZoteroUserIdDraft(value);
          });
          Text('Library Type')
            .fontSize(13)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.palette().textTertiary);
          // 界面使用中文选项，但最终仍保存为 Zotero API 需要的 user / group 常量。
          this.chipGroup(['个人库', '群组库'],
            this.vm.settingsState.zoteroLibraryTypeDraft === 'group' ? '群组库' : '个人库',
            (value: string) => {
              this.vm.updateZoteroLibraryTypeDraft(value === '群组库' ? 'group' : 'user');
            });
          this.formInput('API Key', this.vm.settingsState.zoteroApiKeyDraft, this.vm.settingsState.zoteroApiKeyMasked ?? '保存后仅脱敏显示', (value: string) => {
            this.vm.updateZoteroApiKeyDraft(value);
          }, true);
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
        .width('88%')
        .padding(16)
        .backgroundColor(this.palette().surface)
        .borderRadius(20)
        .border({ width: 1, color: this.palette().outline });
      }
      .width('100%')
      .height('100%');
    }
  }

  @Builder
  private llmDialogCard() {
    if (this.vm.settingsState.isLlmDetailDialogVisible) {
      Stack({ alignContent: Alignment.Center }) {
        this.dialogBackdrop(() => this.vm.hideLlmDetailDialog());
        Column({ space: 12 }) {
          Text('大模型 API 配置')
            .fontSize(18)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.palette().textPrimary);
          this.formInput('Base URL', this.vm.settingsState.llmBaseUrlDraft, 'https://...', (value: string) => {
            this.vm.updateLlmBaseUrlDraft(value);
          });
          this.formInput('Model', this.vm.settingsState.llmModelDraft, 'grok-4.20-0309-non-reasoning', (value: string) => {
            this.vm.updateLlmModelDraft(value);
          });
          this.formInput('API Key', this.vm.settingsState.llmApiKeyDraft, this.vm.settingsState.llmApiKeyMasked ?? '保存后仅脱敏显示', (value: string) => {
            this.vm.updateLlmApiKeyDraft(value);
          }, true);
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
        .width('88%')
        .padding(16)
        .backgroundColor(this.palette().surface)
        .borderRadius(20)
        .border({ width: 1, color: this.palette().outline });
      }
      .width('100%')
      .height('100%');
    }
  }

  @Builder
  private otherDialogs() {
    if (this.isProfileEditorVisible) {
      Stack({ alignContent: Alignment.Center }) {
        this.dialogBackdrop(() => this.hideProfileEditor());
        Column({ space: 12 }) {
          Text('编辑个人资料')
            .fontSize(18)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.palette().textPrimary);
          this.formInput('用户名', this.profileNameDraft, 'XivDaily Reader', (value: string) => {
            this.profileNameDraft = value;
          });
          Text('头像预设')
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.palette().textTertiary)
            .width('100%');
          if (this.profileAvatarImageUriDraft && this.profileAvatarImageUriDraft.length > 0) {
            Image(this.profileAvatarImageUriDraft)
              .width(72)
              .height(72)
              .borderRadius(36)
              .objectFit(ImageFit.Cover);
          }
          // 头像预设显示中文标签，但内部仍保持和 Android 一致的 preset code，便于状态存储与回写。
          this.chipGroup(['study', 'spark', 'orbit'], this.profileAvatarDraft, (value: string) => {
            this.profileAvatarDraft = value;
          }, (value: string) => this.avatarPresetLabel(value));
          Row({ space: 8 }) {
            this.formActionButton(this.profileAvatarImageUriDraft ? '更换头像' : '上传头像', false, false, () => {
              void this.pickProfileAvatar();
            });
            this.formActionButton('移除图片', false, !this.profileAvatarImageUriDraft, () => this.removeProfileAvatarImage());
          }
          .width('100%');
          Text(this.profileAvatarImageUriDraft ? '已选择本地图片头像' : '未选择图片时使用头像预设')
            .fontSize(13)
            .fontColor(this.palette().textSecondary);
          Row({ space: 8 }) {
            this.formActionButton('保存', true, false, () => this.saveProfileEditor());
            this.formActionButton('取消', false, false, () => this.hideProfileEditor());
          }
          .width('100%');
        }
        .width('88%')
        .padding(16)
        .backgroundColor(this.palette().surface)
        .borderRadius(20)
        .border({ width: 1, color: this.palette().outline });
      }
      .width('100%')
      .height('100%');
    }

    if (this.vm.settingsState.isAboutDialogVisible) {
      Stack({ alignContent: Alignment.Center }) {
        this.dialogBackdrop(() => this.vm.hideAboutDialog());
        Column({ space: 10 }) {
          Text('关于 XivDaily')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.palette().textPrimary);
          Text(this.aboutDialogMessage())
            .fontSize(14)
            .lineHeight(22)
            .fontColor(this.palette().textTertiary);
          Row() {
            Blank();
            this.formActionButton('知道了', false, false, () => this.vm.hideAboutDialog());
          }
          .width('100%');
        }
        .width('88%')
        .padding(16)
        .backgroundColor(this.palette().surface)
        .borderRadius(20)
        .border({ width: 1, color: this.palette().outline });
      }
      .width('100%')
      .height('100%');
    }

    if (this.vm.settingsState.isUpdateDialogVisible) {
      Stack({ alignContent: Alignment.Center }) {
        this.dialogBackdrop(() => this.vm.hideUpdateDialog());
        Column({ space: 10 }) {
          Text('检查更新')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.palette().textPrimary);
          Text(this.updateDialogMessage())
            .fontSize(14)
            .lineHeight(22)
            .fontColor(this.palette().textTertiary);
          Row() {
            Blank();
            this.formActionButton('知道了', false, false, () => this.vm.hideUpdateDialog());
          }
          .width('100%');
        }
        .width('88%')
        .padding(16)
        .backgroundColor(this.palette().surface)
        .borderRadius(20)
        .border({ width: 1, color: this.palette().outline });
      }
      .width('100%')
      .height('100%');
    }

    if (this.vm.settingsState.isClearCacheDialogVisible) {
      Stack({ alignContent: Alignment.Center }) {
        this.dialogBackdrop(() => this.vm.hideClearCacheDialog());
        Column({ space: 10 }) {
          Text('确认清理缓存')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.palette().textPrimary);
          Text('将清理首页列表与趋势提示缓存反馈，不影响收藏库与偏好设置。')
            .fontSize(14)
            .lineHeight(22)
            .fontColor(this.palette().textTertiary);
          Row({ space: 8 }) {
            this.formActionButton('开始清理', true, false, () => {
              void this.vm.clearCache();
            });
            this.formActionButton('取消', false, false, () => this.vm.hideClearCacheDialog());
          }
          .width('100%');
        }
        .width('88%')
        .padding(16)
        .backgroundColor(this.palette().surface)
        .borderRadius(20)
        .border({ width: 1, color: this.palette().outline });
      }
      .width('100%')
      .height('100%');
    }
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Scroll(this.pageScroller) {
        Column({ space: AppConstants.SECTION_SPACING }) {
          Text('设置')
            .fontSize(28)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.palette().textPrimary)
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
              .fontColor(this.palette().primary)
              .padding(12)
              .backgroundColor(this.palette().primaryContainer)
              .borderRadius(14);
          }

          if (this.vm.settingsState.errorMessage) {
            Text(this.vm.settingsState.errorMessage!)
              .fontSize(13)
              .fontColor(this.palette().danger)
              .padding(12)
              .backgroundColor(this.palette().dangerContainer)
              .borderRadius(14);
          }

          Text('刷新配置状态')
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.palette().primary)
            .width('100%')
            .textAlign(TextAlign.Center)
            .padding({ top: 14, bottom: 14 })
            .backgroundColor(this.palette().surface)
            .borderRadius(18)
            .border({ width: 1, color: this.palette().outline })
            .onClick(() => {
              void this.vm.refreshIntegrationStatusAction();
            });
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .padding({ left: AppConstants.PAGE_HORIZONTAL_PADDING, right: AppConstants.PAGE_HORIZONTAL_PADDING, top: 20, bottom: 20 });
      }
      .width('100%')
      .height('100%')
      .scrollBar(BarState.Off)
      .scrollable(ScrollDirection.Vertical)
      .backgroundColor(this.palette().background);

      this.themePickerCard();
      this.languagePickerCard();
      this.zoteroDialogCard();
      this.llmDialogCard();
      this.otherDialogs();
    }
    .width('100%')
    .height('100%');
  }
}

interface ColorModeHostContext {
  setColorMode(colorMode: number): void;
}

interface ColorModeConfig {
  colorMode?: string | number;
}

interface ContextWithColorMode extends Context {
  setColorMode(colorMode: number): void;
  config?: ColorModeConfig;
}
