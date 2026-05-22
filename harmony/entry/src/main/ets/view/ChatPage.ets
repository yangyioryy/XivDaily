import AppConstants from '../common/constants/AppConstants';
import Context from '@ohos.app.ability.application';
import common from '@ohos.app.ability.common';
import { resolveXivPalette, XivThemePalette } from '../common/theme/XivTheme';
import { FavoritePaperItem, PaperChatMessage, PaperChatUsedPaper } from '../model/AppModels';
import { AppViewModel } from '../viewmodel/AppViewModel';

interface MarkdownInlineSegment {
  id: string;
  kind: string;
  text: string;
  url?: string;
}

interface MarkdownLinkRef {
  label: string;
  url: string;
}

interface MarkdownBlock {
  id: string;
  kind: string;
  text: string;
  marker: string;
  level: number;
  linkUrl?: string;
  segments?: MarkdownInlineSegment[];
  links?: MarkdownLinkRef[];
}

@Component
export struct ChatPage {
  @ObjectLink vm: AppViewModel;
  @State private isPickerExpanded: boolean = false;
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

  private showToast(message: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({
        message: message
      });
    } catch (error) {
    }
  }

  private async openExternalLink(url: string): Promise<void> {
    const hostContext = this.getUIContext().getHostContext();
    if (!hostContext || url.trim().length === 0) {
      this.showToast('链接暂不可用');
      return;
    }

    try {
      await (hostContext as common.UIAbilityContext).openLink(url.trim());
    } catch (error) {
      this.showToast('打开链接失败');
    }
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
      // Android 端的 Markdown 会保留段内换行，这里不要再把多行段落压成一行。
      const paragraphMarkdown = paragraphLines.join('\n').trim();
      const standaloneLink = this.extractStandaloneLink(paragraphMarkdown);
      const parsedParagraph = this.parseInlineMarkdown(paragraphMarkdown, `paragraph-${blockIndex}`);
      blocks.push({
        id: `paragraph-${blockIndex}`,
        kind: standaloneLink ? 'link' : 'paragraph',
        text: standaloneLink?.label ?? parsedParagraph.plainText,
        marker: '',
        level: 0,
        linkUrl: standaloneLink?.url,
        segments: standaloneLink ? undefined : parsedParagraph.segments,
        links: standaloneLink ? undefined : parsedParagraph.links
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
        const parsedHeading = this.parseInlineMarkdown(trimmedLine.slice(2), `heading-${blockIndex}`);
        blocks.push({
          id: `heading-${blockIndex}`,
          kind: 'heading',
          text: parsedHeading.plainText,
          marker: '',
          level: 1,
          segments: parsedHeading.segments,
          links: parsedHeading.links
        });
        blockIndex += 1;
        continue;
      }

      if (trimmedLine.startsWith('## ')) {
        pushParagraph();
        const parsedHeading = this.parseInlineMarkdown(trimmedLine.slice(3), `heading-${blockIndex}`);
        blocks.push({
          id: `heading-${blockIndex}`,
          kind: 'heading',
          text: parsedHeading.plainText,
          marker: '',
          level: 2,
          segments: parsedHeading.segments,
          links: parsedHeading.links
        });
        blockIndex += 1;
        continue;
      }

      if (trimmedLine.startsWith('### ')) {
        pushParagraph();
        const parsedHeading = this.parseInlineMarkdown(trimmedLine.slice(4), `heading-${blockIndex}`);
        blocks.push({
          id: `heading-${blockIndex}`,
          kind: 'heading',
          text: parsedHeading.plainText,
          marker: '',
          level: 3,
          segments: parsedHeading.segments,
          links: parsedHeading.links
        });
        blockIndex += 1;
        continue;
      }

      if (trimmedLine.startsWith('> ')) {
        pushParagraph();
        const parsedQuote = this.parseInlineMarkdown(trimmedLine.slice(2), `quote-${blockIndex}`);
        blocks.push({
          id: `quote-${blockIndex}`,
          kind: 'quote',
          text: parsedQuote.plainText,
          marker: '',
          level: 0,
          segments: parsedQuote.segments,
          links: parsedQuote.links
        });
        blockIndex += 1;
        continue;
      }

      if (trimmedLine.startsWith('- ') || trimmedLine.startsWith('* ')) {
        pushParagraph();
        const parsedBullet = this.parseInlineMarkdown(trimmedLine.slice(2), `bullet-${blockIndex}`);
        blocks.push({
          id: `bullet-${blockIndex}`,
          kind: 'bullet',
          text: parsedBullet.plainText,
          marker: '•',
          level: 0,
          segments: parsedBullet.segments,
          links: parsedBullet.links
        });
        blockIndex += 1;
        continue;
      }

      const orderedMatch = trimmedLine.match(/^(\d+)\.\s+(.+)$/);
      if (orderedMatch) {
        pushParagraph();
        const parsedOrdered = this.parseInlineMarkdown(orderedMatch[2], `ordered-${blockIndex}`);
        blocks.push({
          id: `ordered-${blockIndex}`,
          kind: 'ordered',
          text: parsedOrdered.plainText,
          marker: `${orderedMatch[1]}.`,
          level: 0,
          segments: parsedOrdered.segments,
          links: parsedOrdered.links
        });
        blockIndex += 1;
        continue;
      }

      paragraphLines.push(line.trimEnd());
    }

    pushParagraph();
    pushCodeBlock();

    if (blocks.length === 0) {
      const parsedFallback = this.parseInlineMarkdown(content, 'paragraph-empty');
      blocks.push({
        id: 'paragraph-empty',
        kind: 'paragraph',
        text: parsedFallback.plainText,
        marker: '',
        level: 0,
        segments: parsedFallback.segments,
        links: parsedFallback.links
      });
    }

    return blocks;
  }

  private parseInlineMarkdown(text: string, blockIdPrefix: string): {
    plainText: string;
    segments: MarkdownInlineSegment[];
    links: MarkdownLinkRef[];
  } {
    const normalized = text.replace(/^\>\s?/g, '');
    const inlinePattern = /!\[([^\]]*)\]\((https?:\/\/[^)]+)\)|\[([^\]]+)\]\((https?:\/\/[^)]+)\)|`([^`]+)`|\*\*([^*]+)\*\*|__([^_]+)__|~~([^~]+)~~|\*([^*\n]+)\*|_([^_\n]+)_/g;
    const segments: MarkdownInlineSegment[] = [];
    const links: MarkdownLinkRef[] = [];
    let segmentIndex = 0;
    let lastIndex = 0;

    const pushTextSegment = (value: string): void => {
      if (value.length === 0) {
        return;
      }
      segments.push({
        id: `${blockIdPrefix}-segment-${segmentIndex}`,
        kind: 'text',
        text: value
      });
      segmentIndex += 1;
    };

    let match: RegExpExecArray | null;
    while ((match = inlinePattern.exec(normalized)) !== null) {
      if (match.index > lastIndex) {
        pushTextSegment(normalized.slice(lastIndex, match.index));
      }

      let kind = 'text';
      let segmentText = '';
      let url: string | undefined = undefined;

      if (match[1] !== undefined && match[2] !== undefined) {
        const altText = match[1].trim();
        kind = 'link';
        segmentText = altText.length > 0 ? `图像: ${altText}` : '图像链接';
        url = match[2].trim();
      } else if (match[3] !== undefined && match[4] !== undefined) {
        kind = 'link';
        segmentText = match[3].trim();
        url = match[4].trim();
      } else if (match[5] !== undefined) {
        kind = 'code';
        segmentText = match[5];
      } else if (match[6] !== undefined || match[7] !== undefined) {
        kind = 'strong';
        segmentText = match[6] ?? match[7] ?? '';
      } else if (match[8] !== undefined) {
        kind = 'strike';
        segmentText = match[8];
      } else if (match[9] !== undefined || match[10] !== undefined) {
        kind = 'emphasis';
        segmentText = match[9] ?? match[10] ?? '';
      }

      if (segmentText.length > 0) {
        segments.push({
          id: `${blockIdPrefix}-segment-${segmentIndex}`,
          kind: kind,
          text: segmentText,
          url: url
        });
        segmentIndex += 1;
        if (url) {
          links.push({
            label: segmentText,
            url: url
          });
        }
      }

      lastIndex = inlinePattern.lastIndex;
    }

    if (lastIndex < normalized.length) {
      pushTextSegment(normalized.slice(lastIndex));
    }

    if (segments.length === 0) {
      pushTextSegment(normalized);
    }

    return {
      plainText: segments.map((segment: MarkdownInlineSegment) => segment.text).join('').trim(),
      segments: segments,
      links: links
    };
  }

  private extractStandaloneLink(text: string): { label: string; url: string } | undefined {
    const trimmed = text.trim();
    const imageMatch = trimmed.match(/^!\[([^\]]*)\]\((https?:\/\/[^)]+)\)$/);
    if (imageMatch) {
      return {
        label: imageMatch[1].trim().length > 0 ? `图像: ${imageMatch[1].trim()}` : '图像链接',
        url: imageMatch[2].trim()
      };
    }

    const markdownLinkMatch = trimmed.match(/^\[([^\]]+)\]\((https?:\/\/[^)]+)\)$/);
    if (markdownLinkMatch) {
      return {
        label: markdownLinkMatch[1].trim(),
        url: markdownLinkMatch[2].trim()
      };
    }

    const urlMatch = trimmed.match(/^(https?:\/\/\S+)$/);
    if (urlMatch) {
      return {
        label: urlMatch[1],
        url: urlMatch[1]
      };
    }

    return undefined;
  }

  private pickerSummaryText(): string {
    const selected = this.selectedFavorites();
    if (selected.length === 0) {
      return `从 ${this.vm.chatState.favorites.length} 篇收藏论文中选择`;
    }
    return `已选 ${selected.length} 篇：${selected.map((favorite: FavoritePaperItem) => favorite.paper.title.slice(0, 12)).join(' / ')}`;
  }

  private pickerMenuHeight(): number {
    return Math.min(this.vm.chatState.favorites.length * 70, 240);
  }

  private pickerButtonHeight(): number {
    return 46;
  }

  private pickerMenuTopOffset(): number {
    return this.pickerButtonHeight() + 6;
  }

  private syncComposerDraft(): void {
    this.composerDraft = this.vm.chatState.inputDraft;
  }

  private togglePickerExpanded(): void {
    if (!this.isPickerExpanded) {
      this.isPickerExpanded = true;
    }
  }

  private collapsePickerExpanded(): void {
    if (this.isPickerExpanded) {
      this.isPickerExpanded = false;
    }
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
    this.collapsePickerExpanded();
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
  private feedbackStrip(message: string, backgroundColor: string, foregroundColor: string) {
    Text(message)
      .fontSize(13)
      .lineHeight(20)
      .fontColor(foregroundColor)
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 12 })
      .backgroundColor(backgroundColor)
      .borderRadius(10)
      .onClick(() => this.collapsePickerExpanded());
  }

  @Builder
  private selectionChip(favorite: FavoritePaperItem) {
    Row({ space: 6 }) {
      Text('✓')
        .fontSize(12)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.palette().primary);
      Text(favorite.paper.title.slice(0, 18))
        .fontSize(12)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.palette().textPrimary)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis });
    }
    .padding({ left: 10, right: 10, top: 6, bottom: 6 })
    .margin({ right: 8, bottom: 8 })
    .backgroundColor(this.palette().surfaceSubtle)
    .borderRadius(999)
    .border({ width: 1, color: this.palette().outline })
    .alignItems(VerticalAlign.Center)
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
        .fontSize(12)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.palette().textSecondary);
    }
    .padding({ left: 10, right: 10, top: 5, bottom: 5 })
    .margin({ right: 8, bottom: 8 })
    .backgroundColor(this.palette().surfaceVariant)
    .borderRadius(10)
    .alignItems(VerticalAlign.Center)
    .onClick(() => this.collapsePickerExpanded());
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

  private struckThroughText(value: string): string {
    // ArkUI 这里暂时没有现成的 inline 删除线落点，先用组合删除线字符补足可见语义。
    return Array.from(value).map((char: string) => {
      return char === ' ' ? char : `${char}\u0336`;
    }).join('');
  }

  @Builder
  private markdownInlineSpan(segment: MarkdownInlineSegment, defaultColor: string) {
    if (segment.kind === 'strong') {
      Span(segment.text)
        .fontWeight(FontWeight.Bold)
        .fontColor(defaultColor);
    } else if (segment.kind === 'emphasis') {
      Span(segment.text)
        .fontWeight(FontWeight.Medium)
        .fontColor(defaultColor);
    } else if (segment.kind === 'code') {
      Span(segment.text)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.palette().primary);
    } else if (segment.kind === 'link') {
      Span(segment.text)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.palette().primary);
    } else if (segment.kind === 'strike') {
      Span(this.struckThroughText(segment.text))
        .fontColor(this.palette().textSecondary);
    } else {
      Span(segment.text)
        .fontColor(defaultColor);
    }
  }

  @Builder
  private markdownInlineText(block: MarkdownBlock, fontSize: number, lineHeight: number, defaultColor: string) {
    if (block.segments && block.segments.length > 0) {
      Text() {
        ForEach(block.segments, (segment: MarkdownInlineSegment) => {
          this.markdownInlineSpan(segment, defaultColor);
        }, (segment: MarkdownInlineSegment) => segment.id);
      }
      .fontSize(fontSize)
      .lineHeight(lineHeight)
      .fontColor(defaultColor)
      .width('100%');
    } else {
      Text(block.text)
        .fontSize(fontSize)
        .lineHeight(lineHeight)
        .fontColor(defaultColor)
        .width('100%');
    }
  }

  @Builder
  private markdownInlineLinkChip(link: MarkdownLinkRef) {
    Row({ space: 4 }) {
      Text('↗')
        .fontSize(11)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.palette().primary);
      Text(link.label)
        .fontSize(11)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.palette().primary)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis });
    }
    .padding({ left: 8, right: 8, top: 4, bottom: 4 })
    .margin({ right: 8, bottom: 4 })
    .backgroundColor(this.palette().surfaceSubtle)
    .borderRadius(8)
    .border({ width: 1, color: this.palette().outline })
    .onClick(() => {
      void this.openExternalLink(link.url);
    });
  }

  @Builder
  private markdownInlineLinkStrip(block: MarkdownBlock) {
    if (block.links && block.links.length > 0) {
      Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start, alignItems: ItemAlign.Center }) {
        ForEach(block.links, (link: MarkdownLinkRef) => {
          this.markdownInlineLinkChip(link);
        }, (link: MarkdownLinkRef) => `${block.id}-${link.url}`);
      }
      .width('100%');
    }
  }

  @Builder
  private markdownBlock(block: MarkdownBlock) {
    if (block.kind === 'heading') {
      Column({ space: block.links && block.links.length > 0 ? 8 : 0 }) {
        this.markdownInlineText(block, this.headingFontSize(block.level), 26, this.palette().textPrimary);
        this.markdownInlineLinkStrip(block);
      }
      .width('100%');
    } else if (block.kind === 'bullet' || block.kind === 'ordered') {
      Row({ space: 8 }) {
        Text(block.marker)
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.palette().textTertiary);
        Column({ space: block.links && block.links.length > 0 ? 8 : 0 }) {
          this.markdownInlineText(block, 14, 22, this.palette().textTertiary);
          this.markdownInlineLinkStrip(block);
        }
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
    } else if (block.kind === 'quote') {
      Row({ space: 10 }) {
        Row()
          .width(4)
          .height('100%')
          .backgroundColor(this.palette().primary)
          .borderRadius(999);
        Column({ space: block.links && block.links.length > 0 ? 8 : 0 }) {
          this.markdownInlineText(block, 14, 22, this.palette().textTertiary);
          this.markdownInlineLinkStrip(block);
        }
          .layoutWeight(1);
      }
      .width('100%')
      .padding({ left: 10, right: 10, top: 10, bottom: 10 })
      .backgroundColor(this.palette().surface)
      .borderRadius(14)
      .alignItems(VerticalAlign.Top);
    } else if (block.kind === 'link' && block.linkUrl) {
      Column({ space: 4 }) {
        Text(block.text)
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.palette().primary)
          .width('100%');
        Text(block.linkUrl)
          .fontSize(12)
          .lineHeight(18)
          .fontColor(this.palette().textSecondary)
          .width('100%');
      }
      .width('100%')
      .padding({ left: 10, right: 10, top: 10, bottom: 10 })
      .backgroundColor(this.palette().surface)
      .borderRadius(14)
      .border({ width: 1, color: this.palette().outline })
      .onClick(() => {
        if (block.linkUrl) {
          void this.openExternalLink(block.linkUrl);
        }
      });
    } else {
      Column({ space: block.links && block.links.length > 0 ? 8 : 0 }) {
        this.markdownInlineText(block, 14, 22, this.palette().textTertiary);
        this.markdownInlineLinkStrip(block);
      }
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
    Row({ space: 8 }) {
      Text(this.pickerSummaryText())
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.palette().textPrimary)
        .layoutWeight(1)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis });
      Text(this.isPickerExpanded ? '▴' : '▾')
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.palette().textSecondary);
    }
    .width('100%')
    .padding({ left: 12, right: 12, top: 11, bottom: 11 })
    .backgroundColor(this.isPickerExpanded ? this.palette().surfaceSubtle : this.palette().surface)
    .borderRadius(14)
    .border({ width: 1, color: this.isPickerExpanded ? this.palette().primary : this.palette().outline })
    .onClick(() => {
      this.togglePickerExpanded();
    });
  }

  @Builder
  private inlinePickerCheckmark(selected: boolean) {
    Row() {
      Text(selected ? '✓' : '')
        .fontSize(11)
        .fontWeight(FontWeight.Medium)
        .fontColor(selected ? this.palette().primary : this.palette().textSecondary);
    }
    .width(18)
    .height(18)
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
    .backgroundColor(selected ? this.palette().primaryContainer : this.palette().surfaceVariant)
    .borderRadius(5)
    .border({ width: 1, color: selected ? this.palette().primary : this.palette().outline });
  }

  @Builder
  private inlinePickerOption(favorite: FavoritePaperItem) {
    // Android 端这里是 DropdownMenuItem，Harmony 端保持整行可点，避免额外按钮打断浏览节奏。
    // 次级信息里的分类与日期分隔符也保持成“·”，避免出现当前鸿蒙端的错误字符。
    Row({ space: 12 }) {
      this.inlinePickerCheckmark(this.isPaperSelected(favorite.paper.id));

      Column({ space: 2 }) {
        Text(favorite.paper.title)
          .fontSize(14)
          .fontWeight(this.isPaperSelected(favorite.paper.id) ? FontWeight.Medium : FontWeight.Regular)
          .fontColor(this.palette().textPrimary)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis });
        Text(`${favorite.paper.primaryCategory} · ${favorite.savedAt.slice(0, 10)}`)
          .fontSize(11)
          .fontColor(this.palette().textSecondary);
      }
      .layoutWeight(1);
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
    .padding({ left: 10, right: 10, top: 9, bottom: 9 })
    .backgroundColor(this.isPaperSelected(favorite.paper.id) ? this.palette().surfaceSubtle : this.palette().surface)
    .borderRadius(10)
    .onClick(() => this.togglePickerSelection(favorite.paper.id));
  }

  @Builder
  private paperPickerCard() {
    Column({ space: 10 }) {
      Text('收藏论文')
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.palette().textSecondary)
        .width('100%');
      if (this.vm.chatState.favorites.length === 0) {
        Text('收藏库为空')
          .fontSize(13)
          .fontColor(this.palette().textSecondary)
          .width('100%');
      } else {
        Stack({ alignContent: Alignment.TopStart }) {
          this.paperPickerButton();

          if (this.isPickerExpanded) {
            // Android 端这里是锚定按钮的 DropdownMenu；Harmony 端改成局部覆盖展开，避免继续挤压下方内容。
            Scroll() {
              Column({ space: 2 }) {
                ForEach(this.vm.chatState.favorites, (favorite: FavoritePaperItem) => {
                  this.inlinePickerOption(favorite);
                }, (favorite: FavoritePaperItem) => favorite.paper.id);
              }
              .width('100%');
            }
          .width('100%')
          .height(this.pickerMenuHeight())
          .margin({ top: this.pickerMenuTopOffset() })
          .padding({ left: 6, right: 6, top: 6, bottom: 6 })
          .backgroundColor(this.palette().surface)
          .borderRadius(14)
          .border({ width: 1, color: this.palette().outline })
          .scrollBar(BarState.Auto)
          .scrollable(ScrollDirection.Vertical);
          }
        }
        .width('100%')
        .height(this.pickerButtonHeight());

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
    Column() {
      Text('选择收藏论文后开始提问')
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.palette().textSecondary)
        .textAlign(TextAlign.Center);
    }
    .alignItems(HorizontalAlign.Center)
    .width('100%')
    .padding({ left: 16, right: 16, top: 20, bottom: 20 })
    .backgroundColor(this.palette().surface)
    .borderRadius(10)
    .onClick(() => this.collapsePickerExpanded());
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
      .width(message.role === 'user' ? '82%' : '86%')
      .padding({ left: 16, right: 16, top: 12, bottom: 12 })
      .backgroundColor(message.role === 'user' ? this.palette().primary : this.palette().surface)
      .borderRadius(10);

      if (message.role !== 'user') {
        Blank();
      }
    }
    .width('100%')
    .onClick(() => this.collapsePickerExpanded());
  }

  @Builder
  private thinkingBubble() {
    Row() {
      Row({ space: 10 }) {
        LoadingProgress()
          .width(16)
          .height(16)
          .color(this.palette().textSecondary);
        Text('正在思考中...')
          .fontSize(14)
          .fontColor(this.palette().textSecondary)
          .lineHeight(22);
      }
      .width('86%')
      .padding({ left: 16, right: 16, top: 12, bottom: 12 })
      .backgroundColor(this.palette().surface)
      .borderRadius(10)
      .alignItems(VerticalAlign.Center);
      Blank();
    }
    .width('100%')
    .onClick(() => this.collapsePickerExpanded());
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
    Row({ space: 10 }) {
      Row({ space: 10 }) {
        TextArea({
          placeholder: this.vm.chatState.isSending ? '正在整理论文材料...' : '向选中论文提问',
          text: this.composerDraft
        })
          .fontSize(15)
          .fontColor(this.palette().textPrimary)
          .placeholderColor(this.palette().textSecondary)
          .backgroundColor('#00000000')
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
            .fontSize(16)
            .fontColor([this.canSendMessage() ? this.palette().primary : this.palette().textSecondary]);
        }
        .width(32)
        .height(32)
        .justifyContent(FlexAlign.Center)
        .borderRadius(16)
        .opacity(this.sendActionOpacity())
        .onClick(() => {
          this.submitComposer();
        });
      }
      .layoutWeight(1)
      .padding({ left: 12, right: 8, top: 0, bottom: 0 })
      .backgroundColor(this.palette().surface)
      .borderRadius(12)
      .border({ width: 1, color: this.palette().outline })
      .alignItems(VerticalAlign.Center);
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
    .onClick(() => this.collapsePickerExpanded());
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Column({ space: AppConstants.SECTION_SPACING }) {
        Row() {
          Column({ space: 4 }) {
            Text('论文对话')
              .fontSize(22)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.palette().textPrimary);
            Text(`已选 ${this.vm.chatState.selectedPaperIds.length} 篇 · 最多 ${AppConstants.MAX_CHAT_PAPERS} 篇`)
              .fontSize(13)
              .fontColor(this.palette().textSecondary);
          }
          Blank();
          Row({ space: 4 }) {
            Text('×')
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.palette().primary);
            Text('清空')
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.palette().primary);
          }
          .padding({ left: 8, right: 8, top: 8, bottom: 8 })
          .alignItems(VerticalAlign.Center)
          .borderRadius(999)
          .onClick(() => {
            this.collapsePickerExpanded();
            this.vm.clearConversation();
          });
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
