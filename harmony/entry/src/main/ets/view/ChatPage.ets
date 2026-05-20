import AppConstants from '../common/constants/AppConstants';
import Context from '@ohos.app.ability.application';
import { resolveXivPalette, XivThemePalette } from '../common/theme/XivTheme';
import { FavoritePaperItem, PaperChatMessage, PaperChatUsedPaper } from '../model/AppModels';
import { AppViewModel } from '../viewmodel/AppViewModel';

interface MarkdownBlock {
  id: string;
  kind: string;
  text: string;
  marker: string;
  level: number;
}

@Component
export struct ChatPage {
  @ObjectLink vm: AppViewModel;
  @State private isPickerExpanded: boolean = false;
  @State private isPickerDialogVisible: boolean = false;
  @State private composerDraft: string = '';
  private messageScroller: Scroller = new Scroller();

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

  // Harmony 端先做一层轻量 Markdown 分块，避免把原始标记直接暴露给用户。
  // 先把模型输出拆成轻量 Markdown 块，避免原始标记直接暴露给用户，同时保持鸿蒙端渲染稳定。
  private markdownBlocks(content: string): MarkdownBlock[] {
    const blocks: MarkdownBlock[] = [];
    const rawLines = content.replace(/\r\n/g, '\n').split('\n');
    let paragraphLines: string[] = [];
    let codeLines: string[] = [];
    let isInCodeFence = false;
    let blockIndex = 0;

    const pushParagraph = (): void => {
      if (paragraphLines.length === 0) {
        return;
      }
      blocks.push({
        id: `paragraph-${blockIndex}`,
        kind: 'paragraph',
        text: this.normalizeMarkdownInline(paragraphLines.join(' ')),
        marker: '',
        level: 0
      });
      blockIndex += 1;
      paragraphLines = [];
    };

    const pushCodeBlock = (): void => {
      if (codeLines.length === 0) {
        return;
      }
      blocks.push({
        id: `code-${blockIndex}`,
        kind: 'code',
        text: codeLines.join('\n'),
        marker: '',
        level: 0
      });
      blockIndex += 1;
      codeLines = [];
    };

    for (let i = 0; i < rawLines.length; i += 1) {
      const line = rawLines[i];
      const trimmedLine = line.trim();

      if (trimmedLine.startsWith('```')) {
        pushParagraph();
        if (isInCodeFence) {
          pushCodeBlock();
        }
        isInCodeFence = !isInCodeFence;
        continue;
      }

      if (isInCodeFence) {
        codeLines.push(line);
        continue;
      }

      if (trimmedLine.length === 0) {
        pushParagraph();
        continue;
      }

      if (trimmedLine.startsWith('# ')) {
        pushParagraph();
        blocks.push({
          id: `heading-${blockIndex}`,
          kind: 'heading',
          text: this.normalizeMarkdownInline(trimmedLine.slice(2)),
          marker: '',
          level: 1
        });
        blockIndex += 1;
        continue;
      }

      if (trimmedLine.startsWith('## ')) {
        pushParagraph();
        blocks.push({
          id: `heading-${blockIndex}`,
          kind: 'heading',
          text: this.normalizeMarkdownInline(trimmedLine.slice(3)),
          marker: '',
          level: 2
        });
        blockIndex += 1;
        continue;
      }

      if (trimmedLine.startsWith('### ')) {
        pushParagraph();
        blocks.push({
          id: `heading-${blockIndex}`,
          kind: 'heading',
          text: this.normalizeMarkdownInline(trimmedLine.slice(4)),
          marker: '',
          level: 3
        });
        blockIndex += 1;
        continue;
      }

      if (trimmedLine.startsWith('- ') || trimmedLine.startsWith('* ')) {
        pushParagraph();
        blocks.push({
          id: `bullet-${blockIndex}`,
          kind: 'bullet',
          text: this.normalizeMarkdownInline(trimmedLine.slice(2)),
          marker: '•',
          level: 0
        });
        blockIndex += 1;
        continue;
      }

      const orderedMatch = trimmedLine.match(/^(\d+)\.\s+(.+)$/);
      if (orderedMatch) {
        pushParagraph();
        blocks.push({
          id: `ordered-${blockIndex}`,
          kind: 'ordered',
          text: this.normalizeMarkdownInline(orderedMatch[2]),
          marker: `${orderedMatch[1]}.`,
          level: 0
        });
        blockIndex += 1;
        continue;
      }

      paragraphLines.push(trimmedLine);
    }

    pushParagraph();
    pushCodeBlock();

    if (blocks.length === 0) {
      blocks.push({
        id: 'paragraph-empty',
        kind: 'paragraph',
        text: this.normalizeMarkdownInline(content),
        marker: '',
        level: 0
      });
    }

    return blocks;
  }

