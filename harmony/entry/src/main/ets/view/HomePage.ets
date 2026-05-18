import AppConstants from '../common/constants/AppConstants';
import { PaperItem } from '../model/AppModels';
import { AppViewModel } from '../viewmodel/AppViewModel';

@Component
export struct HomePage {
  @ObjectLink vm: AppViewModel;

  private dayLabel(days: number): string {
    return days === 1 ? '24h' : `${days} 天`;
  }

  private summaryTitle(): string {
    if (this.vm.homeState.trendSummary?.items.length) {
      return this.vm.homeState.trendSummary!.items[0].trendTitle;
    }
    return '暂无趋势主题';
  }

  @Builder
  private paperCard(paper: PaperItem) {
    const expanded = this.vm.homeState.expandedAbstractPaperIds.indexOf(paper.id) >= 0;
    Column({ space: 10 }) {
      Row() {
        Text(paper.title)
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .fontColor('#111827')
          .layoutWeight(1);
        Text(paper.favoriteState ? '★' : '☆')
          .fontSize(18)
          .fontColor('#B37B3F')
          .onClick(() => this.vm.toggleFavorite(paper.id));
      }
      .width('100%');

      Text(`${paper.authors.join(', ')} · ${paper.primaryCategory} · ${paper.publishedAt}`)
        .fontSize(13)
        .fontColor('#6B7280');

      if (expanded) {
        Column({ space: 8 }) {
          if (paper.translatedSummary) {
            Text('中文翻译')
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .fontColor('#2D6CE8');
            Text(paper.translatedSummary)
              .fontSize(14)
              .lineHeight(22)
              .fontColor('#374151');
          }
          Text('Original Abstract')
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor('#6B7280');
          Text(paper.summary)
            .fontSize(14)
            .lineHeight(22)
            .fontColor('#374151');
        }
        .width('100%');
      }

      Row({ space: 8 }) {
        Text(expanded ? '收起摘要' : '展开摘要')
          .fontSize(14)
          .fontColor('#2D6CE8')
          .padding({ left: 14, right: 14, top: 8, bottom: 8 })
          .backgroundColor('#EAF2FF')
          .borderRadius(12)
          .onClick(() => this.vm.toggleAbstract(paper.id));

        if (expanded) {
          Text('翻译')
            .fontSize(14)
            .fontColor('#2D6CE8')
            .padding({ left: 14, right: 14, top: 8, bottom: 8 })
            .backgroundColor('#EAF2FF')
            .borderRadius(12)
            .onClick(() => this.vm.translatePaper(paper.id));
        }
      }
    }
    .width('100%')
    .padding(16)
    .backgroundColor('#FFFFFF')
    .borderRadius(20);
  }

  build() {
    Column({ space: AppConstants.SECTION_SPACING }) {
      Column({ space: 8 }) {
        Row() {
          Text('首页')
            .fontSize(28)
            .fontWeight(FontWeight.Bold)
            .fontColor('#111827');
          Blank();
          Text('刷新')
            .fontSize(15)
            .fontColor('#2D6CE8')
            .onClick(() => this.vm.refreshHome());
        }
        .width('100%');

        Text('围绕当天筛选范围快速浏览、收藏和同步论文。')
          .fontSize(14)
          .fontColor('#6B7280');
      }

      Column({ space: 12 }) {
        // 这里先用轻量输入条占位，后续再替换成真正的 ArkUI 输入框。
        Row({ space: 8 }) {
          Text('🔎')
            .fontSize(18);
          Text(this.vm.homeState.searchKeywordDraft.length > 0 ? this.vm.homeState.searchKeywordDraft : '搜索论文、作者、关键词')
            .fontSize(16)
            .fontColor(this.vm.homeState.searchKeywordDraft.length > 0 ? '#111827' : '#6B7280')
            .layoutWeight(1)
            .onClick(() => this.vm.updateSearchKeywordDraft('multimodal'));
          Text(this.vm.homeState.searchKeyword.length > 0 ? '清空' : '搜索')
            .fontSize(15)
            .fontColor('#2D6CE8')
            .onClick(() => this.vm.homeState.searchKeyword.length > 0 ? this.vm.clearSearch() : this.vm.submitSearch());
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 14, bottom: 14 })
        .backgroundColor('#FFFFFF')
        .borderRadius(16)
        .border({ width: 1, color: '#D7DEE9' });

        Text('领域')
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .fontColor('#374151')
          .width('100%');

        Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start, alignItems: ItemAlign.Center }) {
          ForEach(this.vm.homeState.categories, (category: string) => {
            const selected = this.vm.homeState.selectedCategory === category;
            Text(category)
              .fontSize(14)
              .fontWeight(selected ? FontWeight.Medium : FontWeight.Regular)
              .fontColor(selected ? '#FFFFFF' : '#1F2937')
              .padding({ left: 16, right: 16, top: 8, bottom: 8 })
              .margin({ right: 8, bottom: 8 })
              .backgroundColor(selected ? '#2D6CE8' : '#FFFFFF')
              .borderRadius(14)
              .border({
                width: selected ? 0 : 1,
                color: '#D7DEE9'
              })
              .onClick(() => this.vm.selectCategory(category));
          }, (category: string) => category);
        }
        .width('100%');

