import AppConstants from '../common/constants/AppConstants';
import { FavoritePaperItem } from '../model/AppModels';
import { AppViewModel } from '../viewmodel/AppViewModel';

@Component
export struct LibraryPage {
  @ObjectLink vm: AppViewModel;

  private filteredFavorites(): FavoritePaperItem[] {
    if (this.vm.libraryState.syncFilter === 'all') {
      return this.vm.libraryState.favorites;
    }
    return this.vm.libraryState.favorites.filter((favorite: FavoritePaperItem) => {
      return favorite.paper.zoteroSyncState === this.vm.libraryState.syncFilter;
    });
  }

  build() {
    const filtered = this.filteredFavorites();
    Column({ space: AppConstants.SECTION_SPACING }) {
      Column({ space: 4 }) {
        Text('收藏库')
          .fontSize(28)
          .fontWeight(FontWeight.Bold)
          .fontColor('#111827');
        Text(`全部 · ${this.vm.libraryState.favorites.length} 条`)
          .fontSize(14)
          .fontColor('#6B7280');
      }

      Row({ space: 8 }) {
        Text(`全部 ${this.vm.libraryState.favorites.length}`)
          .fontSize(14)
          .fontWeight(this.vm.libraryState.syncFilter === 'all' ? FontWeight.Medium : FontWeight.Regular)
          .fontColor('#1F2937')
          .padding({ left: 16, right: 16, top: 8, bottom: 8 })
          .backgroundColor(this.vm.libraryState.syncFilter === 'all' ? '#F1F4FA' : '#FFFFFF')
          .borderRadius(12)
          .border({ width: 1, color: '#D7DEE9' })
          .onClick(() => this.vm.selectLibraryFilter('all'));
        Text('已同步')
          .fontSize(14)
          .fontColor('#6B7280')
          .padding({ left: 16, right: 16, top: 8, bottom: 8 })
          .backgroundColor(this.vm.libraryState.syncFilter === 'synced' ? '#F1F4FA' : '#FFFFFF')
          .borderRadius(12)
          .border({ width: 1, color: '#D7DEE9' })
          .onClick(() => this.vm.selectLibraryFilter('synced'));
        Text('未同步')
          .fontSize(14)
          .fontColor('#6B7280')
          .padding({ left: 16, right: 16, top: 8, bottom: 8 })
          .backgroundColor(this.vm.libraryState.syncFilter === 'not_synced' ? '#F1F4FA' : '#FFFFFF')
          .borderRadius(12)
          .border({ width: 1, color: '#D7DEE9' })
          .onClick(() => this.vm.selectLibraryFilter('not_synced'));
      }

      if (this.vm.libraryState.actionMessage) {
        Text(this.vm.libraryState.actionMessage!)
          .fontSize(13)
          .fontColor('#2D6CE8')
          .padding(12)
          .backgroundColor('#EAF2FF')
          .borderRadius(14);
      }

      if (this.vm.libraryState.errorMessage) {
        Text(this.vm.libraryState.errorMessage!)
          .fontSize(13)
          .fontColor('#B6544A')
          .padding(12)
          .backgroundColor('#FFEAEA')
          .borderRadius(14);
      }

      if (this.vm.libraryState.exportContent) {
        Text(this.vm.libraryState.exportContent!)
          .fontSize(12)
          .fontColor('#374151')
          .padding(12)
          .backgroundColor('#FFFFFF')
          .borderRadius(14);
      }

      Column({ space: 12 }) {
        Text('收藏论文')
          .fontSize(24)
          .fontWeight(FontWeight.Medium)
          .fontColor('#111827');
        Text(`共 ${this.vm.libraryState.favorites.length} 条 · 当前展示 ${filtered.length} 条`)
          .fontSize(14)
          .fontColor('#6B7280');
      }
      .width('100%');

      if (filtered.length === 0) {
        Text('当前筛选下没有结果。')
          .fontSize(14)
          .fontColor('#6B7280')
          .width('100%')
          .padding(16)
          .backgroundColor('#FFFFFF')
          .borderRadius(16);
      } else {
        Column({ space: 12 }) {
          ForEach(filtered, (favorite: FavoritePaperItem) => {
            const selected = this.vm.libraryState.selectedPaperIds.indexOf(favorite.paper.id) >= 0;
            Column({ space: 12 }) {
              Row() {
                Text(favorite.paper.title)
                  .fontSize(18)
                  .fontWeight(FontWeight.Medium)
                  .fontColor('#111827')
                  .layoutWeight(1);
                Text(selected ? '☑' : '☐')
                  .fontSize(18)
                  .fontColor('#2D6CE8')
                  .onClick(() => this.vm.toggleLibrarySelection(favorite.paper.id));
              }
              .width('100%');

              Text(`收藏于 ${favorite.savedAt}`)
                .fontSize(13)
                .fontColor('#6B7280');

              Row({ space: 8 }) {
                Text(favorite.paper.zoteroSyncState === 'synced' ? '● 已同步' : '● 未同步')
                  .fontSize(13)
                  .fontColor(favorite.paper.zoteroSyncState === 'synced' ? '#3F7A58' : '#B37B3F')
                  .padding({ left: 14, right: 14, top: 8, bottom: 8 })
                  .backgroundColor('#F1F4FA')
                  .borderRadius(12);
                Text(selected ? '已选中' : '点按可加入批量选择')
                  .fontSize(13)
                  .fontColor(selected ? '#2D6CE8' : '#9CA3AF')
                  .padding({ left: 14, right: 14, top: 8, bottom: 8 })
                  .backgroundColor('#F1F4FA')
                  .borderRadius(12)
                  .onClick(() => this.vm.toggleLibrarySelection(favorite.paper.id));
              }

              Row({ space: 10 }) {
                Text('对话')
                  .fontSize(15)
                  .fontWeight(FontWeight.Medium)
                  .fontColor('#1D4ED8')
                  .padding({ left: 20, right: 20, top: 10, bottom: 10 })
                  .backgroundColor('#EAF2FF')
                  .borderRadius(14)
                  .onClick(() => {
                    this.vm.selectTab(2);
                    this.vm.toggleChatPaper(favorite.paper.id);
                  });
                Text('删除')
                  .fontSize(15)
                  .fontWeight(FontWeight.Medium)
                  .fontColor('#B6544A')
                  .padding({ left: 20, right: 20, top: 10, bottom: 10 })
                  .backgroundColor('#FFF1DD')
                  .borderRadius(14)
                  .onClick(() => this.vm.deleteFavorite(favorite.paper.id));
              }
            }
            .width('100%')
            .padding(16)
            .backgroundColor('#FFFFFF')
            .borderRadius(20);
          }, (favorite: FavoritePaperItem) => favorite.paper.id);
        }
        .width('100%');
      }

      if (this.vm.libraryState.selectedPaperIds.length > 0) {
        Row({ space: 10 }) {
          Text(`已选 ${this.vm.libraryState.selectedPaperIds.length}`)
            .fontSize(14)
            .fontColor('#111827')
            .layoutWeight(1);
          Text('导出 BibTeX')
            .fontSize(14)
            .fontColor('#2D6CE8')
            .onClick(() => this.vm.exportSelectedBibtex());
        }
        .width('100%')
        .padding(16)
        .backgroundColor('#FFFFFF')
        .borderRadius(16);
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding({ left: AppConstants.PAGE_HORIZONTAL_PADDING, right: AppConstants.PAGE_HORIZONTAL_PADDING, top: 20, bottom: 20 });
  }
}
