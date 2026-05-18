import {
  FavoritePaperItem,
  HomeUiState,
  LibraryUiState,
  PaperChatUiState,
  PaperItem,
  SettingsStatus
} from '../model/AppModels';
import {
  createDefaultChatState,
  createDefaultHomeState,
  createDefaultLibraryState,
  createDefaultSettingsStatus
} from '../model/StateFactory';
import favoriteStoreService from '../service/FavoriteStoreService';
import paperService from '../service/PaperService';
import preferenceService from '../service/PreferenceService';

@Observed
export class AppViewModel {
  selectedTab: number = 0;
  homeState: HomeUiState = createDefaultHomeState();
  libraryState: LibraryUiState = createDefaultLibraryState();
  chatState: PaperChatUiState = createDefaultChatState();
  settingsState: SettingsStatus = createDefaultSettingsStatus();

  private nextActionMessageId: number = 1;

  constructor() {
    this.settingsState = paperService.mergeSettingsStatus(createDefaultSettingsStatus());
    preferenceService.initialize(this.settingsState);
    favoriteStoreService.initialize(paperService.listFavorites());
    this.bootstrap();
  }

  private bootstrap(): void {
    this.refreshHome();
    this.refreshFavorites();
    this.refreshSettings();
  }

  selectTab(index: number): void {
    this.selectedTab = index;
  }

  refreshHome(): void {
    this.homeState.isLoading = true;
    const result = paperService.listHomePapers({
      keyword: this.homeState.searchKeyword.length > 0 ? this.homeState.searchKeyword : undefined,
      category: this.homeState.selectedCategory,
      days: this.homeState.searchKeyword.length > 0 ? undefined : this.homeState.selectedDays,
      page: 1,
      pageSize: 20
    });
    this.homeState.papers = result.items;
    this.homeState.listStatus = result.status;
    this.homeState.listWarning = result.warning;
    this.homeState.emptyReason = result.emptyReason;
    this.homeState.trendSummary = paperService.getTrendSummary();
    this.homeState.isLoading = false;
    this.homeState.isSummaryLoading = false;
  }

  updateSearchKeywordDraft(value: string): void {
    this.homeState.searchKeywordDraft = value;
  }

  submitSearch(): void {
    this.homeState.searchKeyword = this.homeState.searchKeywordDraft.trim();
    this.refreshHome();
  }

  clearSearch(): void {
    this.homeState.searchKeyword = '';
    this.homeState.searchKeywordDraft = '';
    this.refreshHome();
  }

  selectCategory(category: string): void {
    this.homeState.selectedCategory = category;
    this.refreshHome();
  }

  selectDays(days: number): void {
    this.homeState.selectedDays = days;
    if (this.homeState.searchKeyword.length === 0) {
      this.refreshHome();
    }
  }

  toggleAbstract(paperId: string): void {
    const existed = this.homeState.expandedAbstractPaperIds.indexOf(paperId) >= 0;
    this.homeState.expandedAbstractPaperIds = existed
      ? this.homeState.expandedAbstractPaperIds.filter((id: string) => id !== paperId)
      : [...this.homeState.expandedAbstractPaperIds, paperId];
  }

  toggleSummaryExpanded(): void {
    this.homeState.summaryExpanded = !this.homeState.summaryExpanded;
  }

  dismissSummary(): void {
    this.homeState.dismissedSummary = true;
  }

  translatePaper(paperId: string): void {
    const paper = this.homeState.papers.find((item: PaperItem) => item.id === paperId);
    if (!paper) {
      return;
    }
    if (this.homeState.expandedAbstractPaperIds.indexOf(paperId) < 0) {
      this.pushHomeAction('请先展开摘要');
      return;
    }
    const translated = paperService.translatePaper(paper);
    this.homeState.papers = this.homeState.papers.map((item: PaperItem) => item.id === paperId ? translated : item);
    this.pushHomeAction('摘要翻译已完成');
  }