  // 行内样式统一降级成纯文本，优先保证阅读稳定，再逐步补齐复杂 Markdown 能力。
  // 行内样式先统一降级成纯文本，优先保证阅读稳定，后续再逐步补齐更完整的 Markdown 能力。
  private normalizeMarkdownInline(text: string): string {
    return text
      .replace(/!\[([^\]]*)\]\(([^)]+)\)/g, '$1')
      .replace(/\[([^\]]+)\]\(([^)]+)\)/g, '$1')
      .replace(/`([^`]+)`/g, '$1')
      .replace(/(\*\*|__|~~)/g, '')
      .replace(/^\>\s?/g, '')
      .trim();
  }

  private pickerSummaryText(): string {
    const selected = this.selectedFavorites();
    if (selected.length === 0) {
      return `从 ${this.vm.chatState.favorites.length} 篇收藏论文中选择`;
    }
    return `已选 ${selected.length} 篇：${selected.map((favorite: FavoritePaperItem) => favorite.paper.title.slice(0, 12)).join(' / ')}`;
  }

  private syncComposerDraft(): void {
    this.composerDraft = this.vm.chatState.inputDraft;
  }

  private togglePickerExpanded(): void {
    this.isPickerExpanded = !this.isPickerExpanded;
  }

  private showPickerDialog(): void {
    this.isPickerDialogVisible = true;
  }

  private hidePickerDialog(): void {
    this.isPickerDialogVisible = false;
  }

  private togglePickerSelection(paperId: string): void {
    this.vm.toggleChatPaper(paperId);
  }

  private canSendMessage(): boolean {
    return !this.vm.chatState.isSending
      && this.vm.chatState.selectedPaperIds.length > 0
      && this.composerDraft.trim().length > 0;
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

  private submitComposer(): void {
    if (this.vm.chatState.isSending) {
      return;
    }
    this.vm.updateChatDraft(this.composerDraft);
    const sendTask = this.vm.sendChatMessage();
    // 只有真正进入发送态时才清空输入框；如果是未选论文或问题为空，就保留用户输入，
    // 让错误反馈和 Android 一样由 ViewModel 统一给出，而不是在 UI 层静默吞掉。
    if (this.vm.chatState.isSending) {
      this.composerDraft = '';
    }
    void sendTask;
  }

  @Builder
  private leadingPill() {
    Row() {
      Text('✦')
        .fontSize(16)
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
        .fontColor(this.palette().primary);
      Text(favorite.paper.title.slice(0, 18))
        .fontSize(13)
        .fontColor(this.palette().textPrimary);
      Text('×')
        .fontSize(13)
        .fontColor(this.palette().textSecondary);
    }
    .padding({ left: 12, right: 12, top: 8, bottom: 8 })
    .margin({ right: 8, bottom: 8 })
    .backgroundColor(this.palette().secondaryContainer)
    .borderRadius(12)
    .onClick(() => this.togglePickerSelection(favorite.paper.id));
  }

  @Builder
  private sourceStatusChip(usedPaper: PaperChatUsedPaper) {
    Row({ space: 6 }) {
      Row()
        .width(8)
        .height(8)
        .borderRadius(4)
        .backgroundColor(usedPaper.status === 'full_text' ? this.palette().success :
          usedPaper.status === 'summary_fallback' ? this.palette().warning : this.palette().info);
      Text(this.usedPaperStatusLabel(usedPaper.status))
        .fontSize(13)
        .fontColor(this.palette().textSecondary);
    }
    .padding({ left: 12, right: 12, top: 8, bottom: 8 })
    .margin({ right: 8, bottom: 8 })
    .backgroundColor(this.palette().surfaceVariant)
    .borderRadius(12);
  }

  private headingFontSize(level: number): number {
    if (level <= 1) {
      return 18;
    }
    if (level === 2) {
      return 16;
    }
    return 15;
  }

  @Builder
  private markdownBlock(block: MarkdownBlock) {
    if (block.kind === 'heading') {
      Text(block.text)
        .fontSize(this.headingFontSize(block.level))
        .fontWeight(FontWeight.Bold)
        .lineHeight(26)
        .fontColor(this.palette().textPrimary)
        .width('100%');
    } else if (block.kind === 'bullet' || block.kind === 'ordered') {
      Row({ space: 8 }) {
        Text(block.marker)
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.palette().textTertiary);
        Text(block.text)
          .fontSize(14)
          .lineHeight(22)
          .fontColor(this.palette().textTertiary)
          .layoutWeight(1);
      }
      .width('100%')
      .alignItems(VerticalAlign.Top);
    } else if (block.kind === 'code') {
      Text(block.text)
        .fontSize(13)
        .lineHeight(20)
        .fontColor(this.palette().textTertiary)
        .width('100%')
        .padding(12)
        .backgroundColor(this.palette().surfaceVariant)
        .borderRadius(12);
    } else {
      Text(block.text)
        .fontSize(14)
        .lineHeight(22)
        .fontColor(this.palette().textTertiary)
        .width('100%');
    }
  }

  @Builder
  private assistantMessageBody(content: string) {
    // 助手回复按块渲染，尽量贴近 Android 端的正文阅读体验。
    Column({ space: 10 }) {
      ForEach(this.markdownBlocks(content), (block: MarkdownBlock) => {
        this.markdownBlock(block);
      }, (block: MarkdownBlock) => block.id);
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start);
  }

  @Builder
  private paperPickerButton() {
    Row({ space: 10 }) {
      Text(this.pickerSummaryText())
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.palette().primary)
        .layoutWeight(1)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis });
      Text(this.isPickerExpanded ? '^' : 'v')
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.palette().primary);
    }
    .width('100%')
    .padding({ left: 14, right: 14, top: 12, bottom: 12 })
    .backgroundColor(this.palette().surfaceSubtle)
    .borderRadius(14)
    .border({ width: 1, color: this.palette().outline })
    .onClick(() => {
      this.togglePickerExpanded();
    });
  }

  @Builder
  private pickerOption(favorite: FavoritePaperItem) {
    // Android 端是下拉菜单里的整行切换，这里对齐成整行点击，避免全屏蒙层打断对话流。
    Row({ space: 12 }) {
      Row() {
        Text(this.isPaperSelected(favorite.paper.id) ? '✓' : '')
          .fontSize(14)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.palette().onPrimary);
      }
      .width(28)
      .height(28)
      .justifyContent(FlexAlign.Center)
      .backgroundColor(this.isPaperSelected(favorite.paper.id) ? this.palette().primary : this.palette().surface)
      .borderRadius(14)
      .border({
        width: 1.5,
        color: this.isPaperSelected(favorite.paper.id) ? this.palette().primary : this.palette().outline
      });

      Column({ space: 2 }) {
        Text(favorite.paper.title)
          .fontSize(15)
          .fontWeight(this.isPaperSelected(favorite.paper.id) ? FontWeight.Medium : FontWeight.Regular)
          .fontColor(this.palette().textPrimary)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis });
        Text(`${favorite.paper.primaryCategory} · ${favorite.savedAt.slice(0, 10)}`)
          .fontSize(12)
          .fontColor(this.palette().textSecondary);
      }
      .layoutWeight(1);

      Text(this.isPaperSelected(favorite.paper.id) ? '取消' : '选择')
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.isPaperSelected(favorite.paper.id) ? this.palette().primary : this.palette().onPrimary)
        .padding({ left: 12, right: 12, top: 8, bottom: 8 })
        .backgroundColor(this.isPaperSelected(favorite.paper.id) ? this.palette().primaryContainer : this.palette().primary)
        .borderRadius(10)
        .onClick(() => this.togglePickerSelection(favorite.paper.id));
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 14, bottom: 14 })
    .backgroundColor(this.isPaperSelected(favorite.paper.id) ? this.palette().surfaceSubtle : this.palette().surface)
    .borderRadius(14)
    .border({
      width: this.isPaperSelected(favorite.paper.id) ? 2 : 1,
      color: this.isPaperSelected(favorite.paper.id) ? this.palette().primary : this.palette().outline
    });
  }

  @Builder
  private inlinePickerOption(favorite: FavoritePaperItem) {
    Row({ space: 12 }) {
      Row() {
        Text(this.isPaperSelected(favorite.paper.id) ? 'v' : '')
          .fontSize(13)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.palette().onPrimary);
      }
      .width(24)
      .height(24)
      .justifyContent(FlexAlign.Center)
      .backgroundColor(this.isPaperSelected(favorite.paper.id) ? this.palette().primary : this.palette().surface)
      .borderRadius(12)
      .border({
        width: 1.5,
        color: this.isPaperSelected(favorite.paper.id) ? this.palette().primary : this.palette().outline
      });

      Column({ space: 2 }) {
        Text(favorite.paper.title)
          .fontSize(15)
          .fontWeight(this.isPaperSelected(favorite.paper.id) ? FontWeight.Medium : FontWeight.Regular)
          .fontColor(this.palette().textPrimary)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis });
        Text(`${favorite.paper.primaryCategory} 路 ${favorite.savedAt.slice(0, 10)}`)
          .fontSize(12)
          .fontColor(this.palette().textSecondary);
      }
      .layoutWeight(1);
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 14, bottom: 14 })
    .backgroundColor(this.isPaperSelected(favorite.paper.id) ? this.palette().surfaceSubtle : this.palette().surface)
    .borderRadius(14)
    .border({
      width: this.isPaperSelected(favorite.paper.id) ? 2 : 1,
      color: this.isPaperSelected(favorite.paper.id) ? this.palette().primary : this.palette().outline
    })
    .onClick(() => this.togglePickerSelection(favorite.paper.id));
  }

  @Builder
  private paperPickerCard() {
    Column({ space: 10 }) {
      Text('收藏论文')
        .fontSize(18)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.palette().textSecondary)
        .width('100%');
      if (this.vm.chatState.favorites.length === 0) {
        Text('收藏库为空')
          .fontSize(13)
          .fontColor(this.palette().textSecondary)
          .width('100%');
      } else {
        this.paperPickerButton();

        if (this.isPickerExpanded) {
          // Android 端这里是 DropdownMenu，Harmony 先收敛成按钮下方轻量展开面板，避免遮罩打断输入流。
          Column({ space: 8 }) {
            ForEach(this.vm.chatState.favorites, (favorite: FavoritePaperItem) => {
              this.inlinePickerOption(favorite);
            }, (favorite: FavoritePaperItem) => favorite.paper.id);
          }
          .width('100%')
          .padding(10)
          .backgroundColor(this.palette().surface)
          .borderRadius(18)
          .border({ width: 1, color: this.palette().outline });
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
    .alignItems(HorizontalAlign.Start);
  }

  @Builder
  private emptyStateCard() {
    Text('选择收藏论文后开始提问')
      .fontSize(16)
      .fontColor(this.palette().textSecondary)
      .width('100%')
      .padding({ left: 18, right: 18, top: 24, bottom: 24 })
    .backgroundColor(this.palette().surface)
    .borderRadius(20)
    .border({ width: 1, color: this.palette().outline });
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
  private pickerDialogCard() {
    if (this.isPickerDialogVisible) {
      Stack({ alignContent: Alignment.Center }) {
        this.dialogBackdrop(() => this.hidePickerDialog());
        Column({ space: 14 }) {
          Row() {
            Text('选择收藏论文')
              .fontSize(20)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.palette().textPrimary);
            Blank();
            Text('完成')
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.palette().primary)
              .onClick(() => this.hidePickerDialog());
          }
          .width('100%');

          Column({ space: 10 }) {
            ForEach(this.vm.chatState.favorites, (favorite: FavoritePaperItem) => {
              this.pickerOption(favorite);
            }, (favorite: FavoritePaperItem) => favorite.paper.id);
          }
          .width('100%');
        }
        .width('86%')
        .padding(18)
        .backgroundColor(this.palette().surface)
        .borderRadius(24)
        .border({ width: 1, color: this.palette().outline });
      }
      .width('100%')
      .height('100%');
    }
  }

  @Builder
  private messageCard(message: PaperChatMessage) {
    Row() {
      if (message.role === 'user') {
        Blank();
      }

      Column() {
        if (message.role === 'user') {
          Text(message.content)
            .fontSize(14)
            .lineHeight(22)
            .fontColor(this.palette().onPrimary)
            .width('100%');
        } else {
          this.assistantMessageBody(message.content);
        }
      }
      .width(message.role === 'user' ? '74%' : '82%')
      .padding(16)
      .backgroundColor(message.role === 'user' ? this.palette().primary : this.palette().surface)
      .borderRadius(18)
      .border({
        width: message.role === 'user' ? 0 : 1,
        color: this.palette().outline
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
      Row({ space: 10 }) {
        LoadingProgress()
          .width(18)
          .height(18)
          .color(this.palette().textSecondary);
        Text('正在思考中...')
          .fontSize(14)
          .fontColor(this.palette().textSecondary)
          .lineHeight(22);
      }
      .width('82%')
      .padding(16)
      .backgroundColor(this.palette().surface)
      .borderRadius(18)
      .border({ width: 1, color: this.palette().outline })
      .alignItems(VerticalAlign.Center);
      Blank();
    }
    .width('100%');
  }

  @Builder
  private messagesPanel() {
    Column({ space: 12 }) {
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
      .padding({ top: 2, bottom: 2 });
    }
    .width('100%')
    .layoutWeight(1);
  }

  @Builder
  private composerCard() {
    Row({ space: 12 }) {
      TextArea({
        placeholder: this.vm.chatState.isSending ? '正在整理论文材料...' : '向选中论文提问',
        text: this.composerDraft
      })
        .fontSize(15)
        .fontColor(this.palette().textPrimary)
        .placeholderColor(this.palette().textSecondary)
        .backgroundColor(this.palette().surfaceSubtle)
        .borderRadius(16)
        .border({ width: 1, color: this.palette().outline })
        .layoutWeight(1)
        .height(64)
        .enabled(!this.vm.chatState.isSending)
        .onChange((value: string) => {
          this.composerDraft = value;
          this.vm.updateChatDraft(value);
        })
        .onSubmit(() => this.submitComposer());

      Row() {
        SymbolGlyph($r('sys.symbol.paperplane_fill'))
          .fontSize(18)
          .fontColor([this.palette().onPrimary]);
      }
      .width(52)
      .height(52)
      .justifyContent(FlexAlign.Center)
      .backgroundColor(this.palette().primary)
      .borderRadius(26)
      .opacity(this.sendActionOpacity())
      .onClick(() => {
        this.submitComposer();
      });
    }
    .width('100%')
    .alignItems(VerticalAlign.Center);
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Column({ space: AppConstants.SECTION_SPACING }) {
        Row() {
          Column({ space: 4 }) {
            Text('论文对话')
              .fontSize(28)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.palette().textPrimary);
            Text(`已选 ${this.vm.chatState.selectedPaperIds.length} 篇 · 最多 ${AppConstants.MAX_CHAT_PAPERS} 篇`)
              .fontSize(14)
              .fontColor(this.palette().textSecondary);
          }
          Blank();
          Row({ space: 8 }) {
            Text('✕')
              .fontSize(13)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.palette().primary);
            Text('清空')
              .fontSize(13)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.palette().primary);
          }
          .padding({ left: 4, right: 4, top: 6, bottom: 6 })
          .onClick(() => this.vm.clearConversation());
          this.leadingPill();
        }
        .width('100%');

        this.paperPickerCard();

        if (this.vm.chatState.errorMessage) {
          this.feedbackStrip(this.vm.chatState.errorMessage!, this.palette().dangerContainer, this.palette().danger);
        }

        if (this.vm.chatState.warningMessage) {
          this.feedbackStrip(this.vm.chatState.warningMessage!, this.palette().secondaryContainer,
            this.palette().onSecondaryContainer);
        }

        if (this.vm.chatState.usedPapers.length > 0) {
          // Android 端只保留来源状态 pill，这里同步去掉“上下文来源”和论文标题。
          Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start, alignItems: ItemAlign.Center }) {
            ForEach(this.vm.chatState.usedPapers, (usedPaper: PaperChatUsedPaper) => {
              this.sourceStatusChip(usedPaper);
            }, (usedPaper: PaperChatUsedPaper) => usedPaper.paperId);
          }
          .width('100%');
        }

        this.messagesPanel();
        this.composerCard();
      }
      .width('100%')
      .height('100%')
      .alignItems(HorizontalAlign.Start)
      .padding({ left: AppConstants.PAGE_HORIZONTAL_PADDING, right: AppConstants.PAGE_HORIZONTAL_PADDING, top: 20, bottom: 20 })
      .onAppear(() => {
        this.syncComposerDraft();
      });

      this.pickerDialogCard();
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.palette().background);
  }
}

interface ColorModeConfig {
  colorMode?: string | number;
}

interface ContextWithColorMode extends Context {
  config?: ColorModeConfig;
}
