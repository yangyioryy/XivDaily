import AppConstants from '../common/constants/AppConstants';
import { FavoritePaperItem, PaperChatMessage, PaperChatUsedPaper } from '../model/AppModels';
import { AppViewModel } from '../viewmodel/AppViewModel';

@Component
export struct ChatPage {
  @ObjectLink vm: AppViewModel;
  @State private pickerExpanded: boolean = false;
  private messageScroller: Scroller = new Scroller();

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

  private canSendMessage(): boolean {
    return !this.vm.chatState.isSending
      && this.vm.chatState.selectedPaperIds.length > 0
      && this.vm.chatState.inputDraft.trim().length > 0;
  }

  private composerHint(): string {
    if (this.vm.chatState.selectedPaperIds.length > 0) {
      return `将基于 ${this.vm.chatState.selectedPaperIds.length} 篇收藏论文回答`;
    }
    return '先选择收藏论文，再开始提问';
  }

  private sendActionOpacity(): number {
    if (this.vm.chatState.isSending) {
      return 0.6;
    }
    return this.canSendMessage() ? 1 : 0.72;
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
      .lineHeight(20)
      .fontColor(foregroundColor)
      .width('100%')
      .padding(12)
      .backgroundColor(backgroundColor)
      .borderRadius(14);
  }

  @Builder
  private selectionChip(favorite: FavoritePaperItem) {
    Row({ space: 6 }) {
      Text('✓')
        .fontSize(12)
        .fontColor('#2D6CE8');
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
      Text(`${this.usedPaperStatusLabel(usedPaper.status)} · ${usedPaper.title.slice(0, 14)}`)
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
      Column({ space: 4 }) {
        Text('选择引用论文')
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor('#111827');
        Text(this.pickerSummaryText())
          .fontSize(13)
          .fontColor('#6B7280')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis });
      }
      .layoutWeight(1);

