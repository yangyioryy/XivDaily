import AppConstants from '../common/constants/AppConstants';
import { FavoritePaperItem, PaperChatMessage, PaperChatUsedPaper } from '../model/AppModels';
import { AppViewModel } from '../viewmodel/AppViewModel';

@Component
export struct ChatPage {
  @ObjectLink vm: AppViewModel;

  private isPaperSelected(paperId: string): boolean {
    return this.vm.chatState.selectedPaperIds.indexOf(paperId) >= 0;
  }

  private selectedFavorites(): FavoritePaperItem[] {
    return this.vm.chatState.favorites.filter((favorite: FavoritePaperItem) => {
      return this.vm.chatState.selectedPaperIds.indexOf(favorite.paper.id) >= 0;
    });
  }

  private usedPaperStatusLabel(status: string): string {
    if (status === 'full_text') {
      return '全文';
    }
    if (status === 'summary_fallback') {
      return '摘要降级';
    }
    return '未读取';
  }

  @Builder
  private selectionChip(favorite: FavoritePaperItem) {
    Row({ space: 6 }) {
      Text(favorite.paper.title.slice(0, 12))
        .fontSize(13)
        .fontColor('#1F2937');
      Text('×')
        .fontSize(13)
        .fontColor('#6B7280');
    }
    .padding({ left: 12, right: 12, top: 8, bottom: 8 })
    .margin({ right: 8, bottom: 8 })
    .backgroundColor('#F1F4FA')
    .borderRadius(12)
    .onClick(() => this.vm.toggleChatPaper(favorite.paper.id));
  }

  @Builder
  private sourceStatusChip(usedPaper: PaperChatUsedPaper) {
    Row({ space: 6 }) {
      Text(usedPaper.status === 'full_text' ? '●' : '○')
        .fontSize(12)
        .fontColor(usedPaper.status === 'full_text' ? '#3F7A58' : '#B37B3F');
      Text(`${this.usedPaperStatusLabel(usedPaper.status)} · ${usedPaper.title.slice(0, 12)}`)
        .fontSize(13)
        .fontColor('#6B7280');
    }
    .padding({ left: 12, right: 12, top: 8, bottom: 8 })
    .margin({ right: 8, bottom: 8 })
    .backgroundColor('#FFFFFF')
    .borderRadius(12)
    .border({ width: 1, color: '#D7DEE9' });
  }

  @Builder
  private messageCard(message: PaperChatMessage) {
    Column({ space: 8 }) {
      Text(message.role === 'user' ? '你' : '助手')
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .fontColor(message.role === 'user' ? '#1D4ED8' : '#6B7280');
      Text(message.content)
        .fontSize(14)
        .lineHeight(22)
        .fontColor(message.role === 'user' ? '#111827' : '#374151')
        .width('100%');
    }
    .width('100%')
    .padding(16)
    .backgroundColor(message.role === 'user' ? '#EAF2FF' : '#FFFFFF')
    .borderRadius(16);
  }

  build() {
    Column({ space: AppConstants.SECTION_SPACING }) {
      Row() {
        Column({ space: 4 }) {
          Text('论文对话')
            .fontSize(28)
            .fontWeight(FontWeight.Bold)
            .fontColor('#111827');
          Text(`已选 ${this.vm.chatState.selectedPaperIds.length} 篇 · 最多 3 篇`)
            .fontSize(14)
            .fontColor('#6B7280');
        }
        Blank();
        Row({ space: 12 }) {
          Text('清空')
            .fontSize(15)
            .fontColor('#2D6CE8')
            .onClick(() => this.vm.clearConversation());
          Text('刷新')
            .fontSize(15)
            .fontColor('#2D6CE8')
            .onClick(() => this.vm.refreshFavorites());
        }
      }
      .width('100%');

      Column({ space: 10 }) {
        Text('收藏论文')
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .fontColor('#374151');

        if (this.selectedFavorites().length > 0) {
          Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start, alignItems: ItemAlign.Center }) {
            ForEach(this.selectedFavorites(), (favorite: FavoritePaperItem) => {
              this.selectionChip(favorite);
            }, (favorite: FavoritePaperItem) => favorite.paper.id);
          }
          .width('100%');
        }

        Column({ space: 10 }) {
          ForEach(this.vm.chatState.favorites, (favorite: FavoritePaperItem) => {
            Row() {
              Text(this.isPaperSelected(favorite.paper.id) ? '☑' : '☐')
                .fontSize(18)
                .fontColor('#2D6CE8')
                .margin({ right: 10 });
              Column({ space: 2 }) {
                Text(favorite.paper.title)
                  .fontSize(15)
                  .fontWeight(FontWeight.Medium)
                  .fontColor('#111827');
                Text(`${favorite.paper.primaryCategory} · ${favorite.savedAt}`)
                  .fontSize(12)
                  .fontColor('#6B7280');
              }
              .layoutWeight(1);
            }
            .width('100%')
            .padding(14)
            .backgroundColor('#FFFFFF')
            .borderRadius(16)
            .border({
              width: this.isPaperSelected(favorite.paper.id) ? 1.5 : 1,
              color: this.isPaperSelected(favorite.paper.id) ? '#2D6CE8' : '#D7DEE9'
            })
            .onClick(() => this.vm.toggleChatPaper(favorite.paper.id));
          }, (favorite: FavoritePaperItem) => favorite.paper.id);
        }
      }
      .width('100%');

