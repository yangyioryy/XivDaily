import AppConstants from '../common/constants/AppConstants';
import Context from '@ohos.app.ability.application';
import common from '@ohos.app.ability.common';
import { resolveXivPalette, XivThemePalette } from '../common/theme/XivTheme';
import { PaperItem, TrendItem } from '../model/AppModels';
import { AppViewModel } from '../viewmodel/AppViewModel';

@Component
export struct HomePage {
  @ObjectLink vm: AppViewModel;
  @State private customTagDraft: string = '';
  @State private isAddTagDialogVisible: boolean = false;
  @State private pendingDeletionTag: string = '';
  @State private paperSwipeOffsets: SwipeOffsetState[] = [];

  private readSystemColorMode(): string | number | undefined {
    try {
      const hostContext = this.getUIContext().getHostContext() as ContextWithColorMode | undefined;
      return hostContext?.config?.colorMode;
    } catch (error) {
      return undefined;
    }
  }

  // 首页里有不少独立卡片和提示条，需要在页面内继续读取主题调色板，避免深浅色切换后残留浅色硬编码。
  private palette(): XivThemePalette {
    return resolveXivPalette(this.vm.settingsState.themeMode, this.readSystemColorMode());
  }

  private dayLabel(days: number): string {
    return days === 1 ? '24h' : `${days} 天`;
  }

  private summaryTitle(): string {
    if (this.vm.homeState.trendSummary?.items.length) {
      return this.vm.homeState.trendSummary!.items[0].trendTitle;
    }
    return '暂无趋势主题';
  }

  private isPaperExpanded(paperId: string): boolean {
    return this.vm.homeState.expandedAbstractPaperIds.indexOf(paperId) >= 0;
  }

  private isCategorySelected(category: string): boolean {
    return this.vm.homeState.selectedCategory === category;
  }

  private isDaySelected(days: number): boolean {
    return this.vm.homeState.selectedDays === days;
  }

  private isPaperTranslating(paperId: string): boolean {
    return this.vm.homeState.translatingPaperIds.indexOf(paperId) >= 0;
  }

  private isPaperSyncing(paperId: string): boolean {
    return this.vm.homeState.syncingPaperIds.indexOf(paperId) >= 0;
  }

  private isSearchActive(): boolean {
    return this.vm.homeState.searchKeyword.trim().length > 0;
  }

  private heroSubtitle(): string {
    if (this.isSearchActive()) {
      return `正在全 arXiv 搜索“${this.vm.homeState.searchKeyword}”，时间筛选不会缩小搜索范围。`;
    }
    return '围绕当天筛选范围快速浏览、收藏和同步论文。';
  }

  private isFeedRefreshing(): boolean {
    return this.vm.homeState.isLoading || this.vm.homeState.isSummaryLoading;
  }

  private paperSectionTitle(): string {
    return this.vm.homeState.isLoading ? '论文加载中...' : '论文列表';
  }

  private paperSectionSubtitle(): string {
    if (this.isSearchActive()) {
      return `全 arXiv 搜索：${this.vm.homeState.searchKeyword}，分类过滤：${this.vm.homeState.selectedCategory}`;
    }
    // Android 首页这里不追加“n 篇”数量后缀，鸿蒙端保持同一条副标题文案，避免跨端截图时出现肉眼可见差异。
    return `围绕 ${this.vm.homeState.selectedCategory} 的最新研究流`;
  }

  private emptyStateTitle(): string {
    if (this.vm.homeState.isLoading) {
      return '正在刷新论文列表';
    }
    if (this.vm.homeState.listStatus === 'unavailable') {
      return '当前暂时无法获取论文';
    }
    return '当前暂无可展示论文';
  }

  private emptyStateSubtitle(): string {
    if (this.vm.homeState.isLoading) {
      return '稍后将自动填充最新内容';
    }
    if (this.vm.homeState.emptyReason === 'time_window_filtered') {
      return '当前时间窗口过窄，可以尝试切换到 7 天或 30 天。';
    }
    if (this.vm.homeState.emptyReason === 'no_results') {
      return '当前搜索条件下没有命中论文，可以切换领域或重新搜索。';
    }
    if (this.vm.homeState.listStatus === 'unavailable') {
      return '请稍后重试，或先检查本地网络与服务状态。';
    }
    return '可以切换领域、时间窗口或重新搜索';
  }

