import AppConstants from '../common/constants/AppConstants';
import { FavoritePaperItem, PaperChatMessage } from '../model/AppModels';
import { AppViewModel } from '../viewmodel/AppViewModel';

@Component
export struct ChatPage {
  @ObjectLink vm: AppViewModel;

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
        Text('刷新')
          .fontSize(15)
          .fontColor('#2D6CE8')
          .onClick(() => this.vm.refreshFavorites());
      }
      .width('100%');

      Column({ space: 10 }) {
        Text('收藏论文')
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .fontColor('#374151');

        Column({ space: 10 }) {
          ForEach(this.vm.chatState.favorites, (favorite: FavoritePaperItem) => {
            const selected = this.vm.chatState.selectedPaperIds.indexOf(favorite.paper.id) >= 0;
            Row() {
              Text(selected ? '☑' : '☐')
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
            Text(`${message.role === 'user' ? '你' : '助手'}：${message.content}`)
              .fontSize(14)
              .fontColor(message.role === 'user' ? '#111827' : '#374151')
              .width('100%')
              .padding(16)
              .backgroundColor(message.role === 'user' ? '#EAF2FF' : '#FFFFFF')
              .borderRadius(16);
          }, (_: PaperChatMessage, index?: number) => `${index}`);
        }
      }
      .width('100%');

      Row({ space: 8 }) {
        Text(this.vm.chatState.inputDraft.length > 0 ? this.vm.chatState.inputDraft : '向选中论文提问')
          .fontSize(15)
          .fontColor(this.vm.chatState.inputDraft.length > 0 ? '#111827' : '#9CA3AF')
          .layoutWeight(1)
          .onClick(() => this.vm.updateChatDraft('请总结这些论文的核心贡献'));
        Text(this.vm.chatState.isSending ? '发送中' : '发送')
          .fontSize(15)
          .fontColor('#2D6CE8')
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
