import AppConstants from '../common/constants/AppConstants';
import Context from '@ohos.app.ability.application';
import { resolveXivPalette, XivThemePalette } from '../common/theme/XivTheme';
import { FavoritePaperItem } from '../model/AppModels';
import { AppViewModel } from '../viewmodel/AppViewModel';

class LibraryFilterOption {
  value: string;
  label: string;
  renderKey: string;

  constructor(value: string, label: string) {
    this.value = value;
    this.label = label;
    this.renderKey = `${value}:${label}`;
  }
}

@Component
export struct LibraryPage {
  @ObjectLink vm: AppViewModel;
  private listScroller: Scroller = new Scroller();

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

  private filteredFavorites(): FavoritePaperItem[] {
    if (this.vm.libraryState.syncFilter === 'all') {
      return this.vm.libraryState.favorites;
    }
    return this.vm.libraryState.favorites.filter((favorite: FavoritePaperItem) => {
      return favorite.paper.zoteroSyncState === this.vm.libraryState.syncFilter;
    });
  }

  private syncedCount(): number {
    return this.vm.libraryState.favorites.filter((favorite: FavoritePaperItem) => favorite.paper.zoteroSyncState === 'synced').length;
  }

  private unsyncedCount(): number {
    return this.vm.libraryState.favorites.filter((favorite: FavoritePaperItem) => favorite.paper.zoteroSyncState === 'not_synced').length;
  }

  private totalFavoriteCount(): number {
    return this.vm.libraryState.favorites.length;
  }

  private isPaperSelected(paperId: string): boolean {
    return this.vm.libraryState.selectedPaperIds.indexOf(paperId) >= 0;
  }

  private isSyncFilterSelected(filter: string): boolean {
    return this.vm.libraryState.syncFilter === filter;
  }

  private isPaperSyncing(paperId: string): boolean {
    return this.vm.libraryState.syncingPaperIds.indexOf(paperId) >= 0;
  }

  private filterLabel(): string {
    if (this.vm.libraryState.syncFilter === 'synced') {
      return '已同步';
    }
    if (this.vm.libraryState.syncFilter === 'failed') {
      return '同步失败';
    }
    if (this.vm.libraryState.syncFilter === 'not_synced') {
      return '待同步';
    }
    return '全部';
  }

  private visibleCountText(): string {
    return `共 ${this.totalFavoriteCount()} 条 · 当前展示 ${this.filteredFavorites().length} 条`;
  }

  private filterOptions(): LibraryFilterOption[] {
    return [
      new LibraryFilterOption('all', `全部 ${this.totalFavoriteCount()}`),
      new LibraryFilterOption('synced', `已同步 ${this.syncedCount()}`),
      new LibraryFilterOption('not_synced', `未同步 ${this.unsyncedCount()}`)
    ];
  }

  private syncStatusLabel(syncState: string): string {
    if (syncState === 'synced') {
      return '已同步';
    }
    if (syncState === 'failed') {
      return '同步失败';
    }
    return '待同步';
  }

  private syncStatusColor(syncState: string): string {
    // 收藏页状态圆点直接走语义色，和安卓端 status pill 的 synced/failed/pending 保持一致。
    if (syncState === 'synced') {
      return this.palette().success;
    }
    if (syncState === 'failed') {
      return this.palette().danger;
    }
    return this.palette().warning;
  }