  private representativeTitles(item: TrendItem): string {
    const titles: string[] = item.representativePaperIds.map((paperId: string) => {
      const paper = this.vm.homeState.papers.find((candidate: PaperItem) => candidate.id === paperId);
      return paper ? paper.title : '';
    }).filter((title: string) => title.length > 0);
    return titles.join(' / ');
  }

  private showAddTagDialog(): void {
    this.customTagDraft = '';
    this.isAddTagDialogVisible = true;
    this.pendingDeletionTag = '';
  }

  private hideAddTagDialog(): void {
    this.isAddTagDialogVisible = false;
  }

  private markTagPendingDeletion(tag: string): void {
    this.pendingDeletionTag = tag;
  }

  private clearPendingDeletion(): void {
    this.pendingDeletionTag = '';
  }

  private confirmAddCustomTag(): void {
    this.vm.addCustomTag(this.customTagDraft);
    this.isAddTagDialogVisible = false;
    this.customTagDraft = '';
  }

  private showToast(message: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({
        message: message
      });
    } catch (error) {
    }
  }

  private async openPaperSource(paper: PaperItem): Promise<void> {
    const hostContext = this.getUIContext().getHostContext();
    if (!hostContext || paper.sourceUrl.trim().length === 0) {
      this.showToast('论文链接暂不可用');
      return;
    }

    try {
      await (hostContext as common.UIAbilityContext).openLink(paper.sourceUrl.trim());
    } catch (error) {
      this.showToast('打开论文原文失败');
    }
  }

  private swipeTriggerOffset(): number {
    return 96;
  }

  private swipeRevealOffset(): number {
    return 132;
  }

  private paperSwipeOffset(paperId: string): number {
    const offsetState = this.paperSwipeOffsets.find((item: SwipeOffsetState) => item.paperId === paperId);
    return offsetState ? offsetState.offsetX : 0;
  }

  private paperSwipeProgress(paperId: string): number {
    const progress = Math.abs(this.paperSwipeOffset(paperId)) / this.swipeTriggerOffset();
    return Math.max(0, Math.min(progress, 1));
  }

  private paperSwipeHintLabel(paperId: string): string {
    const offset = this.paperSwipeOffset(paperId);
    if (offset > 0) {
      return '右滑同步 Zotero';
    }
    if (offset < 0) {
      return '左滑忽略本条';
    }
    return '左右滑动可触发快捷操作';
  }

  private paperSwipeHintSymbol(paperId: string): string {
    return this.paperSwipeOffset(paperId) >= 0 ? 'sys.symbol.arrow_2_circlepath' : 'sys.symbol.eye_slash';
  }

  private paperSwipeHintColor(paperId: string): ResourceColor {
    const offset = this.paperSwipeOffset(paperId);
    if (offset > 0) {
      return this.palette().primaryContainer;
    }
    if (offset < 0) {
      return this.palette().warningContainer;
    }
    return this.palette().surfaceSubtle;
  }

  private updatePaperSwipeOffset(paperId: string, nextOffset: number): void {
    const clampedOffset = Math.max(-this.swipeRevealOffset(), Math.min(nextOffset, this.swipeRevealOffset()));
    const nextOffsets: SwipeOffsetState[] = this.paperSwipeOffsets
      .filter((item: SwipeOffsetState) => item.paperId !== paperId);
    nextOffsets.push({
      paperId: paperId,
      offsetX: clampedOffset
    });
    this.paperSwipeOffsets = nextOffsets;
  }

  private clearPaperSwipeOffset(paperId: string): void {
    this.paperSwipeOffsets = this.paperSwipeOffsets.filter((item: SwipeOffsetState) => item.paperId !== paperId);
  }

  private animatePaperSwipeOffset(paperId: string, targetOffset: number, onFinish?: () => void): void {
    animateTo({
      duration: 180,
      curve: Curve.EaseOut,
      onFinish: () => {
        if (targetOffset === 0) {
          this.clearPaperSwipeOffset(paperId);
        }
        if (onFinish) {
          onFinish();
        }
      }
    }, () => {
      this.updatePaperSwipeOffset(paperId, targetOffset);
    });
  }

  private commitPaperSwipe(paper: PaperItem): void {
    const offset = this.paperSwipeOffset(paper.id);
    if (offset >= this.swipeTriggerOffset()) {
      this.animatePaperSwipeOffset(paper.id, this.swipeRevealOffset(), () => {
        void this.vm.syncToZotero(paper.id);
        this.animatePaperSwipeOffset(paper.id, 0);
      });
      return;
    }
    if (offset <= -this.swipeTriggerOffset()) {
      this.animatePaperSwipeOffset(paper.id, -this.swipeRevealOffset(), () => {
        this.clearPaperSwipeOffset(paper.id);
        this.vm.dismissHomePaper(paper.id);
      });
      return;
    }
    this.animatePaperSwipeOffset(paper.id, 0);
  }

  private handleCustomTagTap(tag: string): void {
    if (this.pendingDeletionTag === tag) {
      this.clearPendingDeletion();
      return;
    }
    this.vm.selectCategory(tag);
  }

  @Builder
  private heroSection() {
    Column({ space: 14 }) {
      Row() {
        Text('首页')
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.palette().textPrimary);
        Blank();
        Row() {
          SymbolGlyph($r('sys.symbol.bell_fill'))
            .fontSize(14)
            .fontColor([this.palette().primary]);
        }
        .width(34)
        .height(34)
        .justifyContent(FlexAlign.Center)
        .backgroundColor(this.palette().primaryContainer)
        .borderRadius(17);
      }
      .width('100%');

      Text(this.heroSubtitle())
        .fontSize(13)
        .lineHeight(19)
        .fontColor(this.palette().textSecondary)
        .width('100%');
  }
    .width('100%');
  }

  @Builder
  private exploreControlCard() {
    Column({ space: 14 }) {
      Row({ space: 10 }) {
        Text('⌕')
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.palette().textSecondary);
        TextInput({
          placeholder: '搜索论文、作者、关键词',
          text: this.vm.homeState.searchKeywordDraft
        })
          .fontSize(15)
          .layoutWeight(1)
          .fontColor(this.palette().textPrimary)
          .placeholderColor(this.palette().textSecondary)
          .backgroundColor(this.palette().surface)
          .onChange((value: string) => this.vm.updateSearchKeywordDraft(value))
          .onSubmit(() => this.vm.submitSearch());
        if (this.isSearchActive()) {
          Text('×')
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.palette().textTertiary)
            .width(28)
            .height(28)
            .textAlign(TextAlign.Center)
            .backgroundColor(this.palette().surfaceSubtle)
            .borderRadius(14)
            .onClick(() => this.vm.clearSearch());
        }
        Text('搜索')
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.palette().primary)
          .padding({ left: 8, right: 8, top: 8, bottom: 8 })
          .onClick(() => this.vm.submitSearch());
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
      .padding({ left: 14, right: 10, top: 10, bottom: 10 })
      .backgroundColor(this.palette().surface)
      .borderRadius(18)
      .border({ width: 1, color: this.palette().outline });

      Column({ space: 8 }) {
        Text('领域')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.palette().textSecondary)
          .width('100%');

        Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start, alignItems: ItemAlign.Center }) {
          ForEach(this.vm.homeState.categories, (category: string) => {
            Text(category)
              .fontSize(14)
              .fontWeight(this.isCategorySelected(category) ? FontWeight.Medium : FontWeight.Regular)
              .fontColor(this.isCategorySelected(category) ? this.palette().onPrimary : this.palette().textPrimary)
              .padding({ left: 16, right: 16, top: 8, bottom: 8 })
              .margin({ right: 8, bottom: 8 })
              .backgroundColor(this.isCategorySelected(category) ? this.palette().primary : this.palette().surface)
              .borderRadius(14)
              .border({
                width: this.isCategorySelected(category) ? 0 : 1,
                color: this.palette().outline
              })
              .onClick(() => this.vm.selectCategory(category));
          }, (category: string) => category);

          ForEach(this.vm.homeState.customTags, (tag: string) => {
            Row({ space: 0 }) {
              Row() {
                Text(tag)
                  .fontSize(14)
                  .fontWeight(this.isCategorySelected(tag) ? FontWeight.Medium : FontWeight.Regular)
                  .fontColor(this.isCategorySelected(tag) ? this.palette().onPrimary : this.palette().textPrimary);
              }
              .padding({ left: 16, right: 10, top: 8, bottom: 8 })
              .gesture(
                GestureGroup(
                  GestureMode.Exclusive,
                  LongPressGesture({ repeat: false, duration: 350 })
                    .onAction(() => this.markTagPendingDeletion(tag)),
                  TapGesture()
                    .onAction(() => this.handleCustomTagTap(tag))
                )
              );
              if (this.pendingDeletionTag === tag) {
                Text('-')
                  .fontSize(12)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(this.isCategorySelected(tag) ? this.palette().onPrimary : this.palette().danger)
                  .width(22)
                  .height(22)
                  .textAlign(TextAlign.Center)
                  .backgroundColor(this.isCategorySelected(tag) ? this.palette().danger : this.palette().dangerContainer)
                  .borderRadius(6)
                  .margin({ left: 2, right: 12, top: 7, bottom: 7 })
                  .onClick(() => this.vm.deleteCustomTag(tag));
              }
            }
            .margin({ right: 8, bottom: 8 })
            .backgroundColor(this.isCategorySelected(tag) ? this.palette().primary :
              (this.pendingDeletionTag === tag ? this.palette().warningContainer : this.palette().surface))
            .borderRadius(14)
            .border({
              width: this.isCategorySelected(tag) ? 0 : 1,
              color: this.palette().outline
            });
          }, (tag: string) => `custom-${tag}`);

          Text('+ 添加')
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.palette().primary)
            .padding({ left: 16, right: 16, top: 8, bottom: 8 })
            .margin({ right: 8, bottom: 8 })
            .backgroundColor(this.palette().surface)
            .borderRadius(14)
            .border({ width: 1, color: this.palette().outline })
            .onClick(() => this.showAddTagDialog());
        }
        .width('100%');
      }

      if (this.vm.homeState.searchKeyword.length > 0) {
        Text('关键词搜索覆盖全 arXiv；领域只做结果过滤，时间 Pills 会临时隐藏。')
          .fontSize(13)
          .lineHeight(20)
          .fontColor(this.palette().onSecondaryContainer)
          .width('100%')
          .padding(12)
          .backgroundColor(this.palette().secondaryContainer)
          .borderRadius(14);
      } else {
        if (this.vm.homeState.customTags.indexOf(this.vm.homeState.selectedCategory) >= 0) {
          Text('自定义标签会用关键词在全 arXiv 召回论文，适合 embodied-ai 这类研究方向。')
            .fontSize(13)
            .lineHeight(20)
            .fontColor(this.palette().onSecondaryContainer)
            .width('100%')
            .padding(12)
            .backgroundColor(this.palette().secondaryContainer)
            .borderRadius(14);
        }

        Column({ space: 8 }) {
          Text('时间')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.palette().textSecondary)
            .width('100%');

          Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start, alignItems: ItemAlign.Center }) {
            ForEach(this.vm.homeState.dayOptions, (days: number) => {
              Text(this.dayLabel(days))
                .fontSize(14)
                .fontWeight(this.isDaySelected(days) ? FontWeight.Medium : FontWeight.Regular)
                .fontColor(this.isDaySelected(days) ? this.palette().textPrimary : this.palette().textSecondary)
                .padding({ left: 16, right: 16, top: 8, bottom: 8 })
                .margin({ right: 8, bottom: 8 })
                .backgroundColor(this.isDaySelected(days) ? this.palette().secondaryContainer : this.palette().surface)
                .borderRadius(12)
                .border({ width: 1, color: this.palette().outline })
                .onClick(() => this.vm.selectDays(days));
            }, (days: number) => `${days}`);
          }
        }
        .width('100%');
      }
    }
    .width('100%');
  }

  @Builder
  private paperSectionHeader() {
    Row() {
      Column({ space: 4 }) {
        Text(this.paperSectionTitle())
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.palette().textPrimary);
        Text(this.paperSectionSubtitle())
          .fontSize(13)
          .lineHeight(19)
          .fontColor(this.palette().textSecondary);
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start);

      Row({ space: 6 }) {
        Text('↻')
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.palette().primary);
        Text(this.isFeedRefreshing() ? '刷新中' : '刷新')
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.palette().primary);
      }
        .padding({ left: 8, right: 8, top: 8, bottom: 8 })
        .opacity(this.isFeedRefreshing() ? 0.7 : 1)
        .onClick(() => {
          // Android 刷新入口会同时刷新论文列表和趋势摘要，鸿蒙端这里保持同一条链路。
          void this.vm.refreshFeed();
        });
    }
    .width('100%')
    .alignItems(VerticalAlign.Center);
  }

  @Builder
  private trendSummaryCard() {
    Column({ space: 12 }) {
      Row() {
        Column({ space: 6 }) {
          Text('AI 趋势简报')
            .fontSize(18)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.palette().textPrimary);

          Text(`最近 3 天 · ${this.vm.homeState.selectedCategory}`)
            .fontSize(13)
            .fontColor(this.palette().textSecondary);
        }
        Blank();
        Text('关闭')
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.palette().primary)
          .padding({ left: 8, right: 8, top: 8, bottom: 8 })
          .onClick(() => this.vm.dismissSummary());
      }
      .width('100%');

      if (this.vm.homeState.isSummaryLoading) {
        Text('趋势摘要加载中...')
          .fontSize(15)
          .lineHeight(22)
          .fontColor(this.palette().textSecondary)
          .width('100%');
      } else if (this.vm.homeState.trendErrorMessage) {
        Text(this.vm.homeState.trendErrorMessage!)
          .fontSize(13)
          .lineHeight(20)
          .fontColor(this.palette().danger)
          .width('100%')
          .padding({ left: 16, right: 16, top: 10, bottom: 10 })
          .backgroundColor(this.palette().dangerContainer)
          .borderRadius(14);
      } else if (this.vm.homeState.trendSummary) {
        Text(this.vm.homeState.trendSummary!.intro)
          .fontSize(15)
          .lineHeight(22)
          .fontColor(this.palette().onSecondaryContainer)
          .width('100%')
          .padding({ left: 16, right: 16, top: 10, bottom: 10 })
          .backgroundColor(this.palette().surfaceSubtle)
          .borderRadius(16);

        if (this.vm.homeState.summaryExpanded) {
          Column({ space: 10 }) {
            ForEach(this.vm.homeState.trendSummary!.items, (item: TrendItem) => {
              Column({ space: 4 }) {
                Row({ space: 6 }) {
                  Text('●')
                    .fontSize(10)
                    .fontColor(this.palette().primary);
                  Text(`${item.rank}. ${item.trendTitle}`)
                    .fontSize(14)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(this.palette().textPrimary)
                    .layoutWeight(1);
                }
                .width('100%');

                Text(item.summary)
                  .fontSize(13)
                  .lineHeight(20)
                  .fontColor(this.palette().textSecondary);
                if (this.representativeTitles(item).length > 0) {
                  Text(`代表论文：${this.representativeTitles(item)}`)
                    .fontSize(12)
                    .lineHeight(18)
                    .fontColor(this.palette().textSecondary);
                }
              };
            }, (item: TrendItem) => `${item.rank}`);
          }
          .width('100%');
        }

        Text(this.vm.homeState.summaryExpanded ? '收起趋势详情' : '展开趋势详情')
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.palette().primary)
          .padding({ left: 8, right: 8, top: 8, bottom: 8 })
          .onClick(() => this.vm.toggleSummaryExpanded());
      } else {
        Text('暂无趋势摘要')
          .fontSize(15)
          .lineHeight(22)
          .fontColor(this.palette().textSecondary)
          .width('100%');
      }
    }
    .width('100%')
    .padding(16)
    .backgroundColor(this.palette().primaryContainer)
    .borderRadius(20);
  }

  @Builder
  private paperActionButton(iconText: string, label: string, action: () => void, disabled: boolean = false,
    isLoading: boolean = false, iconSymbol?: string) {
    Row({ space: 6 }) {
      if (isLoading) {
        LoadingProgress()
          .width(16)
          .height(16)
          .color(this.palette().onPrimaryContainer);
      } else if (iconSymbol) {
        SymbolGlyph($r(iconSymbol))
          .fontSize(16)
          .fontColor([this.palette().onPrimaryContainer]);
      } else {
        Text(iconText)
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.palette().onPrimaryContainer);
      }
      Text(label)
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.palette().onPrimaryContainer);
    }
    .padding({ left: 12, right: 12, top: 8, bottom: 8 })
    .margin({ right: 8, bottom: 8 })
    .backgroundColor(this.palette().primaryContainer)
    .borderRadius(10)
    .alignItems(VerticalAlign.Center)
    .opacity(disabled ? 0.6 : 1)
    .onClick(() => {
      if (!disabled) {
        action();
      }
    });
  }

  @Builder
  private paperSwipeHint(paper: PaperItem) {
    Row({ space: 8 }) {
      if (this.paperSwipeOffset(paper.id) >= 0) {
        SymbolGlyph($r(this.paperSwipeHintSymbol(paper.id)))
          .fontSize(16)
          .fontColor([this.palette().textPrimary]);
        Text(this.paperSwipeHintLabel(paper.id))
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.palette().textPrimary);
        Blank();
      } else {
        Blank();
        Text(this.paperSwipeHintLabel(paper.id))
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.palette().textPrimary);
        SymbolGlyph($r(this.paperSwipeHintSymbol(paper.id)))
          .fontSize(16)
          .fontColor([this.palette().textPrimary]);
      }
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 20, bottom: 20 })
    .opacity(0.35 + this.paperSwipeProgress(paper.id) * 0.65);
  }

  private homePaperById(paperId: string): PaperItem | undefined {
    return this.vm.homeState.papers.find((item: PaperItem) => item.id === paperId);
  }

  private currentPaper(paper: PaperItem): PaperItem {
    return this.homePaperById(paper.id) ?? paper;
  }

  @Builder
  private paperCard(paper: PaperItem) {
    Stack({ alignContent: Alignment.Center }) {
      this.paperSwipeHint(paper);
      Column({ space: 12 }) {
      Column({ space: 12 }) {
        Row() {
          Text(this.currentPaper(paper).title)
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.palette().textPrimary)
            .layoutWeight(1);
          SymbolGlyph($r(this.currentPaper(paper).favoriteState ? 'sys.symbol.star_fill' : 'sys.symbol.star'))
            .fontSize(20)
            .fontColor([this.currentPaper(paper).favoriteState ? this.palette().warning : this.palette().textTertiary]);
        }
        .width('100%');

        Text(this.currentPaper(paper).authors.join(', '))
          .fontSize(12)
          .lineHeight(18)
          .fontColor(this.palette().textSecondary)
          .width('100%')
          .textAlign(TextAlign.Start);

        Text(`${this.currentPaper(paper).primaryCategory} · ${this.currentPaper(paper).publishedAt.slice(0, 10)} · Zotero ${this.currentPaper(paper).zoteroSyncState}`)
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.palette().onPrimaryContainer)
          .width('100%')
          .textAlign(TextAlign.Start)
          .padding({ left: 16, right: 16, top: 8, bottom: 8 })
          .backgroundColor(this.palette().primaryContainer)
        .borderRadius(10);

        if (this.isPaperExpanded(paper.id)) {
          Column({ space: 10 }) {
            if (this.currentPaper(paper).translatedSummary) {
              Column({ space: 6 }) {
                Text('中文翻译')
                  .fontSize(13)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(this.palette().primary);
                Text(this.currentPaper(paper).translatedSummary)
                  .fontSize(14)
                  .lineHeight(22)
                  .fontColor(this.palette().textPrimary);
                Text('Original Abstract')
                  .fontSize(13)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(this.palette().textSecondary);
                Text(this.currentPaper(paper).summary)
                  .fontSize(13)
                  .lineHeight(20)
                  .fontColor(this.palette().textSecondary);
              }
              .width('100%');
            } else {
              Column({ space: 6 }) {
              Text('Original Abstract')
                .fontSize(13)
                .fontWeight(FontWeight.Medium)
                .fontColor(this.palette().primary);
              Text(this.currentPaper(paper).summary)
                .fontSize(13)
                .lineHeight(20)
                .fontColor(this.palette().textSecondary);
              }
              .width('100%');
            }

            if (this.isPaperTranslating(paper.id) || this.vm.homeState.translationErrors[paper.id]) {
              Text(this.isPaperTranslating(paper.id) ? '摘要翻译中...' : this.vm.homeState.translationErrors[paper.id])
                .fontSize(13)
                .lineHeight(20)
                .fontColor(this.palette().onSecondaryContainer)
                .width('100%')
                .padding({ left: 16, right: 16, top: 10, bottom: 10 })
                .backgroundColor(this.palette().secondaryContainer)
                .borderRadius(14);
            }
          }
          .width('100%');
        }
      }
      .width('100%')
      .gesture(
        GestureGroup(
          GestureMode.Exclusive,
          TapGesture({ count: 2 })
            .onAction(() => this.vm.toggleFavorite(paper.id)),
          TapGesture()
            .onAction(() => {
              void this.openPaperSource(this.currentPaper(paper));
            })
        )
      )
      .parallelGesture(
        PanGesture({
          fingers: 1,
          direction: PanDirection.Horizontal,
          distance: 6
        })
          .onActionUpdate((event?: GestureEvent) => {
            if (event) {
              this.updatePaperSwipeOffset(paper.id, event.offsetX);
            }
          })
          .onActionEnd(() => this.commitPaperSwipe(paper))
          .onActionCancel(() => this.animatePaperSwipeOffset(paper.id, 0))
      );

      Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start, alignItems: ItemAlign.Center }) {
        this.paperActionButton('›', this.isPaperExpanded(paper.id) ? '收起摘要' : '展开摘要',
          () => this.vm.toggleAbstract(paper.id));

        if (this.isPaperExpanded(paper.id)) {
          this.paperActionButton('✦', this.isPaperTranslating(paper.id) ? '翻译中...' : '翻译', () => {
            void this.vm.translatePaper(paper.id);
          }, this.isPaperTranslating(paper.id), this.isPaperTranslating(paper.id));
        }

        this.paperActionButton('☆', this.currentPaper(paper).favoriteState ? '取消收藏' : '收藏', () => this.vm.toggleFavorite(paper.id),
          false, false, this.currentPaper(paper).favoriteState ? 'sys.symbol.bookmark_book_fill' : 'sys.symbol.bookmark_book_closed');

        if (this.currentPaper(paper).zoteroSyncState !== 'synced') {
          this.paperActionButton('↻', this.isPaperSyncing(paper.id) ? '同步中...' : '同步', () => {
            void this.vm.syncToZotero(paper.id);
          }, this.isPaperSyncing(paper.id), this.isPaperSyncing(paper.id), 'sys.symbol.arrow_2_circlepath');
        }
      }
      }
      .width('100%')
      .padding(16)
      .backgroundColor(this.palette().surface)
      .borderRadius(10)
      .translate({ x: this.paperSwipeOffset(paper.id), y: 0, z: 0 })
      .opacity(1 - this.paperSwipeProgress(paper.id) * 0.08);
    }
    .width('100%')
    .backgroundColor(this.paperSwipeHintColor(paper.id))
    .borderRadius(10);
  }

  @Builder
  private emptyStateCard() {
    Column({ space: 10 }) {
      Row() {
        Text('✦')
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.palette().primary);
      }
      .width(32)
      .height(32)
      .justifyContent(FlexAlign.Center)
      .backgroundColor(this.palette().primaryContainer)
      .borderRadius(10);
      Text(this.emptyStateTitle())
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.palette().textPrimary)
        .width('100%')
        .textAlign(TextAlign.Center);
      Text(this.emptyStateSubtitle())
        .fontSize(14)
        .lineHeight(22)
        .fontColor(this.palette().textSecondary)
        .width('100%')
        .textAlign(TextAlign.Center);
    }
    .alignItems(HorizontalAlign.Center)
    .width('100%')
    .padding({ left: 18, right: 18, top: 24, bottom: 24 })
    .backgroundColor(this.palette().surface)
    .borderRadius(16);
  }

  @Builder
  private addTagDialogOverlay() {
    Stack({ alignContent: Alignment.Center }) {
      Row()
        .width('100%')
        .height('100%')
        .backgroundColor('#66000000')
        .onClick(() => this.hideAddTagDialog());

      Column({ space: 14 }) {
        Text('添加自定义标签')
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.palette().textPrimary);
        Text('输入研究方向，例如 embodied-ai。标签会作为关键词检索论文。')
          .fontSize(13)
          .lineHeight(20)
          .fontColor(this.palette().textSecondary)
          .width('100%');
        Text('标签名称')
          .fontSize(13)
          .fontColor(this.palette().textSecondary)
          .width('100%');
        TextInput({
          placeholder: '标签名称',
          text: this.customTagDraft
        })
          .fontSize(15)
          .fontColor(this.palette().textPrimary)
          .placeholderColor(this.palette().textSecondary)
          .backgroundColor(this.palette().surfaceSubtle)
          .borderRadius(12)
          .border({ width: 1, color: this.palette().outline })
          .padding({ left: 14, right: 14, top: 10, bottom: 10 })
          .onChange((value: string) => this.customTagDraft = value)
          .onClick(() => {});
        Row({ space: 8 }) {
          Blank();
          Text('取消')
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.palette().textSecondary)
            .padding({ left: 8, right: 8, top: 8, bottom: 8 })
            .onClick(() => this.hideAddTagDialog());
          Text('添加')
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.palette().primary)
            .padding({ left: 8, right: 8, top: 8, bottom: 8 })
            .onClick(() => this.confirmAddCustomTag());
        }
        .width('100%')
        .justifyContent(FlexAlign.End);
      }
      .width('88%')
      .padding(20)
      .backgroundColor(this.palette().surface)
      .borderRadius(24)
      .onClick(() => {});
    }
    .width('100%')
    .height('100%');
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Column({ space: AppConstants.SECTION_SPACING }) {
        this.heroSection();
        this.exploreControlCard();

        if (this.vm.homeState.errorMessage) {
          Text(this.vm.homeState.errorMessage!)
            .fontSize(13)
            .lineHeight(20)
            .fontColor(this.palette().danger)
            .width('100%')
            .padding(12)
            .backgroundColor(this.palette().dangerContainer)
            .borderRadius(14);
        }

        if (this.vm.homeState.listWarning) {
          Text(this.vm.homeState.listWarning!)
            .fontSize(13)
            .lineHeight(20)
            .fontColor(this.palette().onSecondaryContainer)
            .width('100%')
            .padding(12)
            .backgroundColor(this.palette().secondaryContainer)
            .borderRadius(14);
        }

        if (!this.vm.homeState.dismissedSummary) {
          this.trendSummaryCard();
        }

        Column({ space: 12 }) {
          this.paperSectionHeader();

          if (this.vm.homeState.papers.length === 0) {
            this.emptyStateCard();
          } else {
            ForEach(this.vm.homeState.papers, (paper: PaperItem) => {
              this.paperCard(paper);
            }, (paper: PaperItem) => `${paper.id}:${paper.favoriteState ? '1' : '0'}:${paper.zoteroSyncState}`);
          }
        }
        .width('100%');
      }
      .width('100%')
      .onClick(() => {
        if (this.pendingDeletionTag.length > 0) {
          this.clearPendingDeletion();
        }
      })
      .alignItems(HorizontalAlign.Start)
      .padding({ left: AppConstants.PAGE_HORIZONTAL_PADDING, right: AppConstants.PAGE_HORIZONTAL_PADDING, top: 20, bottom: 20 });

      if (this.isAddTagDialogVisible) {
        this.addTagDialogOverlay();
      }
    }
    .width('100%');
  }
}

interface ColorModeConfig {
  colorMode?: string | number;
}

interface ContextWithColorMode extends Context {
  config?: ColorModeConfig;
}

interface SwipeOffsetState {
  paperId: string;
  offsetX: number;
}