  toggleFavorite(paperId: string): void {
    const paper = this.homeState.papers.find((item: PaperItem) => item.id === paperId);
    if (!paper) {
      return;
    }
    const nextFavoriteState = !paper.favoriteState;
    const updatedPaper: PaperItem = {
      ...paper,
      favoriteState: nextFavoriteState
    };
    this.homeState.papers = this.homeState.papers.map((item: PaperItem) => item.id === paperId ? updatedPaper : item);
    if (nextFavoriteState) {
      favoriteStoreService.saveFavorite(updatedPaper);
      this.pushHomeAction('已收藏');
    } else {
      favoriteStoreService.deleteFavorite(paperId);
      this.pushHomeAction('已取消收藏');
    }
    this.refreshFavorites();
  }

  refreshFavorites(): void {
    const favorites = favoriteStoreService.read(paperService.listFavorites());
    this.libraryState = {
      ...this.libraryState,
      favorites
    };
    this.chatState = {
      ...this.chatState,
      favorites
    };
  }

  toggleLibrarySelection(paperId: string): void {
    const existed = this.libraryState.selectedPaperIds.indexOf(paperId) >= 0;
    this.libraryState.selectedPaperIds = existed
      ? this.libraryState.selectedPaperIds.filter((id: string) => id !== paperId)
      : [...this.libraryState.selectedPaperIds, paperId];
  }

  selectLibraryFilter(filter: string): void {
    this.libraryState.syncFilter = filter;
  }

  exportSelectedBibtex(): void {
    const favorites = this.libraryState.favorites.filter((item: FavoritePaperItem) => {
      return this.libraryState.selectedPaperIds.indexOf(item.paper.id) >= 0;
    });
    if (favorites.length === 0) {
      this.libraryState.errorMessage = '请先选择要导出的论文';
      return;
    }
    this.libraryState.exportContent = paperService.exportBibtex(favorites);
    this.libraryState.actionMessage = 'BibTeX 已生成';
  }

  deleteFavorite(paperId: string): void {
    favoriteStoreService.deleteFavorite(paperId);
    this.refreshFavorites();
    this.libraryState.selectedPaperIds = this.libraryState.selectedPaperIds.filter((id: string) => id !== paperId);
    this.libraryState.actionMessage = '已删除收藏';
  }

  toggleChatPaper(paperId: string): void {
    const existed = this.chatState.selectedPaperIds.indexOf(paperId) >= 0;
    if (existed) {
      this.chatState.selectedPaperIds = this.chatState.selectedPaperIds.filter((id: string) => id !== paperId);
      return;
    }
    if (this.chatState.selectedPaperIds.length >= 3) {
      this.chatState.errorMessage = '一次最多选择 3 篇论文';
      return;
    }
    this.chatState.selectedPaperIds = [...this.chatState.selectedPaperIds, paperId];
    this.chatState.errorMessage = undefined;
  }

  updateChatDraft(value: string): void {
    this.chatState.inputDraft = value;
  }

  sendChatMessage(): void {
    const selectedPapers = this.chatState.favorites.filter((item: FavoritePaperItem) => {
      return this.chatState.selectedPaperIds.indexOf(item.paper.id) >= 0;
    });
    const question = this.chatState.inputDraft.trim();
    if (selectedPapers.length === 0) {
      this.chatState.errorMessage = '请先选择至少一篇收藏论文';
      return;
    }
    if (question.length === 0) {
      this.chatState.errorMessage = '请输入要询问的问题';
      return;
    }
    this.chatState.isSending = true;
    const result = paperService.chatWithPapers(selectedPapers, question);
    this.chatState.messages = result.messages;
    this.chatState.usedPapers = result.usedPapers;
    this.chatState.warningMessage = result.warning;
    this.chatState.inputDraft = '';
    this.chatState.isSending = false;
    this.chatState.errorMessage = undefined;
  }

  refreshSettings(): void {
    this.settingsState = preferenceService.read(this.settingsState);
  }

  updateDefaultCategory(category: string): void {
    this.settingsState.defaultCategory = category;
    this.settingsState = preferenceService.save(this.settingsState);
    this.homeState.selectedCategory = category;
    this.refreshHome();
  }

  updateDefaultDays(days: number): void {
    this.settingsState.defaultDays = days;
    this.settingsState = preferenceService.save(this.settingsState);
    this.homeState.selectedDays = days;
    this.refreshHome();
  }

  private pushHomeAction(text: string): void {
    this.homeState.actionMessage = {
      id: this.nextActionMessageId++,
      text
    };
    this.libraryState.actionMessage = undefined;
  }
}