  @Builder
  private leadingPill(iconText: string) {
    Row() {
      Text(iconText)
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.palette().primary);
    }
    .width(32)
    .height(32)
    .justifyContent(FlexAlign.Center)
    .backgroundColor(this.palette().primaryContainer)
    .borderRadius(10);
  }

  @Builder
  private heroSection() {
    Column({ space: 10 }) {
      Row() {
        Column({ space: 2 }) {
          Text('收藏库')
            .fontSize(22)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.palette().textPrimary);
          Text(`${this.filterLabel()} · ${this.filteredFavorites().length} 条`)
            .fontSize(13)
            .fontColor(this.palette().textSecondary);
        }
        Blank();
        Row({ space: 8 }) {
          this.leadingPill('⌕');
          this.leadingPill('▣');
        }
      }
      .width('100%');
    }
    .width('100%');
  }

  @Builder
  private filterChip(value: string, label: string) {
    Text(label)
      .fontSize(13)
      .fontWeight(this.isSyncFilterSelected(value) ? FontWeight.Medium : FontWeight.Regular)
      .fontColor(this.isSyncFilterSelected(value) ? this.palette().onPrimaryContainer : this.palette().textSecondary)
      .padding({ left: 14, right: 14, top: 8, bottom: 8 })
      .margin({ right: 8, bottom: 8 })
      .backgroundColor(this.isSyncFilterSelected(value) ? this.palette().primaryContainer : this.palette().surface)
      .borderRadius(14)
      .border({ width: 1, color: this.isSyncFilterSelected(value) ? this.palette().primary : this.palette().outline })
      .onClick(() => this.vm.selectLibraryFilter(value));
  }

  @Builder
  private filterToolbar() {
    Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start, alignItems: ItemAlign.Center }) {
      ForEach(this.filterOptions(), (item: LibraryFilterOption) => {
        this.filterChip(item.value, item.label);
      }, (item: LibraryFilterOption) => item.renderKey);
    }
    .width('100%');
  }

  @Builder
  private feedbackCard(title: string, message: string, backgroundColor: string, foregroundColor: string) {
    Column({ space: 4 }) {
      Text(title)
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .fontColor(foregroundColor);
      Text(message)
        .fontSize(13)
        .lineHeight(20)
        .fontColor(foregroundColor)
        .width('100%');
    }
    .width('100%')
    .padding(14)
    .backgroundColor(backgroundColor)
    .borderRadius(16)
    .border({ width: 1, color: this.palette().outline });
  }

  @Builder
  private exportCard(content: string) {
    Column({ space: 8 }) {
      Text('BibTeX 导出结果')
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.palette().onSecondaryContainer);
      Text('生成后可直接复制到你的文献管理工具中。')
        .fontSize(13)
        .fontColor(this.palette().onSecondaryContainer);
      Text(content.length > 0 ? content : '未导出任何条目')
        .fontSize(12)
        .lineHeight(18)
        .fontColor(this.palette().onSecondaryContainer)
        .width('100%');
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 14, bottom: 14 })
    .backgroundColor(this.palette().secondaryContainer)
    .borderRadius(16);
  }

  @Builder
  private emptyStateCard(title: string, subtitle: string) {
    Column({ space: 8 }) {
      this.leadingPill('▣');
      Text(title)
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.palette().textPrimary);
      Text(subtitle)
        .fontSize(13)
        .lineHeight(20)
        .fontColor(this.palette().textSecondary)
        .textAlign(TextAlign.Center);
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 18, bottom: 18 })
    .backgroundColor(this.palette().surface)
    .borderRadius(16);
  }

  @Builder
  private statusPill(label: string, color: string) {
    Row({ space: 6 }) {
      Row()
        .width(8)
        .height(8)
        .borderRadius(4)
        .backgroundColor(color);
      Text(label)
        .fontSize(12)
        .fontColor(this.palette().textSecondary);
    }
    .padding({ left: 10, right: 10, top: 6, bottom: 6 })
    .backgroundColor(this.palette().surfaceVariant)
    .borderRadius(10);
  }

  @Builder
  private favoriteCard(favorite: FavoritePaperItem) {
    Column({ space: 10 }) {
      Row({ space: 12 }) {
        Column({ space: 4 }) {
          Text(favorite.paper.title)
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.palette().textPrimary)
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis });
          Text(`收藏于 ${favorite.savedAt.slice(0, 10)}`)
            .fontSize(12)
            .fontColor(this.palette().textSecondary);
        }
        .layoutWeight(1);
        SymbolGlyph($r('sys.symbol.star_fill'))
          .fontSize(18)
          .fontColor([this.palette().warning]);
      }
      .width('100%');

      Row({ space: 8 }) {
        this.statusPill(this.syncStatusLabel(favorite.paper.zoteroSyncState), this.syncStatusColor(favorite.paper.zoteroSyncState));
        this.statusPill(this.isPaperSelected(favorite.paper.id) ? '已选中' : '点按可加入批量选择',
          this.isPaperSelected(favorite.paper.id) ? this.palette().primary : this.palette().outline);
        if (this.isPaperSyncing(favorite.paper.id)) {
          this.statusPill('同步中...', this.palette().primary);
        }
      }
      .width('100%');

      Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start, alignItems: ItemAlign.Center }) {
        Row({ space: 6 }) {
          SymbolGlyph($r('sys.symbol.paperplane_fill'))
            .fontSize(16)
            .fontColor([this.palette().onPrimaryContainer]);
          Text('对话')
            .fontSize(13)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.palette().onPrimaryContainer);
        }
          .padding({ left: 12, right: 12, top: 8, bottom: 8 })
          .margin({ right: 8, bottom: 8 })
          .backgroundColor(this.palette().primaryContainer)
          .borderRadius(10)
          .justifyContent(FlexAlign.Center)
          .alignItems(VerticalAlign.Center)
          .onClick(() => {
            this.vm.openChatFromLibrary(favorite.paper.id);
          });

        if (favorite.paper.zoteroSyncState !== 'synced') {
          Row({ space: 6 }) {
            if (this.isPaperSyncing(favorite.paper.id)) {
              LoadingProgress()
                .width(16)
                .height(16)
                .color(this.palette().onPrimaryContainer);
            } else {
              SymbolGlyph($r('sys.symbol.arrow_2_circlepath'))
                .fontSize(16)
                .fontColor([this.palette().onPrimaryContainer]);
            }
            Text(this.isPaperSyncing(favorite.paper.id) ? '同步中...' : '同步 Zotero')
              .fontSize(13)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.palette().onPrimaryContainer);
          }
            .padding({ left: 12, right: 12, top: 8, bottom: 8 })
            .margin({ right: 8, bottom: 8 })
            .backgroundColor(this.palette().primaryContainer)
            .borderRadius(10)
            .justifyContent(FlexAlign.Center)
            .alignItems(VerticalAlign.Center)
            .opacity(this.isPaperSyncing(favorite.paper.id) ? 0.65 : 1)
            .onClick(() => {
              if (!this.isPaperSyncing(favorite.paper.id)) {
                void this.vm.syncFavoriteToZotero(favorite.paper.id);
              }
            });
        }

        Row({ space: 6 }) {
          SymbolGlyph($r('sys.symbol.trash'))
            .fontSize(16)
            .fontColor([this.palette().danger]);
          Text('删除')
            .fontSize(13)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.palette().danger);
        }
          .padding({ left: 12, right: 12, top: 8, bottom: 8 })
          .margin({ right: 8, bottom: 8 })
          .backgroundColor(this.palette().dangerContainer)
          .borderRadius(10)
          .justifyContent(FlexAlign.Center)
          .alignItems(VerticalAlign.Center)
          .onClick(() => this.vm.deleteFavorite(favorite.paper.id));
      }
      .width('100%');
    }
    .width('100%')
    .padding(16)
    .backgroundColor(this.palette().surface)
    .borderRadius(20)
    .border({ width: 1, color: this.palette().outline })
    .onClick(() => this.vm.toggleLibrarySelection(favorite.paper.id));
  }

  private batchBarBackgroundColor(): string {
    return this.palette().textPrimary;
  }

  private batchBarForegroundColor(): string {
    return this.palette().surface;
  }

  @Builder
  private batchPrimaryActionButton(label: string, action: () => void, iconText?: string) {
    Row({ space: 6 }) {
      if (iconText !== undefined && iconText.length > 0) {
        Text(iconText)
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.palette().onPrimary);
      }
      Text(label)
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.palette().onPrimary);
    }
    .padding({ left: 14, right: 14, top: 10, bottom: 10 })
    .backgroundColor(this.palette().primary)
    .borderRadius(12)
    .alignItems(VerticalAlign.Center)
    .onClick(() => action());
  }

  @Builder
  private batchDangerActionButton(action: () => void) {
    Row() {
      SymbolGlyph($r('sys.symbol.trash'))
        .fontSize(14)
        .fontColor([this.palette().danger]);
    }
    .width(36)
    .height(36)
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
    .backgroundColor(this.palette().dangerContainer)
    .borderRadius(12)
    .onClick(() => action());
  }

  @Builder
  private batchBottomBar() {
    Row({ space: 8 }) {
      Text(`已选 ${this.vm.libraryState.selectedPaperIds.length}`)
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.batchBarForegroundColor())
        .layoutWeight(1);
      this.batchPrimaryActionButton('全选', () => {
        this.vm.selectAllLibraryPapers(this.filteredFavorites().map((favorite: FavoritePaperItem) => favorite.paper.id));
      });
      this.batchPrimaryActionButton('导出', () => {
        this.vm.exportSelectedBibtex();
      }, '↓');
      this.batchDangerActionButton(() => {
        this.vm.deleteSelectedFavorites();
      });
    }
    .width('100%')
    .padding(12)
    .backgroundColor(this.batchBarBackgroundColor())
    .borderRadius(18);
  }

  @Builder
  private listSection() {
    Column({ space: 12 }) {
      Text('收藏论文')
        .fontSize(22)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.palette().textPrimary)
        .width('100%');

      if (this.totalFavoriteCount() > 0 && this.filteredFavorites().length > 0) {
        Text(this.visibleCountText())
          .fontSize(13)
          .fontColor(this.palette().textSecondary)
          .width('100%');
      }

      Scroll(this.listScroller) {
        Column({ space: 12 }) {
          if (this.totalFavoriteCount() === 0) {
            this.emptyStateCard('还没有收藏论文', '在首页收藏感兴趣的论文后，这里会成为你的研究资料库。');
          } else if (this.filteredFavorites().length === 0) {
            this.emptyStateCard('当前筛选下没有结果', '可以切换同步状态，或者检查导出与同步后的收藏记录。');
          } else {
            ForEach(this.filteredFavorites(), (favorite: FavoritePaperItem) => {
              this.favoriteCard(favorite);
            }, (favorite: FavoritePaperItem) => favorite.paper.id);
          }
        }
        .width('100%');
      }
      .width('100%')
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .scrollable(ScrollDirection.Vertical)
      .padding(2);
    }
    .width('100%')
    .layoutWeight(1);
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      Column({ space: AppConstants.SECTION_SPACING }) {
        this.heroSection();
        this.filterToolbar();

        if (this.vm.libraryState.actionMessage) {
          this.feedbackCard('操作反馈', this.vm.libraryState.actionMessage!, this.palette().primaryContainer,
            this.palette().onPrimaryContainer);
        }

        if (this.vm.libraryState.errorMessage) {
          this.feedbackCard('操作提醒', this.vm.libraryState.errorMessage!, this.palette().dangerContainer,
            this.palette().danger);
        }

        if (this.vm.libraryState.exportContent) {
          this.exportCard(this.vm.libraryState.exportContent!);
        }

        this.listSection();
      }
      .width('100%')
      .height('100%')
      .alignItems(HorizontalAlign.Start)
      .backgroundColor(this.palette().background)
      .padding({
        left: AppConstants.PAGE_HORIZONTAL_PADDING,
        right: AppConstants.PAGE_HORIZONTAL_PADDING,
        top: 20,
        bottom: this.vm.libraryState.selectedPaperIds.length > 0 ? 108 : 20
      });

      if (this.vm.libraryState.selectedPaperIds.length > 0) {
        Row() {
          this.batchBottomBar();
        }
        .width('100%')
        .padding({ left: AppConstants.PAGE_HORIZONTAL_PADDING, right: AppConstants.PAGE_HORIZONTAL_PADDING, bottom: 20 });
      }
    }
    .width('100%')
    .height('100%');
  }
}

interface ColorModeConfig {
  colorMode?: string | number;
}

interface ContextWithColorMode extends Context {
  config?: ColorModeConfig;
}