      if (this.vm.chatState.errorMessage) {
        Text(this.vm.chatState.errorMessage!)
          .fontSize(13)
          .fontColor('#B6544A')
          .padding(12)
          .backgroundColor('#FFEAEA')
          .borderRadius(14);
      }

      if (this.vm.chatState.warningMessage) {
        Text(this.vm.chatState.warningMessage!)
          .fontSize(13)
          .fontColor('#B37B3F')
          .padding(12)
          .backgroundColor('#FFF1DD')
          .borderRadius(14);
      }

      if (this.vm.chatState.usedPapers.length > 0) {
        Column({ space: 10 }) {
          Text('上下文来源')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor('#374151');
          Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start, alignItems: ItemAlign.Center }) {
            ForEach(this.vm.chatState.usedPapers, (usedPaper: PaperChatUsedPaper) => {
              this.sourceStatusChip(usedPaper);
            }, (usedPaper: PaperChatUsedPaper) => usedPaper.paperId);
          }
          .width('100%');
        }
        .width('100%');
      }

      Column({ space: 10 }) {
        if (this.vm.chatState.messages.length === 0) {
          Text('选择收藏论文后开始提问')
            .fontSize(15)
            .fontColor('#9CA3AF')
            .width('100%')
            .padding(18)
            .backgroundColor('#FFFFFF')
            .borderRadius(18);
        } else {
          ForEach(this.vm.chatState.messages, (message: PaperChatMessage, index?: number) => {
            this.messageCard(message);
          }, (_: PaperChatMessage, index?: number) => `${index}`);
        }

        if (this.vm.chatState.isSending) {
          Text('正在思考中...')
            .fontSize(14)
            .fontColor('#6B7280')
            .width('100%')
            .padding(16)
            .backgroundColor('#FFFFFF')
            .borderRadius(16);
        }
      }
      .width('100%');

      Row({ space: 8 }) {
        TextArea({
          placeholder: this.vm.chatState.isSending ? '正在整理论文材料...' : '向选中论文提问',
          text: this.vm.chatState.inputDraft
        })
          .fontSize(15)
          .layoutWeight(1)
          .backgroundColor('#FFFFFF')
          .height(76)
          .enabled(!this.vm.chatState.isSending)
          .onChange((value: string) => this.vm.updateChatDraft(value))
          .onSubmit(() => this.vm.sendChatMessage());
        Text(this.vm.chatState.isSending ? '发送中' : '发送')
          .fontSize(15)
          .fontColor('#2D6CE8')
          .opacity(this.vm.chatState.isSending ? 0.6 : 1)
          .onClick(() => this.vm.sendChatMessage());
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 14, bottom: 14 })
      .backgroundColor('#FFFFFF')
      .borderRadius(16)
      .border({ width: 1, color: '#D7DEE9' });
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding({ left: AppConstants.PAGE_HORIZONTAL_PADDING, right: AppConstants.PAGE_HORIZONTAL_PADDING, top: 20, bottom: 20 });
  }
}
