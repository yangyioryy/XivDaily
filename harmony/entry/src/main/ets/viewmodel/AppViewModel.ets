import {
  FavoritePaperItem,
  HomeActionMessage,
  HomeUiState,
  LibraryUiState,
  PaperChatMessage,
  PaperChatUiState,
  PaperItem,
  SettingsStatus,
  ZoteroSyncState
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
import hilog from '@ohos.hilog';

@Observed
export class AppViewModel {
  selectedTab: number = 0;
  homeState: HomeUiState = createDefaultHomeState();
  libraryState: LibraryUiState = createDefaultLibraryState();
  chatState: PaperChatUiState = createDefaultChatState();
  settingsState: SettingsStatus = createDefaultSettingsStatus();

  private nextActionMessageId: number = 1;
  private homeActionTimerId?: number;
  // 用会话版本隔离收藏库快速进入对话与旧请求返回，避免旧回复污染新上下文。
  private activeChatSessionVersion: number = 0;

  constructor() {
    preferenceService.initialize(this.settingsState);
    const storedFavorites = favoriteStoreService.read([]);
    favoriteStoreService.initialize(storedFavorites);
    this.applyLocalSettings(preferenceService.read(this.settingsState));
    this.refreshFavorites();
    void this.bootstrap();
  }

  private async bootstrap(): Promise<void> {
    await Promise.all([
      this.refreshHome(),
      this.refreshTrendSummary(),
      this.refreshIntegrationStatus(false)
    ]);
  }

  selectTab(index: number): void {
    this.selectedTab = index;
  }

  updateSearchKeywordDraft(value: string): void {
    this.homeState.searchKeywordDraft = value;
  }

  submitSearch(): void {
    this.homeState.searchKeyword = this.homeState.searchKeywordDraft.trim();
    void this.refreshHome();
  }

  clearSearch(): void {
    this.homeState.searchKeyword = '';
    this.homeState.searchKeywordDraft = '';
    void this.refreshHome();
  }

  selectCategory(category: string): void {
    this.homeState.selectedCategory = category;
    this.homeState.dismissedSummary = false;
    this.homeState.errorMessage = undefined;
    this.homeState.trendErrorMessage = undefined;
    void this.refreshFeed();
  }

  selectDays(days: number): void {
    this.homeState.selectedDays = days;
    if (!this.isSearchActive()) {
      void this.refreshHome();
    }
  }

  addCustomTag(tag: string): void {
    const normalizedTag = this.normalizeCustomTag(tag);
    if (normalizedTag.length === 0) {
      this.pushHomeAction('请输入标签名称');
      return;
    }
    if (this.homeState.categories.indexOf(normalizedTag) >= 0 || this.homeState.customTags.indexOf(normalizedTag) >= 0) {
      this.pushHomeAction('标签已存在');
      return;
    }

    const nextTags = this.homeState.customTags.concat([normalizedTag]);
    this.settingsState.customTags = nextTags;
    this.persistLocalSettings();
    this.applyLocalSettings(this.settingsState);
    this.homeState.selectedCategory = normalizedTag;
    this.homeState.dismissedSummary = false;
    void this.refreshFeed();
    this.pushHomeAction(`已添加标签：${normalizedTag}`);
  }

  deleteCustomTag(tag: string): void {
    if (this.homeState.customTags.indexOf(tag) < 0) {
      return;
    }

    const nextTags = this.homeState.customTags.filter((item: string) => item !== tag);
    this.settingsState.customTags = nextTags;
    this.persistLocalSettings();
    this.applyLocalSettings(this.settingsState);
    if (this.homeState.selectedCategory === tag) {
      this.homeState.selectedCategory = this.homeState.categories[0] ?? 'cs.CV';
    }
    this.homeState.dismissedSummary = false;
    void this.refreshFeed();
    this.pushHomeAction(`已删除标签：${tag}`);
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

  async refreshFeed(): Promise<void> {
    await Promise.all([
      this.refreshHome(),
      this.refreshTrendSummary()
    ]);
  }

  async refreshHome(): Promise<void> {
    const searchKeyword = this.homeState.searchKeyword.trim();
    // 搜索态下沿用 Android 的语义：关键词优先，时间窗口仅服务无关键词首页流。
    const keyword = searchKeyword.length > 0
      ? searchKeyword
      : this.isSelectedCategoryCustomTag()
        ? this.toCustomTagSearchKeyword(this.homeState.selectedCategory)
        : undefined;
    const category = this.isSelectedCategoryCustomTag() ? undefined : this.homeState.selectedCategory;
    const days = keyword ? undefined : this.homeState.selectedDays;

    this.homeState.isLoading = true;
    this.homeState.errorMessage = undefined;

    try {
      const result = await paperService.listHomePapers({
        keyword: keyword,
        category: category,
        days: days,
        page: 1,
        pageSize: 20
      });

      this.homeState.papers = this.mergeHomePapersWithLocalFavorites(result.items);
      this.homeState.listStatus = result.status;
      this.homeState.listWarning = result.warning;
      this.homeState.emptyReason = result.emptyReason;
      hilog.info(
        0x0000,
        'XivDaily',
        'refreshHome success. papers=%{public}s status=%{public}s warning=%{public}s emptyReason=%{public}s',
        `${this.homeState.papers.length}`,
        `${this.homeState.listStatus}`,
        `${this.homeState.listWarning ?? ''}`,
        `${this.homeState.emptyReason ?? ''}`
      );
    } catch (error) {
      this.homeState.errorMessage = mapUserFriendlyError('论文列表暂时无法刷新', error);
    } finally {
      this.homeState.isLoading = false;
      hilog.info(
        0x0000,
        'XivDaily',
        'refreshHome finally. isLoading=%{public}s papers=%{public}s error=%{public}s',
        `${this.homeState.isLoading}`,
        `${this.homeState.papers.length}`,
        `${this.homeState.errorMessage ?? ''}`
      );
    }
  }

  private async refreshTrendSummary(): Promise<void> {
    this.homeState.isSummaryLoading = true;
    const category = this.isSelectedCategoryCustomTag() ? undefined : this.homeState.selectedCategory;

    try {
      this.homeState.trendSummary = await paperService.getTrendSummary(category);
      this.homeState.trendErrorMessage = undefined;
      hilog.info(
        0x0000,
        'XivDaily',
        'refreshTrendSummary success. items=%{public}s status=%{public}s',
        `${this.homeState.trendSummary?.items.length ?? 0}`,
        `${this.homeState.trendSummary?.status ?? ''}`
      );
    } catch (error) {
      this.homeState.trendErrorMessage = mapUserFriendlyError('趋势摘要暂时不可用', error);
    } finally {
      this.homeState.isSummaryLoading = false;
      hilog.info(
        0x0000,
        'XivDaily',
        'refreshTrendSummary finally. isSummaryLoading=%{public}s error=%{public}s',
        `${this.homeState.isSummaryLoading}`,
        `${this.homeState.trendErrorMessage ?? ''}`
      );
    }
  }

  async translatePaper(paperId: string): Promise<void> {
    const paper = this.homeState.papers.find((item: PaperItem) => item.id === paperId);
    if (!paper) {
      return;
    }
    if (this.homeState.expandedAbstractPaperIds.indexOf(paperId) < 0) {
      this.pushHomeAction('请先展开摘要');
      return;
    }
    if (paper.translatedSummary && paper.translatedSummary.length > 0) {
      this.pushHomeAction('已显示中文翻译');
      return;
    }
    if (this.homeState.translatingPaperIds.indexOf(paperId) >= 0) {
      return;
    }

    this.homeState.translatingPaperIds = [...this.homeState.translatingPaperIds, paperId];
    this.homeState.translationErrors = this.copyTranslationErrorsWithout(paperId);

    try {
      const translated = await paperService.translatePaper(paper);
      this.homeState.papers = this.homeState.papers.map((item: PaperItem) => {
        return item.id === paperId ? translated : item;
      });
      this.pushHomeAction('摘要翻译已完成');
    } catch (error) {
      const nextErrors = this.copyTranslationErrorsWithout('');
      nextErrors[paperId] = mapUserFriendlyError('摘要翻译暂时不可用', error);
      this.homeState.translationErrors = nextErrors;
    } finally {
      this.homeState.translatingPaperIds = this.homeState.translatingPaperIds.filter((id: string) => id !== paperId);
    }
  }

  toggleFavorite(paperId: string): void {
    const paper = this.homeState.papers.find((item: PaperItem) => item.id === paperId);
    if (!paper) {
      return;
    }

    const nextFavoriteState = !paper.favoriteState;
    const updatedPaper = this.withFavoriteState(paper, nextFavoriteState);

    if (nextFavoriteState) {
      this.upsertFavorite(updatedPaper);
      this.pushHomeAction('已收藏');
    } else {
      favoriteStoreService.deleteFavorite(paperId);
      this.pushHomeAction('已取消收藏');
    }

    this.homeState.papers = this.homeState.papers.map((item: PaperItem) => {
      return item.id === paperId ? updatedPaper : item;
    });
    this.refreshFavorites();
  }

  dismissHomePaper(paperId: string): void {
    const paper = this.homeState.papers.find((item: PaperItem) => item.id === paperId);
    if (!paper) {
      return;
    }

    this.homeState.papers = this.homeState.papers.filter((item: PaperItem) => item.id !== paperId);
    this.homeState.expandedAbstractPaperIds = this.homeState.expandedAbstractPaperIds.filter((id: string) => id !== paperId);
    this.homeState.translatingPaperIds = this.homeState.translatingPaperIds.filter((id: string) => id !== paperId);
    this.homeState.syncingPaperIds = this.homeState.syncingPaperIds.filter((id: string) => id !== paperId);
    this.homeState.translationErrors = this.copyTranslationErrorsWithout(paperId);
    this.pushHomeAction(`已从当前流忽略：${paper.title}`);
  }

  async syncToZotero(paperId: string): Promise<void> {
    const paper = this.homeState.papers.find((item: PaperItem) => item.id === paperId);
    if (!paper) {
      return;
    }
    if (paper.zoteroSyncState === 'synced') {
      this.pushHomeAction('这篇论文已经同步到 Zotero');
      return;
    }
    if (this.homeState.syncingPaperIds.indexOf(paperId) >= 0) {
      return;
    }

    this.homeState.syncingPaperIds = [...this.homeState.syncingPaperIds, paperId];
    this.pushHomeAction('正在同步到 Zotero...');

    try {
      const result = await paperService.syncPaperToZotero(paper);
      this.homeState.papers = this.homeState.papers.map((item: PaperItem) => {
        return item.id === paperId ? result.paper : item;
      });
      this.upsertFavorite(result.paper);
      this.refreshFavorites();
      this.pushHomeAction(result.paper.zoteroSyncState === 'synced' ? '已同步到 Zotero' : (result.message ?? 'Zotero 同步暂未完成'));
    } catch (error) {
      this.homeState.errorMessage = mapUserFriendlyError('Zotero 同步暂时失败', error);
    } finally {
      this.homeState.syncingPaperIds = this.homeState.syncingPaperIds.filter((id: string) => id !== paperId);
    }
  }

  refreshFavorites(): void {
    const favorites = favoriteStoreService.read([]);
    const favoriteIds = favorites.map((item: FavoritePaperItem) => item.paper.id);
    const nextChatSelectedPaperIds = this.chatState.selectedPaperIds.filter((id: string) => favoriteIds.indexOf(id) >= 0);

    this.libraryState.favorites = favorites;
    this.libraryState.selectedPaperIds = this.libraryState.selectedPaperIds.filter((id: string) => favoriteIds.indexOf(id) >= 0);
    this.chatState = {
      favorites: favorites,
      selectedPaperIds: nextChatSelectedPaperIds,
      messages: this.chatState.messages,
      inputDraft: this.chatState.inputDraft,
      isSending: this.chatState.isSending,
      errorMessage: this.chatState.errorMessage,
      warningMessage: this.chatState.warningMessage,
      usedPapers: this.chatState.usedPapers
    };
    this.homeState.papers = this.mergeHomePapersWithLocalFavorites(this.homeState.papers);
  }

  toggleLibrarySelection(paperId: string): void {
    const existed = this.libraryState.selectedPaperIds.indexOf(paperId) >= 0;
    this.libraryState.selectedPaperIds = existed
      ? this.libraryState.selectedPaperIds.filter((id: string) => id !== paperId)
      : [...this.libraryState.selectedPaperIds, paperId];
  }

  selectAllLibraryPapers(paperIds: string[]): void {
    this.libraryState.selectedPaperIds = paperIds.slice();
    this.libraryState.errorMessage = undefined;
  }

  selectLibraryFilter(filter: string): void {
    this.libraryState.syncFilter = filter;
  }

  async syncFavoriteToZotero(paperId: string): Promise<void> {
    const favorite = this.libraryState.favorites.find((item: FavoritePaperItem) => item.paper.id === paperId);
    if (!favorite) {
      return;
    }
    if (favorite.paper.zoteroSyncState === 'synced') {
      this.libraryState.actionMessage = '这篇论文已经同步到 Zotero';
      this.libraryState.errorMessage = undefined;
      return;
    }
    if (this.libraryState.syncingPaperIds.indexOf(paperId) >= 0) {
      return;
    }

    this.libraryState.syncingPaperIds = [...this.libraryState.syncingPaperIds, paperId];
    this.libraryState.actionMessage = '正在同步到 Zotero...';
    this.libraryState.errorMessage = undefined;

    try {
      const result = await paperService.syncPaperToZotero(favorite.paper);
      this.homeState.papers = this.homeState.papers.map((item: PaperItem) => {
        return item.id === paperId ? result.paper : item;
      });
      this.upsertFavorite(result.paper);
      this.refreshFavorites();
      this.libraryState.actionMessage = result.paper.zoteroSyncState === 'synced'
        ? `已同步到 Zotero：${result.paper.title}`
        : (result.message ?? 'Zotero 同步暂未完成');
      this.libraryState.errorMessage = undefined;
    } catch (error) {
      this.libraryState.errorMessage = mapUserFriendlyError('收藏同步暂时失败', error);
    } finally {
      this.libraryState.syncingPaperIds = this.libraryState.syncingPaperIds.filter((id: string) => id !== paperId);
    }
  }

  async exportSelectedBibtex(): Promise<void> {
    if (this.libraryState.selectedPaperIds.length === 0) {
      this.libraryState.errorMessage = '请先选择要导出的论文';
      return;
    }

    try {
      this.libraryState.exportContent = await paperService.exportBibtex(this.libraryState.selectedPaperIds);
      this.libraryState.actionMessage = 'BibTeX 已生成';
      this.libraryState.errorMessage = undefined;
    } catch (error) {
      this.libraryState.errorMessage = mapUserFriendlyError('导出暂时失败', error);
    }
  }

  deleteFavorite(paperId: string): void {
    favoriteStoreService.deleteFavorite(paperId);
    this.refreshFavorites();
    this.homeState.papers = this.homeState.papers.map((item: PaperItem) => {
      return item.id === paperId ? this.withFavoriteState(item, false) : item;
    });
    this.libraryState.selectedPaperIds = this.libraryState.selectedPaperIds.filter((id: string) => id !== paperId);
    this.libraryState.actionMessage = '已删除收藏';
    this.libraryState.errorMessage = undefined;
  }

  deleteSelectedFavorites(): void {
    if (this.libraryState.selectedPaperIds.length === 0) {
      this.libraryState.errorMessage = '请先选择要删除的论文';
      return;
    }

    const ids = this.libraryState.selectedPaperIds.slice();
    ids.forEach((paperId: string) => {
      favoriteStoreService.deleteFavorite(paperId);
    });
    this.refreshFavorites();
    this.homeState.papers = this.homeState.papers.map((item: PaperItem) => {
      return ids.indexOf(item.id) >= 0 ? this.withFavoriteState(item, false) : item;
    });
    this.libraryState.selectedPaperIds = [];
    this.libraryState.actionMessage = `已批量删除 ${ids.length} 条收藏`;
    this.libraryState.errorMessage = undefined;
  }

  openChatFromLibrary(paperId: string): void {
    const favorite = this.libraryState.favorites.find((item: FavoritePaperItem) => item.paper.id === paperId);
    if (!favorite) {
      return;
    }
    this.activeChatSessionVersion += 1;
    this.selectedTab = 2;
    this.chatState = {
      favorites: this.chatState.favorites,
      selectedPaperIds: [paperId],
      messages: [],
      inputDraft: '',
      isSending: false,
      errorMessage: undefined,
      warningMessage: undefined,
      usedPapers: []
    };
  }

  toggleChatPaper(paperId: string): void {
    const existed = this.chatState.selectedPaperIds.indexOf(paperId) >= 0;
    if (existed) {
      this.chatState = {
        favorites: this.chatState.favorites,
        selectedPaperIds: this.chatState.selectedPaperIds.filter((id: string) => id !== paperId),
        messages: this.chatState.messages,
        inputDraft: this.chatState.inputDraft,
        isSending: this.chatState.isSending,
        errorMessage: undefined,
        warningMessage: this.chatState.warningMessage,
        usedPapers: this.chatState.usedPapers
      };
      return;
    }
    if (this.chatState.selectedPaperIds.length >= 3) {
      this.chatState = {
        favorites: this.chatState.favorites,
        selectedPaperIds: this.chatState.selectedPaperIds,
        messages: this.chatState.messages,
        inputDraft: this.chatState.inputDraft,
        isSending: this.chatState.isSending,
        errorMessage: '一次最多选择 3 篇论文',
        warningMessage: this.chatState.warningMessage,
        usedPapers: this.chatState.usedPapers
      };
      return;
    }
    this.chatState = {
      favorites: this.chatState.favorites,
      selectedPaperIds: [...this.chatState.selectedPaperIds, paperId],
      messages: this.chatState.messages,
      inputDraft: this.chatState.inputDraft,
      isSending: this.chatState.isSending,
      errorMessage: undefined,
      warningMessage: this.chatState.warningMessage,
      usedPapers: this.chatState.usedPapers
    };
  }

  updateChatDraft(value: string): void {
    if (this.chatState.isSending) {
      return;
    }
    this.chatState = {
      favorites: this.chatState.favorites,
      selectedPaperIds: this.chatState.selectedPaperIds,
      messages: this.chatState.messages,
      inputDraft: value,
      isSending: false,
      errorMessage: undefined,
      warningMessage: this.chatState.warningMessage,
      usedPapers: this.chatState.usedPapers
    };
  }

  async sendChatMessage(): Promise<void> {
    const selectedPapers = this.chatState.favorites.filter((item: FavoritePaperItem) => {
      return this.chatState.selectedPaperIds.indexOf(item.paper.id) >= 0;
    });
    const question = this.chatState.inputDraft.trim();

    if (selectedPapers.length === 0) {
      this.chatState = {
        favorites: this.chatState.favorites,
        selectedPaperIds: this.chatState.selectedPaperIds,
        messages: this.chatState.messages,
        inputDraft: this.chatState.inputDraft,
        isSending: false,
        errorMessage: '请先选择至少一篇收藏论文',
        warningMessage: this.chatState.warningMessage,
        usedPapers: this.chatState.usedPapers
      };
      return;
    }
    if (question.length === 0) {
      this.chatState = {
        favorites: this.chatState.favorites,
        selectedPaperIds: this.chatState.selectedPaperIds,
        messages: this.chatState.messages,
        inputDraft: this.chatState.inputDraft,
        isSending: false,
        errorMessage: '请输入要询问的问题',
        warningMessage: this.chatState.warningMessage,
        usedPapers: this.chatState.usedPapers
      };
      return;
    }

    const userMessage: PaperChatMessage = {
      role: 'user',
      content: question
    };
    const nextMessages: PaperChatMessage[] = this.chatState.messages.concat([userMessage]);

    this.chatState = {
      favorites: this.chatState.favorites,
      selectedPaperIds: this.chatState.selectedPaperIds,
      messages: nextMessages,
      inputDraft: '',
      isSending: true,
      errorMessage: undefined,
      warningMessage: undefined,
      usedPapers: this.chatState.usedPapers
    };

    const sessionVersion = this.activeChatSessionVersion;
    try {
      const result = await paperService.chatWithPapers(selectedPapers, nextMessages);
      if (sessionVersion !== this.activeChatSessionVersion) {
        return;
      }
      const assistantMessage: PaperChatMessage = {
        role: 'assistant',
        content: result.answer
      };
      this.chatState = {
        favorites: this.chatState.favorites,
        selectedPaperIds: this.chatState.selectedPaperIds,
        messages: nextMessages.concat([assistantMessage]),
        inputDraft: this.chatState.inputDraft,
        isSending: false,
        errorMessage: undefined,
        warningMessage: result.warning,
        usedPapers: result.usedPapers
      };
    } catch (error) {
      if (sessionVersion !== this.activeChatSessionVersion) {
        return;
      }
      this.chatState = {
        favorites: this.chatState.favorites,
        selectedPaperIds: this.chatState.selectedPaperIds,
        messages: this.chatState.messages,
        inputDraft: this.chatState.inputDraft,
        isSending: false,
        errorMessage: mapUserFriendlyError('论文对话暂时失败', error),
        warningMessage: this.chatState.warningMessage,
        usedPapers: this.chatState.usedPapers
      };
    }
  }

  clearConversation(): void {
    this.chatState = {
      favorites: this.chatState.favorites,
      selectedPaperIds: this.chatState.selectedPaperIds,
      messages: [],
      inputDraft: this.chatState.inputDraft,
      isSending: this.chatState.isSending,
      errorMessage: undefined,
      warningMessage: undefined,
      usedPapers: []
    };
  }

  updateDefaultCategory(category: string): void {
    this.settingsState.defaultCategory = category;
    this.persistLocalSettings();
    this.applyLocalSettings(this.settingsState);
    this.settingsState.actionMessage = '默认领域已更新';
    this.settingsState.errorMessage = undefined;
    void this.refreshFeed();
  }

  updateDefaultDays(days: number): void {
    this.settingsState.defaultDays = days;
    this.persistLocalSettings();
    this.applyLocalSettings(this.settingsState);
    this.settingsState.actionMessage = '默认时间窗口已更新';
    this.settingsState.errorMessage = undefined;
    void this.refreshHome();
  }

  showThemePicker(): void {
    this.settingsState.isThemePickerVisible = true;
    this.settingsState.errorMessage = undefined;
  }

  hideThemePicker(): void {
    this.settingsState.isThemePickerVisible = false;
  }

  selectThemeMode(themeMode: string): void {
    this.settingsState.themeMode = themeMode;
    this.settingsState.isThemePickerVisible = false;
    this.persistLocalSettings();
    this.applyLocalSettings(this.settingsState);
    this.settingsState.actionMessage = `主题已切换为${themeModeLabel(themeMode)}`;
    this.settingsState.errorMessage = undefined;
  }

  showLanguagePicker(): void {
    this.settingsState.isLanguagePickerVisible = true;
    this.settingsState.errorMessage = undefined;
  }

  hideLanguagePicker(): void {
    this.settingsState.isLanguagePickerVisible = false;
  }

  selectLanguage(language: string): void {
    this.settingsState.language = language;
    this.settingsState.isLanguagePickerVisible = false;
    this.persistLocalSettings();
    this.applyLocalSettings(this.settingsState);
    this.settingsState.actionMessage = `语言已切换为${languageLabel(language)}`;
    this.settingsState.errorMessage = undefined;
  }

  showZoteroDetailDialog(): void {
    this.settingsState.isZoteroDetailDialogVisible = true;
    this.settingsState.zoteroUserIdDraft = this.settingsState.zoteroUserId ?? '';
    this.settingsState.zoteroLibraryTypeDraft = this.settingsState.zoteroLibraryType ?? 'user';
    this.settingsState.zoteroApiKeyDraft = '';
    this.settingsState.zoteroTargetCollectionNameDraft = this.settingsState.zoteroTargetCollectionName;
    this.settingsState.errorMessage = undefined;
  }

  hideZoteroDetailDialog(): void {
    this.settingsState.isZoteroDetailDialogVisible = false;
  }

  showLlmDetailDialog(): void {
    this.settingsState.isLlmDetailDialogVisible = true;
    this.settingsState.llmBaseUrlDraft = this.settingsState.llmBaseUrl;
    this.settingsState.llmApiKeyDraft = '';
    this.settingsState.llmModelDraft = this.settingsState.llmModel;
    this.settingsState.errorMessage = undefined;
  }

  hideLlmDetailDialog(): void {
    this.settingsState.isLlmDetailDialogVisible = false;
  }

  updateZoteroUserIdDraft(value: string): void {
    this.settingsState.zoteroUserIdDraft = value;
  }

  updateZoteroLibraryTypeDraft(value: string): void {
    this.settingsState.zoteroLibraryTypeDraft = value;
  }

  updateZoteroApiKeyDraft(value: string): void {
    this.settingsState.zoteroApiKeyDraft = value;
  }

  updateZoteroCollectionDraft(value: string): void {
    this.settingsState.zoteroTargetCollectionNameDraft = value;
  }

  updateLlmBaseUrlDraft(value: string): void {
    this.settingsState.llmBaseUrlDraft = value;
  }

  updateLlmApiKeyDraft(value: string): void {
    this.settingsState.llmApiKeyDraft = value;
  }

  updateLlmModelDraft(value: string): void {
    this.settingsState.llmModelDraft = value;
  }

  showAboutDialog(): void {
    this.settingsState.isAboutDialogVisible = true;
    this.settingsState.errorMessage = undefined;
  }

  hideAboutDialog(): void {
    this.settingsState.isAboutDialogVisible = false;
  }

  showUpdateDialog(): void {
    this.settingsState.isUpdateDialogVisible = true;
    this.settingsState.errorMessage = undefined;
  }

  hideUpdateDialog(): void {
    this.settingsState.isUpdateDialogVisible = false;
  }

  showClearCacheDialog(): void {
    this.settingsState.isClearCacheDialogVisible = true;
    this.settingsState.errorMessage = undefined;
  }

  hideClearCacheDialog(): void {
    this.settingsState.isClearCacheDialogVisible = false;
  }

  private wait(delayMs: number): Promise<void> {
    return new Promise((resolve: () => void) => {
      setTimeout(() => resolve(), delayMs);
    });
  }

  updateProfile(displayName: string, avatarPreset: string, avatarImageUri?: string): void {
    const normalizedName = displayName.trim().length > 0 ? displayName.trim() : 'XivDaily Reader';
    this.settingsState.displayName = normalizedName;
    this.settingsState.avatarPreset = avatarPreset;
    this.settingsState.avatarImageUri = avatarImageUri;
    this.persistLocalSettings();
    this.applyLocalSettings(this.settingsState);
    this.settingsState.actionMessage = '个人资料已保存';
    this.settingsState.errorMessage = undefined;
  }

  async clearCache(): Promise<void> {
    // 这里直接对齐 Android 的两段反馈：先让用户看到“清理中”，再落到“刚刚完成”。
    this.settingsState.isClearCacheDialogVisible = false;
    this.settingsState.cacheStatusText = '清理中';
    this.settingsState.actionMessage = '正在清理首页列表与趋势缓存提示';
    this.settingsState.errorMessage = undefined;
    await this.wait(800);
    this.settingsState.cacheStatusText = '刚刚完成';
    this.settingsState.actionMessage = '缓存已清理完成';
    this.settingsState.errorMessage = undefined;
  }

  async refreshIntegrationStatusAction(): Promise<void> {
    await this.refreshIntegrationStatus(true);
  }

  async saveZoteroConfig(): Promise<void> {
    this.settingsState.isConfigBusy = true;
    this.settingsState.errorMessage = undefined;

    try {
      const status = await paperService.saveZoteroConfig(
        normalizeOptionalDraft(this.settingsState.zoteroUserIdDraft),
        this.settingsState.zoteroLibraryTypeDraft.trim().length > 0 ? this.settingsState.zoteroLibraryTypeDraft.trim() : 'user',
        normalizeOptionalDraft(this.settingsState.zoteroApiKeyDraft),
        this.settingsState.zoteroTargetCollectionNameDraft.trim().length > 0
          ? this.settingsState.zoteroTargetCollectionNameDraft.trim()
          : 'XivDaily'
      );
      this.applyRemoteIntegrationStatus(status);
      this.settingsState.isConfigBusy = false;
      this.settingsState.isZoteroDetailDialogVisible = false;
      this.settingsState.actionMessage = 'Zotero 配置已保存';
      this.settingsState.errorMessage = undefined;
    } catch (error) {
      this.settingsState.isConfigBusy = false;
      this.settingsState.errorMessage = mapUserFriendlyError('Zotero 配置保存失败', error);
    }
  }

  async saveLlmConfig(): Promise<void> {
    this.settingsState.isConfigBusy = true;
    this.settingsState.errorMessage = undefined;

    try {
      const status = await paperService.saveLlmConfig(
        this.settingsState.llmBaseUrlDraft.trim().length > 0 ? this.settingsState.llmBaseUrlDraft.trim() : DEFAULT_LLM_BASE_URL,
        normalizeOptionalDraft(this.settingsState.llmApiKeyDraft),
        this.settingsState.llmModelDraft.trim().length > 0 ? this.settingsState.llmModelDraft.trim() : DEFAULT_LLM_MODEL
      );
      this.applyRemoteIntegrationStatus(status);
      this.settingsState.isConfigBusy = false;
      this.settingsState.isLlmDetailDialogVisible = false;
      this.settingsState.actionMessage = '大模型配置已保存';
      this.settingsState.errorMessage = undefined;
    } catch (error) {
      this.settingsState.isConfigBusy = false;
      this.settingsState.errorMessage = mapUserFriendlyError('大模型配置保存失败', error);
    }
  }

  async testZoteroConfig(): Promise<void> {
    this.settingsState.isConfigBusy = true;
    this.settingsState.errorMessage = undefined;

    try {
      const result = await paperService.testZoteroConfig();
      this.settingsState.isConfigBusy = false;
      this.settingsState.actionMessage = result.ok ? result.message : undefined;
      this.settingsState.errorMessage = result.ok ? undefined : result.message;
    } catch (error) {
      this.settingsState.isConfigBusy = false;
      this.settingsState.errorMessage = mapUserFriendlyError('Zotero 连接测试失败', error);
    }
  }

  async testLlmConfig(): Promise<void> {
    this.settingsState.isConfigBusy = true;
    this.settingsState.errorMessage = undefined;

    try {
      const result = await paperService.testLlmConfig();
      this.settingsState.isConfigBusy = false;
      this.settingsState.actionMessage = result.ok ? result.message : undefined;
      this.settingsState.errorMessage = result.ok ? undefined : result.message;
    } catch (error) {
      this.settingsState.isConfigBusy = false;
      this.settingsState.errorMessage = mapUserFriendlyError('大模型连接测试失败', error);
    }
  }

  private async refreshIntegrationStatus(showSuccessMessage: boolean): Promise<void> {
    try {
      const remoteStatus = await paperService.getIntegrationConfigStatus();
      this.applyRemoteIntegrationStatus(remoteStatus);
      this.settingsState.integrationStatusFailed = false;
      this.settingsState.errorMessage = undefined;
      this.settingsState.actionMessage = showSuccessMessage ? '配置状态已刷新' : this.settingsState.actionMessage;
    } catch (error) {
      this.settingsState.integrationStatusFailed = true;
      this.settingsState.zoteroTargetCollectionStatus = 'error';
      this.settingsState.errorMessage = mapUserFriendlyError('配置状态刷新失败', error);
    }
  }

  private applyLocalSettings(nextSettings: SettingsStatus): void {
    this.settingsState.defaultCategory = nextSettings.defaultCategory;
    this.settingsState.customTags = nextSettings.customTags.slice();
    this.settingsState.defaultDays = nextSettings.defaultDays;
    this.settingsState.themeMode = nextSettings.themeMode;
    this.settingsState.hasSeenOnboarding = nextSettings.hasSeenOnboarding;
    this.settingsState.displayName = nextSettings.displayName;
    this.settingsState.avatarPreset = nextSettings.avatarPreset;
    this.settingsState.avatarImageUri = nextSettings.avatarImageUri;
    this.settingsState.language = nextSettings.language;
    this.settingsState.zoteroUserIdDraft = nextSettings.zoteroUserIdDraft;
    this.settingsState.zoteroLibraryTypeDraft = nextSettings.zoteroLibraryTypeDraft;
    this.settingsState.zoteroApiKeyDraft = nextSettings.zoteroApiKeyDraft;
    this.settingsState.zoteroTargetCollectionNameDraft = nextSettings.zoteroTargetCollectionNameDraft;
    this.settingsState.llmBaseUrlDraft = nextSettings.llmBaseUrlDraft;
    this.settingsState.llmApiKeyDraft = nextSettings.llmApiKeyDraft;
    this.settingsState.llmModelDraft = nextSettings.llmModelDraft;
    this.settingsState.isThemePickerVisible = false;
    this.settingsState.isLanguagePickerVisible = false;
    this.settingsState.isZoteroDetailDialogVisible = false;
    this.settingsState.isLlmDetailDialogVisible = false;
    this.settingsState.isAboutDialogVisible = false;
    this.settingsState.isUpdateDialogVisible = false;
    this.settingsState.isClearCacheDialogVisible = false;
    this.settingsState.cacheStatusText = nextSettings.cacheStatusText;
    this.settingsState.actionMessage = undefined;
    this.settingsState.errorMessage = undefined;

    this.homeState.customTags = nextSettings.customTags.slice();
    this.homeState.selectedDays = nextSettings.defaultDays;
    const availableCategories = this.homeState.categories.concat(nextSettings.customTags);
    if (availableCategories.indexOf(this.homeState.selectedCategory) < 0) {
      this.homeState.selectedCategory = availableCategories[0] ?? 'cs.CV';
    } else if (this.homeState.selectedCategory.indexOf('cs.') === 0) {
      this.homeState.selectedCategory = availableCategories.indexOf(nextSettings.defaultCategory) >= 0
        ? nextSettings.defaultCategory
        : this.homeState.selectedCategory;
    }
  }

  private persistLocalSettings(): void {
    // 仅把本地偏好落盘，避免把瞬时错误提示等界面态写进持久层。
    const nextSettings = this.cloneSettingsState(this.settingsState);
    nextSettings.actionMessage = undefined;
    nextSettings.errorMessage = undefined;
    nextSettings.isConfigBusy = false;
    nextSettings.isThemePickerVisible = false;
    nextSettings.isLanguagePickerVisible = false;
    nextSettings.isZoteroDetailDialogVisible = false;
    nextSettings.isLlmDetailDialogVisible = false;
    nextSettings.isAboutDialogVisible = false;
    nextSettings.isUpdateDialogVisible = false;
    nextSettings.isClearCacheDialogVisible = false;
    this.settingsState = preferenceService.save(nextSettings);
  }

  private mergeHomePapersWithLocalFavorites(items: PaperItem[]): PaperItem[] {
    const favorites = favoriteStoreService.read([]);

    return items.map((item: PaperItem) => {
      const favorite = favorites.find((saved: FavoritePaperItem) => saved.paper.id === item.id);
      if (!favorite) {
        return item;
      }
      return this.withFavoriteAndSync(item, true, favorite.paper.zoteroSyncState);
    });
  }

  private upsertFavorite(paper: PaperItem): void {
    favoriteStoreService.deleteFavorite(paper.id);
    favoriteStoreService.saveFavorite(paper);
  }

  private withFavoriteState(paper: PaperItem, favoriteState: boolean): PaperItem {
    const nextPaper: PaperItem = {
      id: paper.id,
      title: paper.title,
      authors: paper.authors,
      summary: paper.summary,
      translatedSummary: paper.translatedSummary,
      publishedAt: paper.publishedAt,
      updatedAt: paper.updatedAt,
      primaryCategory: paper.primaryCategory,
      sourceUrl: paper.sourceUrl,
      pdfUrl: paper.pdfUrl,
      favoriteState: favoriteState,
      zoteroSyncState: paper.zoteroSyncState
    };
    return nextPaper;
  }

  private withFavoriteAndSync(paper: PaperItem, favoriteState: boolean, zoteroSyncState: ZoteroSyncState): PaperItem {
    const nextPaper: PaperItem = {
      id: paper.id,
      title: paper.title,
      authors: paper.authors,
      summary: paper.summary,
      translatedSummary: paper.translatedSummary,
      publishedAt: paper.publishedAt,
      updatedAt: paper.updatedAt,
      primaryCategory: paper.primaryCategory,
      sourceUrl: paper.sourceUrl,
      pdfUrl: paper.pdfUrl,
      favoriteState: favoriteState,
      zoteroSyncState: zoteroSyncState
    };
    return nextPaper;
  }

  private cloneSettingsState(source: SettingsStatus): SettingsStatus {
    const nextSettings: SettingsStatus = {
      defaultCategory: source.defaultCategory,
      customTags: source.customTags.slice(),
      defaultDays: source.defaultDays,
      themeMode: source.themeMode,
      hasSeenOnboarding: source.hasSeenOnboarding,
      displayName: source.displayName,
      avatarPreset: source.avatarPreset,
      avatarImageUri: source.avatarImageUri,
      language: source.language,
      zoteroConfigured: source.zoteroConfigured,
      zoteroUserId: source.zoteroUserId,
      zoteroLibraryType: source.zoteroLibraryType,
      zoteroApiKeyMasked: source.zoteroApiKeyMasked,
      zoteroTargetCollectionName: source.zoteroTargetCollectionName,
      zoteroTargetCollectionKey: source.zoteroTargetCollectionKey,
      zoteroTargetCollectionStatus: source.zoteroTargetCollectionStatus,
      llmConfigured: source.llmConfigured,
      llmBaseUrl: source.llmBaseUrl,
      llmModel: source.llmModel,
      llmApiKeyMasked: source.llmApiKeyMasked,
      integrationStatusFailed: source.integrationStatusFailed,
      isConfigBusy: source.isConfigBusy,
      zoteroUserIdDraft: source.zoteroUserIdDraft,
      zoteroLibraryTypeDraft: source.zoteroLibraryTypeDraft,
      zoteroApiKeyDraft: source.zoteroApiKeyDraft,
      zoteroTargetCollectionNameDraft: source.zoteroTargetCollectionNameDraft,
      llmBaseUrlDraft: source.llmBaseUrlDraft,
      llmApiKeyDraft: source.llmApiKeyDraft,
      llmModelDraft: source.llmModelDraft,
      isThemePickerVisible: source.isThemePickerVisible,
      isLanguagePickerVisible: source.isLanguagePickerVisible,
      isZoteroDetailDialogVisible: source.isZoteroDetailDialogVisible,
      isLlmDetailDialogVisible: source.isLlmDetailDialogVisible,
      isAboutDialogVisible: source.isAboutDialogVisible,
      isUpdateDialogVisible: source.isUpdateDialogVisible,
      isClearCacheDialogVisible: source.isClearCacheDialogVisible,
      cacheStatusText: source.cacheStatusText,
      actionMessage: source.actionMessage,
      errorMessage: source.errorMessage
    };
    return nextSettings;
  }

  private applyRemoteIntegrationStatus(status: SettingsStatus): void {
    this.settingsState.zoteroConfigured = status.zoteroConfigured;
    this.settingsState.zoteroUserId = status.zoteroUserId;
    this.settingsState.zoteroLibraryType = status.zoteroLibraryType;
    this.settingsState.zoteroApiKeyMasked = status.zoteroApiKeyMasked;
    this.settingsState.zoteroTargetCollectionName = status.zoteroTargetCollectionName;
    this.settingsState.zoteroTargetCollectionKey = status.zoteroTargetCollectionKey;
    this.settingsState.zoteroTargetCollectionStatus = status.zoteroTargetCollectionStatus;
    this.settingsState.llmConfigured = status.llmConfigured;
    this.settingsState.llmBaseUrl = status.llmBaseUrl;
    this.settingsState.llmModel = status.llmModel;
    this.settingsState.llmApiKeyMasked = status.llmApiKeyMasked;
    this.settingsState.zoteroUserIdDraft = status.zoteroUserId ?? '';
    this.settingsState.zoteroLibraryTypeDraft = status.zoteroLibraryType ?? 'user';
    this.settingsState.zoteroTargetCollectionNameDraft = status.zoteroTargetCollectionName;
    this.settingsState.llmBaseUrlDraft = status.llmBaseUrl;
    this.settingsState.llmModelDraft = status.llmModel;
    this.settingsState.integrationStatusFailed = false;
  }

  private copyTranslationErrorsWithout(paperId: string): Record<string, string> {
    const nextErrors: Record<string, string> = {};
    Object.keys(this.homeState.translationErrors).forEach((key: string) => {
      if (key !== paperId) {
        nextErrors[key] = this.homeState.translationErrors[key];
      }
    });
    return nextErrors;
  }

  private isSelectedCategoryCustomTag(): boolean {
    return this.homeState.customTags.indexOf(this.homeState.selectedCategory) >= 0;
  }

  private isSearchActive(): boolean {
    return this.homeState.searchKeyword.trim().length > 0;
  }

  private toCustomTagSearchKeyword(value: string): string {
    return value.replace(/[-_]+/g, ' ').replace(/\s+/g, ' ').trim();
  }

  private normalizeCustomTag(value: string): string {
    return value.trim().replace(/\s+/g, '-').replace(/-+/g, '-').replace(/^-|-$/g, '').toLowerCase();
  }

  private clearHomeActionTimer(): void {
    if (this.homeActionTimerId !== undefined) {
      clearTimeout(this.homeActionTimerId);
      this.homeActionTimerId = undefined;
    }
  }

  private pushHomeAction(text: string): void {
    const message: HomeActionMessage = {
      id: this.nextActionMessageId,
      text: text
    };
    this.nextActionMessageId += 1;
    this.clearHomeActionTimer();
    this.homeState.actionMessage = message;
    this.homeState.errorMessage = undefined;
    this.homeActionTimerId = setTimeout(() => {
      if (this.homeState.actionMessage?.id === message.id) {
        this.homeState.actionMessage = undefined;
      }
      this.homeActionTimerId = undefined;
    }, 2500) as number;
  }
}

function mapUserFriendlyError(prefix: string, error: Object): string {
  const message = error instanceof Error ? error.message : `${error}`;
  const detail = message.toLowerCase();

  if (detail.includes('timeout') || detail.includes('2300028')) {
    return `${prefix}，请稍后重试。`;
  }
  if (detail.includes('resolve') || detail.includes('2300006')) {
    return `${prefix}，请检查当前网络连接。`;
  }
  if (detail.includes('connect') || detail.includes('refused') || detail.includes('2300007')) {
    return `${prefix}，请确认本地后端已经启动。`;
  }
  if (detail.includes('2300997')) {
    return `${prefix}，当前构建未允许明文 HTTP，请检查鸿蒙联网配置。`;
  }
  return `${prefix}，请稍后再试。`;
}

function normalizeOptionalDraft(value: string): string | undefined {
  const normalized = value.trim();
  return normalized.length > 0 ? normalized : undefined;
}

function themeModeLabel(themeMode: string): string {
  if (themeMode === 'dark') {
    return '深色';
  }
  if (themeMode === 'light') {
    return '浅色';
  }
  return '跟随系统';
}

function languageLabel(language: string): string {
  if (language === 'en-US') {
    return 'English';
  }
  return '简体中文';
}

const DEFAULT_LLM_BASE_URL: string = 'https://grok.yangyioryy.cc.cd';
const DEFAULT_LLM_MODEL: string = 'grok-4.20-0309-non-reasoning';