        Text('时间')
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .fontColor('#374151')
          .width('100%');

        Row({ space: 8 }) {
          ForEach(this.vm.homeState.dayOptions, (days: number) => {
            const selected = this.vm.homeState.selectedDays === days;
            Text(this.dayLabel(days))
              .fontSize(14)
              .fontWeight(selected ? FontWeight.Medium : FontWeight.Regular)
              .fontColor(selected ? '#1F2937' : '#6B7280')
              .padding({ left: 16, right: 16, top: 8, bottom: 8 })
              .backgroundColor(selected ? '#F1F4FA' : '#FFFFFF')
              .borderRadius(12)
              .border({ width: 1, color: '#D7DEE9' })
              .onClick(() => this.vm.selectDays(days));
          }, (days: number) => `${days}`);
        }
      }

      if (this.vm.homeState.actionMessage) {
        Text(this.vm.homeState.actionMessage!.text)
          .fontSize(13)
          .fontColor('#2D6CE8')
          .padding(12)
          .backgroundColor('#EAF2FF')
          .borderRadius(14);
      }

      if (this.vm.homeState.listWarning) {
        Text(this.vm.homeState.listWarning!)
          .fontSize(13)
          .fontColor('#B37B3F')
          .padding(12)
          .backgroundColor('#FFF1DD')
          .borderRadius(14);
      }

      if (this.vm.homeState.errorMessage) {
        Text(this.vm.homeState.errorMessage!)
          .fontSize(13)
          .fontColor('#B6544A')
          .padding(12)
          .backgroundColor('#FFEAEA')
          .borderRadius(14);
      }

      if (!this.vm.homeState.dismissedSummary && this.vm.homeState.trendSummary) {
        Column({ space: 12 }) {
          Row() {
            Column({ space: 4 }) {
              Text('AI 趋势简报')
                .fontSize(24)
                .fontWeight(FontWeight.Medium)
                .fontColor('#111827');
              Text(`最近 3 天 · ${this.vm.homeState.selectedCategory}`)
                .fontSize(13)
                .fontColor('#6B7280');
            }
            Blank();
            Text('关闭')
              .fontSize(15)
              .fontColor('#2D6CE8')
              .onClick(() => this.vm.dismissSummary());
          }
          .width('100%');

          Text(this.vm.homeState.trendSummary!.intro)
            .fontSize(15)
            .lineHeight(24)
            .fontColor('#374151')
            .width('100%')
            .padding(16)
            .backgroundColor('#FFFFFF')
            .borderRadius(16);

          if (this.vm.homeState.summaryExpanded) {
            Column({ space: 12 }) {
              ForEach(this.vm.homeState.trendSummary!.items, (item) => {
                Column({ space: 6 }) {
                  Text(`${item.rank}. ${item.trendTitle}`)
                    .fontSize(18)
                    .fontWeight(FontWeight.Medium)
                    .fontColor('#1F2937');
                  Text(item.summary)
                    .fontSize(14)
                    .lineHeight(22)
                    .fontColor('#6B7280');
                }
                .width('100%');
              }, (item) => `${item.rank}`);
            }
            .width('100%');
          }

          Text(this.vm.homeState.summaryExpanded ? '收起趋势详情' : '展开趋势详情')
            .fontSize(14)
            .fontColor('#2D6CE8')
            .onClick(() => this.vm.toggleSummaryExpanded());
        }
        .width('100%')
        .padding(16)
        .backgroundColor('#EAF2FF')
        .borderRadius(20);
      }

      Column({ space: 12 }) {
        Text(this.vm.homeState.isLoading ? '论文加载中...' : `论文列表 · ${this.vm.homeState.listStatus}`)
          .fontSize(24)
          .fontWeight(FontWeight.Medium)
          .fontColor('#111827');

        if (this.vm.homeState.papers.length === 0) {
          Text('当前暂无可展示论文，可以切换领域或时间窗口。')
            .fontSize(14)
            .fontColor('#6B7280')
            .width('100%')
            .padding(16)
            .backgroundColor('#FFFFFF')
            .borderRadius(16);
        } else {
          ForEach(this.vm.homeState.papers, (paper: PaperItem) => {
            this.paperCard(paper);
          }, (paper: PaperItem) => paper.id);
        }
      }
      .width('100%');
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding({ left: AppConstants.PAGE_HORIZONTAL_PADDING, right: AppConstants.PAGE_HORIZONTAL_PADDING, top: 20, bottom: 20 });
  }
}
