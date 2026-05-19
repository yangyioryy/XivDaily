import AppConstants from '../common/constants/AppConstants';
import { FavoritePaperItem, PaperChatMessage, PaperChatUsedPaper } from '../model/AppModels';
import { AppViewModel } from '../viewmodel/AppViewModel';

@Component
export struct ChatPage {
  @ObjectLink vm: AppViewModel;
  @State private pickerExpanded: boolean = false;

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

  private pickerSummaryText(): string {
    const selected = this.selectedFavorites();
    if (selected.length === 0) {
      return `从 ${this.vm.chatState.favorites.length} 篇收藏论文中选择`;
    }
    return `已选 ${selected.length} 篇：${selected.map((favorite: FavoritePaperItem) => favorite.paper.title.slice(0, 12)).join(' / ')}`;
  }

  @Builder
  private leadingPill() {
    Row() {
      Text('✦')
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor('#2D6CE8');
    }
    .width(32)
    .height(32)
    .justifyContent(FlexAlign.Center)
    .backgroundColor('#EAF2FF')
    .borderRadius(10);
  }

  @Builder
  private feedbackStrip(message: string, backgroundColor: string, foregroundColor: string) {
    Text(message)
      .fontSize(13)
      .fontColor(foregroundColor)
      .width('100%')
      .padding(12)
      .backgroundColor(backgroundColor)
      .borderRadius(14);
  }

  @Builder
  private selectionChip(favorite: FavoritePaperItem) {
    Row({ space: 6 }) {
      Text(favorite.paper.title.slice(0, 18))
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
      Row()
        .width(8)
        .height(8)
        .borderRadius(4)
        .backgroundColor(usedPaper.status === 'full_text' ? '#3F7A58' : usedPaper.status === 'summary_fallback' ? '#B37B3F' : '#2D6CE8');
      Text(`${this.usedPaperStatusLabel(usedPaper.status)} · ${usedPaper.title.slice(0, 12)}`)
        .fontSize(13)
        .fontColor('#6B7280');
    }
    .padding({ left: 12, right: 12, top: 8, bottom: 8 })
    .margin({ right: 8, bottom: 8 })
    .backgroundColor('#F1F4FA')
    .borderRadius(12);
  }

