import AppConstants from '../common/constants/AppConstants';
import common from '@ohos.app.ability.common';
import { PaperItem, TrendItem } from '../model/AppModels';
import { AppViewModel } from '../viewmodel/AppViewModel';

@Component
export struct HomePage {
  @ObjectLink vm: AppViewModel;
  @State private customTagDraft: string = '';
  @State private isAddTagDialogVisible: boolean = false;
  @State private pendingDeletionTag: string = '';

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

  private paperSectionTitle(): string {
    return this.vm.homeState.isLoading ? '论文加载中...' : '论文列表';
  }

  private paperSectionSubtitle(): string {
    if (this.isSearchActive()) {
      return `全 arXiv 搜索：${this.vm.homeState.searchKeyword}，分类过滤：${this.vm.homeState.selectedCategory}`;
    }
    const countSuffix = this.vm.homeState.papers.length > 0 ? ` · ${this.vm.homeState.papers.length} 篇` : '';
    return `围绕 ${this.vm.homeState.selectedCategory} 的最新研究流${countSuffix}`;
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

  private normalizeSwipeAngle(angle: number): number {
    const normalizedAngle = angle % 360;
    return normalizedAngle < 0 ? normalizedAngle + 360 : normalizedAngle;
  }

  private handlePaperSwipe(paper: PaperItem, event: GestureEvent): void {
    const swipeEvent = event as SwipeGestureEvent;
    const angle = this.normalizeSwipeAngle(swipeEvent.angle);
    if (angle <= 90 || angle >= 270) {
      void this.vm.syncToZotero(paper.id);
      return;
    }
    this.vm.dismissHomePaper(paper.id);
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
          .fontColor('#111827');
        Blank();
        Row() {
          SymbolGlyph($r('sys.symbol.bell_fill'))
            .fontSize(14)
            .fontColor(['#2D6CE8']);
        }
        .width(34)
        .height(34)
        .justifyContent(FlexAlign.Center)
        .backgroundColor('#E8F0FF')
        .borderRadius(17);
      }
      .width('100%');

      Text(this.heroSubtitle())
        .fontSize(13)
        .lineHeight(19)
        .fontColor('#6B7280')
        .width('100%');
    }
    .width('100%');
  }

  @Builder
  private exploreControlCard() {
    Column({ space: 14 }) {
      Row({ space: 16 }) {
        Text('🔎')
          .fontSize(22);
        TextInput({
          placeholder: '搜索论文、作者、关键词',
          text: this.vm.homeState.searchKeywordDraft
        })
          .fontSize(15)
          .layoutWeight(1)
          .backgroundColor('#FFFFFF')
          .onChange((value: string) => this.vm.updateSearchKeywordDraft(value))
          .onSubmit(() => this.vm.submitSearch());
        Text('搜索')
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor('#2D6CE8')
          .onClick(() => this.vm.submitSearch());
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 16, bottom: 16 })
      .backgroundColor('#FFFFFF')
      .borderRadius(24)
      .border({ width: 1, color: '#D9E2F0' });

      if (this.isSearchActive()) {
        Row() {
          Blank();
          Text('退出搜索')
            .fontSize(13)
            .fontWeight(FontWeight.Medium)
            .fontColor('#475569')
            .padding({ left: 14, right: 14, top: 8, bottom: 8 })
            .backgroundColor('#F1F4FA')
            .borderRadius(999)
            .onClick(() => this.vm.clearSearch());
        }
        .width('100%');
      }

      Column({ space: 8 }) {
        Text('领域')
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .fontColor('#374151')
          .width('100%');

        Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start, alignItems: ItemAlign.Center }) {
          ForEach(this.vm.homeState.categories, (category: string) => {
            Text(category)
              .fontSize(14)
              .fontWeight(this.isCategorySelected(category) ? FontWeight.Medium : FontWeight.Regular)
              .fontColor(this.isCategorySelected(category) ? '#FFFFFF' : '#1F2937')
              .padding({ left: 16, right: 16, top: 8, bottom: 8 })
              .margin({ right: 8, bottom: 8 })
              .backgroundColor(this.isCategorySelected(category) ? '#2D6CE8' : '#F8FAFC')
              .borderRadius(14)
              .border({
                width: this.isCategorySelected(category) ? 0 : 1,
                color: '#D7DEE9'
              })
              .onClick(() => this.vm.selectCategory(category));
          }, (category: string) => category);

          ForEach(this.vm.homeState.customTags, (tag: string) => {
            Row({ space: 0 }) {
              Row() {
                Text(tag)
                  .fontSize(14)
                  .fontWeight(this.isCategorySelected(tag) ? FontWeight.Medium : FontWeight.Regular)
                  .fontColor(this.isCategorySelected(tag) ? '#FFFFFF' : '#1F2937');
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
                  .fontColor(this.isCategorySelected(tag) ? '#FFFFFF' : '#B6544A')
                  .width(22)
                  .height(22)
                  .textAlign(TextAlign.Center)
                  .backgroundColor(this.isCategorySelected(tag) ? '#8E2D2D' : '#FFEAEA')
                  .borderRadius(6)
                  .margin({ left: 2, right: 12, top: 7, bottom: 7 })
                  .onClick(() => this.vm.deleteCustomTag(tag));
              }
            }
            .margin({ right: 8, bottom: 8 })
            .backgroundColor(this.isCategorySelected(tag) ? '#2D6CE8' : (this.pendingDeletionTag === tag ? '#FFF1DD' : '#F8FAFC'))
            .borderRadius(14)
            .border({
              width: this.isCategorySelected(tag) ? 0 : 1,
              color: '#D7DEE9'
            });
          }, (tag: string) => `custom-${tag}`);

          Text('+ 添加')
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor('#2D6CE8')
            .padding({ left: 16, right: 16, top: 8, bottom: 8 })
            .margin({ right: 8, bottom: 8 })
            .backgroundColor('#F8FAFC')
            .borderRadius(14)
            .border({ width: 1, color: '#D7DEE9' })
            .onClick(() => this.showAddTagDialog());
        }
        .width('100%');
      }

      if (this.vm.homeState.searchKeyword.length > 0) {
        Text('关键词搜索覆盖全 arXiv；领域只做结果过滤，时间 Pills 会临时隐藏。')
          .fontSize(13)
          .lineHeight(20)
          .fontColor('#6B7280')
          .width('100%')
          .padding(12)
          .backgroundColor('#FFF1DD')
          .borderRadius(14);
      } else {
        if (this.vm.homeState.customTags.indexOf(this.vm.homeState.selectedCategory) >= 0) {
          Text('自定义标签会用关键词在全 arXiv 召回论文，适合 embodied-ai 这类研究方向。')
            .fontSize(13)
            .lineHeight(20)
            .fontColor('#6B7280')
            .width('100%')
            .padding(12)
            .backgroundColor('#FFF1DD')
            .borderRadius(14);
        }

        Column({ space: 8 }) {
          Text('时间')
            .fontSize(18)
            .fontWeight(FontWeight.Medium)
            .fontColor('#374151')
            .width('100%');

          Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start, alignItems: ItemAlign.Center }) {
            ForEach(this.vm.homeState.dayOptions, (days: number) => {
              Text(this.dayLabel(days))
                .fontSize(14)
                .fontWeight(this.isDaySelected(days) ? FontWeight.Medium : FontWeight.Regular)
                .fontColor(this.isDaySelected(days) ? '#1F2937' : '#6B7280')
                .padding({ left: 16, right: 16, top: 8, bottom: 8 })
                .margin({ right: 8, bottom: 8 })
                .backgroundColor(this.isDaySelected(days) ? '#F1F4FA' : '#F8FAFC')
                .borderRadius(12)
                .border({ width: 1, color: '#D7DEE9' })
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
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor('#111827');
        Text(this.paperSectionSubtitle())
          .fontSize(13)
          .lineHeight(19)
          .fontColor('#6B7280');
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start);

      Text(this.vm.homeState.isLoading ? '刷新中' : '刷新')
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor('#2D6CE8')
        .padding({ left: 12, right: 12, top: 8, bottom: 8 })
        .backgroundColor('#EAF2FF')
        .borderRadius(999)
        .opacity(this.vm.homeState.isLoading ? 0.7 : 1)
        .onClick(() => this.vm.refreshHome());
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
            .fontSize(20)
            .fontWeight(FontWeight.Medium)
            .fontColor('#111827');

          Text(`最近 3 天 · ${this.vm.homeState.selectedCategory}`)
            .fontSize(13)
            .fontColor('#6B7280');
        }
        Blank();
        Text('关闭')
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor('#2D6CE8')
          .padding({ left: 12, right: 12, top: 8, bottom: 8 })
          .backgroundColor('#FFFFFF')
          .borderRadius(999)
          .onClick(() => this.vm.dismissSummary());
      }
      .width('100%');

      if (this.vm.homeState.isSummaryLoading) {
        Text('趋势摘要加载中...')
        .fontSize(14)
        .fontColor('#6B7280')
          .width('100%');
      } else if (this.vm.homeState.trendErrorMessage) {
        Text(this.vm.homeState.trendErrorMessage!)
          .fontSize(14)
          .lineHeight(21)
          .fontColor('#B6544A')
          .width('100%')
          .padding(14)
          .backgroundColor('#FFEAEA')
          .borderRadius(16);
      } else if (this.vm.homeState.trendSummary) {
        Text(this.vm.homeState.trendSummary!.intro)
          .fontSize(15)
          .lineHeight(22)
          .fontColor('#374151')
          .width('100%')
          .padding(14)
          .backgroundColor('#FDFEFF')
          .borderRadius(18);

        if (this.vm.homeState.summaryExpanded) {
          Column({ space: 12 }) {
            ForEach(this.vm.homeState.trendSummary!.items, (item: TrendItem) => {
              Column({ space: 6 }) {
                Row({ space: 8 }) {
                  Text('●')
                    .fontSize(12)
                    .fontColor('#2D6CE8');
                  Text(`${item.rank}. ${item.trendTitle}`)
                    .fontSize(15)
                    .fontWeight(FontWeight.Medium)
                    .fontColor('#1F2937')
                    .layoutWeight(1);
                }
                .width('100%');

                Text(item.summary)
                  .fontSize(14)
                  .lineHeight(22)
                  .fontColor('#6B7280');
                if (this.representativeTitles(item).length > 0) {
                  Text(`代表论文：${this.representativeTitles(item)}`)
                    .fontSize(13)
                    .lineHeight(20)
                    .fontColor('#6B7280');
                }
              };
            }, (item: TrendItem) => `${item.rank}`);
          }
          .width('100%');
        }

        Text(this.vm.homeState.summaryExpanded ? '收起趋势详情' : '展开趋势详情')
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor('#2D6CE8')
          .padding({ left: 12, right: 12, top: 8, bottom: 8 })
          .backgroundColor('#FDFEFF')
          .borderRadius(999)
          .onClick(() => this.vm.toggleSummaryExpanded());
      } else {
        Text('暂无趋势摘要')
          .fontSize(14)
          .fontColor('#6B7280')
          .width('100%');
      }
    }
    .width('100%')
    .padding(18)
    .backgroundColor('#EAF2FF')
    .borderRadius(24);
  }

  @Builder
  private paperCard(paper: PaperItem) {
    Column({ space: 12 }) {
      Column({ space: 12 }) {
        Row() {
          Text(paper.title)
            .fontSize(18)
            .fontWeight(FontWeight.Medium)
          .fontColor('#111827')
          .layoutWeight(1);
          Text(paper.favoriteState ? '★' : '☆')
            .fontSize(16)
            .fontColor('#B37B3F');
        }
        .width('100%');

        Text(paper.authors.join(', '))
          .fontSize(13)
          .lineHeight(20)
          .fontColor('#6B7280');

        Text(`${paper.primaryCategory} · ${paper.publishedAt.slice(0, 10)} · Zotero ${paper.zoteroSyncState}`)
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor('#37527A')
          .padding({ left: 12, right: 12, top: 8, bottom: 8 })
          .backgroundColor('#EEF4FF')
          .borderRadius(14);

        if (this.isPaperExpanded(paper.id)) {
          Column({ space: 10 }) {
            if (paper.translatedSummary) {
              Column({ space: 8 }) {
                Text('中文翻译')
                  .fontSize(14)
                  .fontWeight(FontWeight.Medium)
                  .fontColor('#2D6CE8');
                Text(paper.translatedSummary)
                  .fontSize(14)
                  .lineHeight(22)
                  .fontColor('#374151');
              }
              .width('100%')
              .padding(14)
              .backgroundColor('#F7FAFF')
              .borderRadius(16);
            }

            Column({ space: 8 }) {
              Text('Original Abstract')
                .fontSize(14)
                .fontWeight(FontWeight.Medium)
                .fontColor('#6B7280');
              Text(paper.summary)
                .fontSize(14)
                .lineHeight(22)
                .fontColor('#374151');
            }
            .width('100%')
            .padding(14)
            .backgroundColor('#F8FAFC')
            .borderRadius(16);

            if (this.vm.homeState.translationErrors[paper.id]) {
              Text(this.vm.homeState.translationErrors[paper.id])
                .fontSize(13)
                .lineHeight(20)
                .fontColor('#B6544A')
                .padding(12)
                .backgroundColor('#FFEAEA')
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
              void this.openPaperSource(paper);
            })
        )
      )
      .parallelGesture(
        SwipeGesture({ direction: SwipeDirection.Horizontal })
          .onAction((event: GestureEvent) => this.handlePaperSwipe(paper, event))
      );

      Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start, alignItems: ItemAlign.Center }) {
        Text(`${this.isPaperExpanded(paper.id) ? '›' : '›'} ${this.isPaperExpanded(paper.id) ? '收起摘要' : '展开摘要'}`)
          .fontSize(14)
          .fontColor('#2D6CE8')
          .padding({ left: 14, right: 14, top: 8, bottom: 8 })
          .margin({ right: 8, bottom: 8 })
          .backgroundColor('#EEF4FF')
          .borderRadius(12)
          .onClick(() => this.vm.toggleAbstract(paper.id));

        if (this.isPaperExpanded(paper.id)) {
          Text(`✦ ${this.isPaperTranslating(paper.id) ? '翻译中...' : '翻译'}`)
            .fontSize(14)
            .fontColor('#2D6CE8')
            .padding({ left: 14, right: 14, top: 8, bottom: 8 })
            .margin({ right: 8, bottom: 8 })
            .backgroundColor('#EEF4FF')
            .borderRadius(12)
            .opacity(this.isPaperTranslating(paper.id) ? 0.6 : 1)
            .onClick(() => {
              void this.vm.translatePaper(paper.id);
            });
        }

        Text(`☆ ${paper.favoriteState ? '取消收藏' : '收藏'}`)
          .fontSize(14)
          .fontColor('#2D6CE8')
          .padding({ left: 14, right: 14, top: 8, bottom: 8 })
          .margin({ right: 8, bottom: 8 })
          .backgroundColor('#EEF4FF')
          .borderRadius(12)
          .onClick(() => this.vm.toggleFavorite(paper.id));

        if (paper.zoteroSyncState !== 'synced') {
          Text(`↻ ${this.isPaperSyncing(paper.id) ? '同步中...' : '同步'}`)
            .fontSize(14)
            .fontColor('#2D6CE8')
            .padding({ left: 14, right: 14, top: 8, bottom: 8 })
            .margin({ right: 8, bottom: 8 })
            .backgroundColor('#EEF4FF')
            .borderRadius(12)
            .opacity(this.isPaperSyncing(paper.id) ? 0.6 : 1)
            .onClick(() => {
              void this.vm.syncToZotero(paper.id);
            });
        }
      }
    }
    .width('100%')
    .padding(18)
    .backgroundColor('#FFFFFF')
    .borderRadius(24)
    .border({ width: 1, color: '#E5EBF5' });
  }

  @Builder
  private emptyStateCard() {
    Column({ space: 10 }) {
      Text(this.emptyStateTitle())
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor('#111827');
      Text(this.emptyStateSubtitle())
        .fontSize(14)
        .lineHeight(22)
        .fontColor('#6B7280');
    }
    .alignItems(HorizontalAlign.Center)
    .width('100%')
    .padding({ left: 20, right: 20, top: 28, bottom: 28 })
    .backgroundColor('#FFFFFF')
    .borderRadius(20)
    .border({ width: 1, color: '#E5EBF5' });
  }

  build() {
    Column({ space: AppConstants.SECTION_SPACING }) {
      this.heroSection();
      this.exploreControlCard();

      if (this.vm.homeState.errorMessage) {
        Text(this.vm.homeState.errorMessage!)
          .fontSize(13)
          .lineHeight(20)
          .fontColor('#B6544A')
          .width('100%')
          .padding(12)
          .backgroundColor('#FFEAEA')
          .borderRadius(14);
      }

      if (this.vm.homeState.listWarning) {
        Text(this.vm.homeState.listWarning!)
          .fontSize(13)
          .lineHeight(20)
          .fontColor('#B37B3F')
          .width('100%')
          .padding(12)
          .backgroundColor('#FFF1DD')
          .borderRadius(14);
      }

      if (!this.vm.homeState.dismissedSummary) {
        this.trendSummaryCard();
      }

      if (this.vm.homeState.actionMessage) {
        Text(this.vm.homeState.actionMessage!.text)
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor('#FFFFFF')
          .padding({ left: 14, right: 14, top: 10, bottom: 10 })
          .backgroundColor('#1F2937')
          .borderRadius(999);
      }

      Column({ space: 12 }) {
        this.paperSectionHeader();

        if (this.vm.homeState.papers.length === 0) {
          this.emptyStateCard();
        } else {
          ForEach(this.vm.homeState.papers, (paper: PaperItem) => {
            this.paperCard(paper);
          }, (paper: PaperItem) => paper.id);
        }
      }
      .width('100%');

      if (this.isAddTagDialogVisible) {
        Column({ space: 12 }) {
          Text('添加自定义标签')
            .fontSize(18)
            .fontWeight(FontWeight.Medium)
            .fontColor('#111827');
          Text('输入研究方向，例如 embodied-ai。标签会作为关键词检索论文。')
            .fontSize(13)
            .fontColor('#6B7280');
          TextInput({
            placeholder: '标签名称',
            text: this.customTagDraft
          })
            .fontSize(15)
            .backgroundColor('#FFFFFF')
            .borderRadius(14)
            .border({ width: 1, color: '#D7DEE9' })
            .padding({ left: 14, right: 14, top: 12, bottom: 12 })
            .onChange((value: string) => this.customTagDraft = value);
          Row({ space: 8 }) {
            Text('添加')
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .fontColor('#FFFFFF')
              .padding({ left: 18, right: 18, top: 10, bottom: 10 })
              .backgroundColor('#2D6CE8')
              .borderRadius(14)
              .onClick(() => this.confirmAddCustomTag());
            Text('取消')
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .fontColor('#2D6CE8')
              .padding({ left: 18, right: 18, top: 10, bottom: 10 })
              .backgroundColor('#EAF2FF')
              .borderRadius(14)
              .onClick(() => this.hideAddTagDialog());
          }
        }
        .width('100%')
        .padding(16)
        .backgroundColor('#FFFFFF')
        .borderRadius(20)
        .border({ width: 1, color: '#E5EBF5' });
      }
    }
    .width('100%')
    .onClick(() => {
      if (this.pendingDeletionTag.length > 0) {
        this.clearPendingDeletion();
      }
    })
    .alignItems(HorizontalAlign.Start)
    .padding({ left: AppConstants.PAGE_HORIZONTAL_PADDING, right: AppConstants.PAGE_HORIZONTAL_PADDING, top: 20, bottom: 20 });
  }
}