      Text(this.pickerExpanded ? '收起' : '展开')
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .fontColor('#2D6CE8');
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 14, bottom: 14 })
    .backgroundColor('#F8FAFC')
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
    Column({ space: 12 }) {
      Row() {
        Column({ space: 4 }) {
          Text('收藏论文')
            .fontSize(20)
            .fontWeight(FontWeight.Medium)
            .fontColor('#111827');
          Text(`最多选择 ${AppConstants.MAX_CHAT_PAPERS} 篇，用于回答时构造上下文。`)
            .fontSize(13)
            .lineHeight(20)
            .fontColor('#6B7280');
        }
        Blank();
        Text(`已选 ${this.vm.chatState.selectedPaperIds.length}/${AppConstants.MAX_CHAT_PAPERS}`)
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor('#2D6CE8')
          .padding({ left: 10, right: 10, top: 6, bottom: 6 })
          .backgroundColor('#EAF2FF')
          .borderRadius(999);
      }
      .width('100%');

      if (this.vm.chatState.favorites.length === 0) {
        Text('收藏库为空。先去收藏库或首页收藏论文，再回到这里发起对话。')
          .fontSize(14)
          .lineHeight(22)
          .fontColor('#6B7280')
          .width('100%')
          .padding(14)
          .backgroundColor('#F8FAFC')
          .borderRadius(16);
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
    .width('100%')
    .padding(18)
    .backgroundColor('#FFFFFF')
    .borderRadius(24)
    .border({ width: 1, color: '#E5EBF5' });
  }

  @Builder
  private emptyStateCard() {
    Column({ space: 10 }) {
      this.leadingPill();
      Text('选择收藏论文后开始提问')
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor('#111827');
      Text('模型会结合选中的论文标题、摘要和可用全文生成回答。')
        .fontSize(14)
        .lineHeight(22)
        .fontColor('#6B7280')
        .textAlign(TextAlign.Center);
    }
    .width('100%')
    .padding({ left: 18, right: 18, top: 24, bottom: 24 })
    .backgroundColor('#FFFFFF')
    .borderRadius(20);
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
          .fontColor(message.role === 'user' ? '#DBEAFE' : '#6B7280');
        Text(message.content)
          .fontSize(14)
          .lineHeight(22)
          .fontColor(message.role === 'user' ? '#FFFFFF' : '#374151')
          .width('100%');
      }
      .width(message.role === 'user' ? '74%' : '82%')
      .padding(16)
      .backgroundColor(message.role === 'user' ? '#2D6CE8' : '#FFFFFF')
      .borderRadius(18)
      .border({
        width: message.role === 'user' ? 0 : 1,
        color: '#E5EBF5'
      });

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
      .width('82%')
      .padding(16)
      .backgroundColor('#FFFFFF')
      .borderRadius(18)
      .border({ width: 1, color: '#E5EBF5' });
      Blank();
    }
    .width('100%');
  }

  @Builder
  private messagesPanel() {
    Column({ space: 12 }) {
      Row() {
        Column({ space: 4 }) {
          Text('对话记录')
            .fontSize(20)
            .fontWeight(FontWeight.Medium)
            .fontColor('#111827');
          Text(this.vm.chatState.messages.length > 0 ? `当前共 ${this.vm.chatState.messages.length} 条消息` : '问题会结合已选论文的上下文回答。')
            .fontSize(13)
            .lineHeight(20)
            .fontColor('#6B7280');
        }
        Blank();
        if (this.vm.chatState.messages.length > 0) {
          Text('清空')
            .fontSize(13)
            .fontWeight(FontWeight.Medium)
            .fontColor('#2D6CE8')
            .padding({ left: 12, right: 12, top: 8, bottom: 8 })
            .backgroundColor('#F8FAFC')
            .borderRadius(999)
            .border({ width: 1, color: '#D7DEE9' })
            .onClick(() => this.vm.clearConversation());
        }
      }
      .width('100%');

      Scroll(this.messageScroller) {
        Column({ space: 10 }) {
          if (this.vm.chatState.messages.length === 0) {
            this.emptyStateCard();
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
      }
      .width('100%')
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .scrollable(ScrollDirection.Vertical)
      .padding(14)
      .backgroundColor('#F8FAFC')
      .borderRadius(20)
      .border({ width: 1, color: '#E5EBF5' });
    }
    .width('100%')
    .layoutWeight(1)
    .padding(18)
    .backgroundColor('#FFFFFF')
    .borderRadius(24)
    .border({ width: 1, color: '#E5EBF5' });
  }

  @Builder
  private composerCard() {
    Column({ space: 10 }) {
      TextArea({
        placeholder: this.vm.chatState.isSending ? '正在整理论文材料...' : '向选中论文提问',
        text: this.vm.chatState.inputDraft
      })
        .fontSize(15)
        .backgroundColor('#F8FAFC')
        .borderRadius(18)
        .border({ width: 1, color: '#D7DEE9' })
        .height(92)
        .enabled(!this.vm.chatState.isSending)
        .onChange((value: string) => this.vm.updateChatDraft(value))
        .onSubmit(() => this.vm.sendChatMessage());

      Row({ space: 12 }) {
        Text(this.composerHint())
          .fontSize(13)
          .fontColor('#6B7280')
          .layoutWeight(1);
        Text(this.vm.chatState.isSending ? '发送中...' : '发送')
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor('#FFFFFF')
          .padding({ left: 16, right: 16, top: 10, bottom: 10 })
          .backgroundColor('#2D6CE8')
          .borderRadius(14)
          .opacity(this.sendActionOpacity())
          .onClick(() => {
            if (!this.vm.chatState.isSending) {
              void this.vm.sendChatMessage();
            }
          });
      }
      .width('100%');
    }
    .width('100%')
    .padding(16)
    .backgroundColor('#FFFFFF')
    .borderRadius(24)
    .border({ width: 1, color: '#E5EBF5' });
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
        this.leadingPill();
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

      this.messagesPanel();
      this.composerCard();
    }
    .width('100%')
    .height('100%')
    .alignItems(HorizontalAlign.Start)
    .backgroundColor('#F7F9FD')
    .padding({ left: AppConstants.PAGE_HORIZONTAL_PADDING, right: AppConstants.PAGE_HORIZONTAL_PADDING, top: 20, bottom: 20 });
  }
}