  @Builder
  private paperPickerButton() {
    Row({ space: 10 }) {
      Text(this.pickerSummaryText())
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor('#1F2937')
        .layoutWeight(1)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis });
      Text(this.pickerExpanded ? '▴' : '▾')
        .fontSize(14)
        .fontColor('#6B7280');
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 14, bottom: 14 })
    .backgroundColor('#FFFFFF')
    .borderRadius(16)
    .border({ width: 1, color: '#D7DEE9' })
    .onClick(() => {
      this.pickerExpanded = !this.pickerExpanded;
    });
  }

  @Builder
  private pickerOption(favorite: FavoritePaperItem) {
    Row({ space: 10 }) {
      Text(this.isPaperSelected(favorite.paper.id) ? '☑' : '☐')
        .fontSize(18)
        .fontColor('#2D6CE8');
      Column({ space: 2 }) {
        Text(favorite.paper.title)
          .fontSize(15)
          .fontWeight(this.isPaperSelected(favorite.paper.id) ? FontWeight.Medium : FontWeight.Regular)
          .fontColor('#111827')
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis });
        Text(`${favorite.paper.primaryCategory} · ${favorite.savedAt.slice(0, 10)}`)
          .fontSize(12)
          .fontColor('#6B7280');
      }
      .layoutWeight(1);
    }
    .width('100%')
    .padding({ left: 14, right: 14, top: 12, bottom: 12 })
    .backgroundColor(this.isPaperSelected(favorite.paper.id) ? '#F7FBFF' : '#FFFFFF')
    .borderRadius(14)
    .border({
      width: this.isPaperSelected(favorite.paper.id) ? 1.5 : 1,
      color: this.isPaperSelected(favorite.paper.id) ? '#2D6CE8' : '#E5E7EB'
    })
    .onClick(() => this.vm.toggleChatPaper(favorite.paper.id));
  }

  @Builder
  private paperPickerCard() {
    Column({ space: 10 }) {
      Text('收藏论文')
        .fontSize(18)
        .fontWeight(FontWeight.Medium)
        .fontColor('#374151');

      if (this.vm.chatState.favorites.length === 0) {
        Text('收藏库为空')
          .fontSize(14)
          .fontColor('#9CA3AF')
          .width('100%');
      } else {
        this.paperPickerButton();

        if (this.pickerExpanded) {
          Column({ space: 10 }) {
            ForEach(this.vm.chatState.favorites, (favorite: FavoritePaperItem) => {
              this.pickerOption(favorite);
            }, (favorite: FavoritePaperItem) => favorite.paper.id);
          }
          .width('100%');
        }

        if (this.selectedFavorites().length > 0) {
          Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start, alignItems: ItemAlign.Center }) {
            ForEach(this.selectedFavorites(), (favorite: FavoritePaperItem) => {
              this.selectionChip(favorite);
            }, (favorite: FavoritePaperItem) => favorite.paper.id);
          }
          .width('100%');
        }
      }
    }
    .width('100%');
  }

  @Builder
  private messageCard(message: PaperChatMessage) {
    Row() {
      if (message.role === 'user') {
        Blank();
      }

      Column({ space: 8 }) {
        Text(message.role === 'user' ? '你' : '助手')
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor(message.role === 'user' ? '#1D4ED8' : '#6B7280');
        Text(message.content)
          .fontSize(14)
          .lineHeight(22)
          .fontColor(message.role === 'user' ? '#FFFFFF' : '#374151')
          .width('100%');
      }
      .width('78%')
      .padding(16)
      .backgroundColor(message.role === 'user' ? '#2D6CE8' : '#FFFFFF')
      .borderRadius(16);

      if (message.role !== 'user') {
        Blank();
      }
    }
    .width('100%');
  }

  @Builder
  private thinkingBubble() {
    Row() {
      Column({ space: 8 }) {
        Text('助手')
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor('#6B7280');
        Text('正在思考中...')
          .fontSize(14)
          .fontColor('#6B7280')
          .width('100%');
      }
      .width('78%')
      .padding(16)
      .backgroundColor('#FFFFFF')
      .borderRadius(16);
      Blank();
    }
    .width('100%');
  }

  build() {
    Column({ space: AppConstants.SECTION_SPACING }) {
      Row() {
        Column({ space: 4 }) {
          Text('论文对话')
            .fontSize(28)
            .fontWeight(FontWeight.Bold)
            .fontColor('#111827');
          Text(`已选 ${this.vm.chatState.selectedPaperIds.length} 篇 · 最多 ${AppConstants.MAX_CHAT_PAPERS} 篇`)
            .fontSize(14)
            .fontColor('#6B7280');
        }
        Blank();
        Row({ space: 12 }) {
          Text('清空')
            .fontSize(15)
            .fontColor('#2D6CE8')
            .onClick(() => this.vm.clearConversation());
          this.leadingPill();
        }
      }
      .width('100%');

      this.paperPickerCard();

      if (this.vm.chatState.errorMessage) {
        this.feedbackStrip(this.vm.chatState.errorMessage!, '#FFEAEA', '#B6544A');
      }

      if (this.vm.chatState.warningMessage) {
        this.feedbackStrip(this.vm.chatState.warningMessage!, '#FFF1DD', '#B37B3F');
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
          this.thinkingBubble();
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
          .fontWeight(FontWeight.Medium)
          .fontColor('#2D6CE8')
          .padding({ left: 10, right: 10, top: 10, bottom: 10 })
          .backgroundColor('#EAF2FF')
          .borderRadius(14)
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
