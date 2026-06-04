import {
  FavoritePaperItem,
  HomeActionMessage,
  HomeUiState,
  LibraryUiState,
  PaperChatMessage,
  PaperChatUiState,
  PaperItem,
  SettingsStatus,
  TrendItem,
  TrendSummary,
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
import { normalizeXivThemeMode } from '../common/theme/XivTheme';

@Observed
export class AppViewModel {
  selectedTab: number = 0;
  onTabChanged?: (index: number) => void;
  homeState: HomeUiState = createDefaultHomeState();
  libraryState: LibraryUiState = createDefaultLibraryState();
  chatState: PaperChatUiState = createDefaultChatState();
  settingsState: SettingsStatus = createDefaultSettingsStatus();

  private nextActionMessageId: number = 1;
  private homeActionTimerId?: number;
  private settingsFeedbackTimerId?: number;
  private bootstrapped: boolean = false;
  // 用会话版本隔离收藏库快速进入对话与旧请求返回，避免旧回复污染新上下文。
  private activeChatSessionVersion: number = 0;

  constructor() {
    preferenceService.initialize(this.settingsState);
    const storedFavorites = favoriteStoreService.read([]);
    favoriteStoreService.initialize(storedFavorites);
    this.applyLocalSettings(preferenceService.read(this.settingsState));
    this.refreshFavorites();
  }

  ensureBootstrapped(): void {
    if (this.bootstrapped) {
      return;
    }
    this.bootstrapped = true;
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
    if (this.onTabChanged) {
      this.onTabChanged(index);
    }
  }

  updateSearchKeywordDraft(value: string): void {
    this.updateHomeState((state: HomeUiState) => {
      state.searchKeywordDraft = value;
    });
  }

  submitSearch(): void {
    this.updateHomeState((state: HomeUiState) => {
      state.searchKeyword = state.searchKeywordDraft.trim();
    });
    void this.refreshHome();
  }

  clearSearch(): void {
    this.updateHomeState((state: HomeUiState) => {
      state.searchKeyword = '';
      state.searchKeywordDraft = '';
    });
    void this.refreshHome();
  }

  selectCategory(category: string): void {
    this.updateHomeState((state: HomeUiState) => {
      state.selectedCategory = category;
      state.dismissedSummary = false;
      state.errorMessage = undefined;
      state.trendErrorMessage = undefined;
    });
    void this.refreshFeed();
  }

  selectDays(days: number): void {
    this.updateHomeState((state: HomeUiState) => {
      state.selectedDays = days;
    });
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
    this.updateSettingsState((state: SettingsStatus) => {
      state.customTags = nextTags;
    });
    this.persistLocalSettings();
    this.applyLocalSettings(this.settingsState);
    this.updateHomeState((state: HomeUiState) => {
      state.selectedCategory = normalizedTag;
      state.dismissedSummary = false;
    });
    void this.refreshFeed();
    this.pushHomeAction(`已添加标签：${normalizedTag}`);
  }

  deleteCustomTag(tag: string): void {
    if (this.homeState.customTags.indexOf(tag) < 0) {
      return;
    }

    const nextTags = this.homeState.customTags.filter((item: string) => item !== tag);
    this.updateSettingsState((state: SettingsStatus) => {
      state.customTags = nextTags;
    });
    this.persistLocalSettings();
    this.applyLocalSettings(this.settingsState);
    this.updateHomeState((state: HomeUiState) => {
      if (state.selectedCategory === tag) {
        state.selectedCategory = state.categories[0] ?? 'cs.CV';
      }
      state.dismissedSummary = false;
    });
    void this.refreshFeed();
    this.pushHomeAction(`已删除标签：${tag}`);
  }

  toggleAbstract(paperId: string): void {
    const existed = this.homeState.expandedAbstractPaperIds.indexOf(paperId) >= 0;
    this.updateHomeState((state: HomeUiState) => {
      state.expandedAbstractPaperIds = existed
        ? state.expandedAbstractPaperIds.filter((id: string) => id !== paperId)
        : [...state.expandedAbstractPaperIds, paperId];
    });
  }

  toggleSummaryExpanded(): void {
    this.updateHomeState((state: HomeUiState) => {
      state.summaryExpanded = !state.summaryExpanded;
    });
  }

  dismissSummary(): void {
    this.updateHomeState((state: HomeUiState) => {
      state.dismissedSummary = true;
    });
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

    this.updateHomeState((state: HomeUiState) => {
      state.isLoading = true;
      state.errorMessage = undefined;
    });

    try {
      const result = await paperService.listHomePapers({
        keyword: keyword,
        category: category,
        days: days,
        page: 1,
        pageSize: 20
      });

      this.updateHomeState((state: HomeUiState) => {
        state.papers = this.mergeHomePapersWithLocalFavorites(result.items);
        state.listStatus = result.status;
        state.listWarning = result.warning;
        state.emptyReason = result.emptyReason;
      });
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
      this.updateHomeState((state: HomeUiState) => {
        state.errorMessage = mapUserFriendlyError('论文列表暂时无法刷新', error);
      });
    } finally {
      this.updateHomeState((state: HomeUiState) => {
        state.isLoading = false;
      });
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
    this.updateHomeState((state: HomeUiState) => {
      state.isSummaryLoading = true;
    });
    const category = this.isSelectedCategoryCustomTag() ? undefined : this.homeState.selectedCategory;

    try {
      const trendSummary = await paperService.getTrendSummary(category);
      this.updateHomeState((state: HomeUiState) => {
        state.trendSummary = trendSummary;
        state.trendErrorMessage = undefined;
      });
      hilog.info(
        0x0000,
        'XivDaily',
        'refreshTrendSummary success. items=%{public}s status=%{public}s',
        `${this.homeState.trendSummary?.items.length ?? 0}`,
        `${this.homeState.trendSummary?.status ?? ''}`
      );
    } catch (error) {
      this.updateHomeState((state: HomeUiState) => {
        state.trendErrorMessage = mapUserFriendlyError('趋势摘要暂时不可用', error);
      });
    } finally {
      this.updateHomeState((state: HomeUiState) => {
        state.isSummaryLoading = false;
      });
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

    this.updateHomeState((state: HomeUiState) => {
      state.translatingPaperIds = [...state.translatingPaperIds, paperId];
      state.translationErrors = this.copyTranslationErrorsWithout(paperId);
    });

    try {
      const translated = await paperService.translatePaper(paper);
      this.updateHomeState((state: HomeUiState) => {
        state.papers = state.papers.map((item: PaperItem) => {
          return item.id === paperId ? translated : item;
        });
      });
      this.pushHomeAction('摘要翻译已完成');
    } catch (error) {
      const nextErrors = this.copyTranslationErrorsWithout('');
      nextErrors[paperId] = mapUserFriendlyError('摘要翻译暂时不可用', error);
      this.updateHomeState((state: HomeUiState) => {
        state.translationErrors = nextErrors;
      });
    } finally {
      this.updateHomeState((state: HomeUiState) => {
        state.translatingPaperIds = state.translatingPaperIds.filter((id: string) => id !== paperId);
      });
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

    this.updateHomeState((state: HomeUiState) => {
      state.papers = state.papers.map((item: PaperItem) => {
        return item.id === paperId ? updatedPaper : item;
      });
    });
    this.refreshFavorites();
  }

  dismissHomePaper(paperId: string): void {
    const paper = this.homeState.papers.find((item: PaperItem) => item.id === paperId);
    if (!paper) {
      return;
    }

    this.updateHomeState((state: HomeUiState) => {
      state.papers = state.papers.filter((item: PaperItem) => item.id !== paperId);
      state.expandedAbstractPaperIds = state.expandedAbstractPaperIds.filter((id: string) => id !== paperId);
      state.translatingPaperIds = state.translatingPaperIds.filter((id: string) => id !== paperId);
      state.syncingPaperIds = state.syncingPaperIds.filter((id: string) => id !== paperId);
      state.translationErrors = this.copyTranslationErrorsWithout(paperId);
    });
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

    this.updateHomeState((state: HomeUiState) => {
      state.syncingPaperIds = [...state.syncingPaperIds, paperId];
    });
    this.pushHomeAction('正在同步到 Zotero...');

    try {
      const result = await paperService.syncPaperToZotero(paper);
      this.updateHomeState((state: HomeUiState) => {
        state.papers = state.papers.map((item: PaperItem) => {
          return item.id === paperId ? result.paper : item;
        });
      });
      this.upsertFavorite(result.paper);
      this.refreshFavorites();
      this.pushHomeAction(result.paper.zoteroSyncState === 'synced' ? '已同步到 Zotero' : (result.message ?? 'Zotero 同步暂未完成'));
    } catch (error) {
      this.updateHomeState((state: HomeUiState) => {
        state.errorMessage = mapUserFriendlyError('Zotero 同步暂时失败', error);
      });
    } finally {
      this.updateHomeState((state: HomeUiState) => {
        state.syncingPaperIds = state.syncingPaperIds.filter((id: string) => id !== paperId);
      });
    }
  }

  refreshFavorites(): void {
    const favorites = favoriteStoreService.read([]);
    const favoriteIds = favorites.map((item: FavoritePaperItem) => item.paper.id);
    const nextChatSelectedPaperIds = this.chatState.selectedPaperIds.filter((id: string) => favoriteIds.indexOf(id) >= 0);

    this.updateLibraryState((state: LibraryUiState) => {
      state.favorites = favorites;
      state.selectedPaperIds = state.selectedPaperIds.filter((id: string) => favoriteIds.indexOf(id) >= 0);
    });
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
    this.updateHomeState((state: HomeUiState) => {
      state.papers = this.mergeHomePapersWithLocalFavorites(state.papers);
    });
  }

  toggleLibrarySelection(paperId: string): void {
    const existed = this.libraryState.selectedPaperIds.indexOf(paperId) >= 0;
    this.updateLibraryState((state: LibraryUiState) => {
      state.selectedPaperIds = existed
        ? state.selectedPaperIds.filter((id: string) => id !== paperId)
        : [...state.selectedPaperIds, paperId];
    });
  }

  selectAllLibraryPapers(paperIds: string[]): void {
    this.updateLibraryState((state: LibraryUiState) => {
      state.selectedPaperIds = paperIds.slice();
      state.errorMessage = undefined;
    });
  }

  selectLibraryFilter(filter: string): void {
    this.updateLibraryState((state: LibraryUiState) => {
      state.syncFilter = filter;
    });
  }

  async syncFavoriteToZotero(paperId: string): Promise<void> {
    const favorite = this.libraryState.favorites.find((item: FavoritePaperItem) => item.paper.id === paperId);
    if (!favorite) {
      return;
    }
    if (favorite.paper.zoteroSyncState === 'synced') {
      this.updateLibraryState((state: LibraryUiState) => {
        state.actionMessage = '这篇论文已经同步到 Zotero';
        state.errorMessage = undefined;
      });
      return;
    }
    if (this.libraryState.syncingPaperIds.indexOf(paperId) >= 0) {
      return;
    }

    this.updateLibraryState((state: LibraryUiState) => {
      state.syncingPaperIds = [...state.syncingPaperIds, paperId];
      state.actionMessage = '正在同步到 Zotero...';
      state.errorMessage = undefined;
    });

    try {
      const result = await paperService.syncPaperToZotero(favorite.paper);
      this.updateHomeState((state: HomeUiState) => {
        state.papers = state.papers.map((item: PaperItem) => {
          return item.id === paperId ? result.paper : item;
        });
      });
      this.upsertFavorite(result.paper);
      this.refreshFavorites();
      this.updateLibraryState((state: LibraryUiState) => {
        state.actionMessage = result.paper.zoteroSyncState === 'synced'
          ? `已同步到 Zotero：${result.paper.title}`
          : (result.message ?? 'Zotero 同步暂未完成');
        state.errorMessage = undefined;
      });
    } catch (error) {
      this.updateLibraryState((state: LibraryUiState) => {
        state.errorMessage = mapUserFriendlyError('收藏同步暂时失败', error);
      });
    } finally {
      this.updateLibraryState((state: LibraryUiState) => {
        state.syncingPaperIds = state.syncingPaperIds.filter((id: string) => id !== paperId);
      });
    }
  }

  async exportSelectedBibtex(): Promise<void> {
    if (this.libraryState.selectedPaperIds.length === 0) {
      this.updateLibraryState((state: LibraryUiState) => {
        state.errorMessage = '请先选择要导出的论文';
      });
      return;
    }

    try {
      const exportContent = await paperService.exportBibtex(this.libraryState.selectedPaperIds);
      this.updateLibraryState((state: LibraryUiState) => {
        state.exportContent = exportContent;
        // 导出成功后立即清空批量选择，避免后续删除/再次导出误用旧选中集合。
        state.selectedPaperIds = [];
        state.actionMessage = 'BibTeX 已生成';
        state.errorMessage = undefined;
      });
    } catch (error) {
      this.updateLibraryState((state: LibraryUiState) => {
        state.errorMessage = mapUserFriendlyError('导出暂时失败', error);
      });
    }
  }

  deleteFavorite(paperId: string): void {
    favoriteStoreService.deleteFavorite(paperId);
    this.refreshFavorites();
    this.updateHomeState((state: HomeUiState) => {
      state.papers = state.papers.map((item: PaperItem) => {
        return item.id === paperId ? this.withFavoriteState(item, false) : item;
      });
    });
    this.updateLibraryState((state: LibraryUiState) => {
      state.selectedPaperIds = state.selectedPaperIds.filter((id: string) => id !== paperId);
      state.actionMessage = '已删除收藏';
      state.errorMessage = undefined;
    });
  }

  deleteSelectedFavorites(): void {
    if (this.libraryState.selectedPaperIds.length === 0) {
      this.updateLibraryState((state: LibraryUiState) => {
        state.errorMessage = '请先选择要删除的论文';
      });
      return;
    }

    const ids = this.libraryState.selectedPaperIds.slice();
    ids.forEach((paperId: string) => {
      favoriteStoreService.deleteFavorite(paperId);
    });
    this.refreshFavorites();
    this.updateHomeState((state: HomeUiState) => {
      state.papers = state.papers.map((item: PaperItem) => {
        return ids.indexOf(item.id) >= 0 ? this.withFavoriteState(item, false) : item;
      });
    });
    this.updateLibraryState((state: LibraryUiState) => {
      state.selectedPaperIds = [];
      state.actionMessage = `已批量删除 ${ids.length} 条收藏`;
      state.errorMessage = undefined;
    });
  }

  openChatFromLibrary(paperId: string): void {
    const favorite = this.libraryState.favorites.find((item: FavoritePaperItem) => item.paper.id === paperId);
    if (!favorite) {
      return;
    }
    this.activeChatSessionVersion += 1;
    this.selectTab(2);
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
    this.updateSettingsState((state: SettingsStatus) => {
      state.defaultCategory = category;
    });
    this.persistLocalSettings();
    this.applyLocalSettings(this.settingsState);
    this.updateSettingsState((state: SettingsStatus) => {
      state.actionMessage = '默认领域已更新';
      state.errorMessage = undefined;
    });
    void this.refreshFeed();
  }

  updateDefaultDays(days: number): void {
    this.updateSettingsState((state: SettingsStatus) => {
      state.defaultDays = days;
    });
    this.persistLocalSettings();
    this.applyLocalSettings(this.settingsState);
    this.updateSettingsState((state: SettingsStatus) => {
      state.actionMessage = '默认时间窗口已更新';
      state.errorMessage = undefined;
    });
    void this.refreshHome();
  }

  showThemePicker(): void {
    this.updateSettingsState((state: SettingsStatus) => {
      state.isThemePickerVisible = true;
      state.errorMessage = undefined;
    });
  }

  hideThemePicker(): void {
    this.updateSettingsState((state: SettingsStatus) => {
      state.isThemePickerVisible = false;
    });
  }

  selectThemeMode(themeMode: string): void {
    const normalizedThemeMode = normalizeXivThemeMode(themeMode);
    this.updateSettingsState((state: SettingsStatus) => {
      state.themeMode = normalizedThemeMode;
      state.isThemePickerVisible = false;
    });
    this.persistLocalSettings();
    this.applyLocalSettings(this.settingsState);
    this.updateSettingsState((state: SettingsStatus) => {
      state.actionMessage = `主题已切换为${themeModeLabel(normalizedThemeMode)}`;
      state.errorMessage = undefined;
    });
  }

  showLanguagePicker(): void {
    this.updateSettingsState((state: SettingsStatus) => {
      state.isLanguagePickerVisible = true;
      state.errorMessage = undefined;
    });
  }

  hideLanguagePicker(): void {
    this.updateSettingsState((state: SettingsStatus) => {
      state.isLanguagePickerVisible = false;
    });
  }

  selectLanguage(language: string): void {
    this.updateSettingsState((state: SettingsStatus) => {
      state.language = language;
      state.isLanguagePickerVisible = false;
    });
    this.persistLocalSettings();
    this.applyLocalSettings(this.settingsState);
    this.updateSettingsState((state: SettingsStatus) => {
      state.actionMessage = `语言已切换为${languageLabel(language)}`;
      state.errorMessage = undefined;
    });
  }

  showZoteroDetailDialog(): void {
    this.updateSettingsState((state: SettingsStatus) => {
      state.isZoteroDetailDialogVisible = true;
      state.zoteroUserIdDraft = state.zoteroUserId ?? '';
      state.zoteroLibraryTypeDraft = state.zoteroLibraryType ?? 'user';
      state.zoteroApiKeyDraft = '';
      state.zoteroTargetCollectionNameDraft = state.zoteroTargetCollectionName;
      state.errorMessage = undefined;
    });
  }

  hideZoteroDetailDialog(): void {
    this.updateSettingsState((state: SettingsStatus) => {
      state.isZoteroDetailDialogVisible = false;
    });
  }

  showLlmDetailDialog(): void {
    this.updateSettingsState((state: SettingsStatus) => {
      state.isLlmDetailDialogVisible = true;
      state.llmBaseUrlDraft = state.llmBaseUrl;
      state.llmApiKeyDraft = '';
      state.llmModelDraft = state.llmModel;
      state.errorMessage = undefined;
    });
  }

  hideLlmDetailDialog(): void {
    this.updateSettingsState((state: SettingsStatus) => {
      state.isLlmDetailDialogVisible = false;
    });
  }

  updateZoteroUserIdDraft(value: string): void {
    this.updateSettingsState((state: SettingsStatus) => {
      state.zoteroUserIdDraft = value;
    });
  }

  updateZoteroLibraryTypeDraft(value: string): void {
    this.updateSettingsState((state: SettingsStatus) => {
      state.zoteroLibraryTypeDraft = value;
    });
  }

  updateZoteroApiKeyDraft(value: string): void {
    this.updateSettingsState((state: SettingsStatus) => {
      state.zoteroApiKeyDraft = value;
    });
  }

  updateZoteroCollectionDraft(value: string): void {
    this.updateSettingsState((state: SettingsStatus) => {
      state.zoteroTargetCollectionNameDraft = value;
    });
  }

  updateLlmBaseUrlDraft(value: string): void {
    this.updateSettingsState((state: SettingsStatus) => {
      state.llmBaseUrlDraft = value;
    });
  }

  updateLlmApiKeyDraft(value: string): void {
    this.updateSettingsState((state: SettingsStatus) => {
      state.llmApiKeyDraft = value;
    });
  }

  updateLlmModelDraft(value: string): void {
    this.updateSettingsState((state: SettingsStatus) => {
      state.llmModelDraft = value;
    });
  }

  showAboutDialog(): void {
    this.updateSettingsState((state: SettingsStatus) => {
      state.isAboutDialogVisible = true;
      state.errorMessage = undefined;
    });
  }

  hideAboutDialog(): void {
    this.updateSettingsState((state: SettingsStatus) => {
      state.isAboutDialogVisible = false;
    });
  }

  showUpdateDialog(): void {
    this.updateSettingsState((state: SettingsStatus) => {
      state.isUpdateDialogVisible = true;
      state.errorMessage = undefined;
    });
  }

  hideUpdateDialog(): void {
    this.updateSettingsState((state: SettingsStatus) => {
      state.isUpdateDialogVisible = false;
    });
  }

  showClearCacheDialog(): void {
    this.updateSettingsState((state: SettingsStatus) => {
      state.isClearCacheDialogVisible = true;
      state.errorMessage = undefined;
    });
  }

  hideClearCacheDialog(): void {
    this.updateSettingsState((state: SettingsStatus) => {
      state.isClearCacheDialogVisible = false;
    });
  }

  private wait(delayMs: number): Promise<void> {
    return new Promise((resolve: () => void) => {
      setTimeout(() => resolve(), delayMs);
    });
  }

  updateProfile(displayName: string, avatarPreset: string, avatarImageUri?: string): void {
    const normalizedName = displayName.trim().length > 0 ? displayName.trim() : 'XivDaily Reader';
    this.updateSettingsState((state: SettingsStatus) => {
      state.displayName = normalizedName;
      state.avatarPreset = avatarPreset;
      state.avatarImageUri = avatarImageUri;
    });
    this.persistLocalSettings();
    this.applyLocalSettings(this.settingsState);
    this.updateSettingsState((state: SettingsStatus) => {
      state.actionMessage = '个人资料已保存';
      state.errorMessage = undefined;
    });
  }

  async clearCache(): Promise<void> {
    // 这里直接对齐 Android 的两段反馈：先让用户看到“清理中”，再落到“刚刚完成”。
    this.updateSettingsState((state: SettingsStatus) => {
      state.isClearCacheDialogVisible = false;
      state.cacheStatusText = '清理中';
      state.actionMessage = '正在清理首页列表与趋势缓存提示';
      state.errorMessage = undefined;
    });
    await this.wait(800);
    this.updateSettingsState((state: SettingsStatus) => {
      state.cacheStatusText = '刚刚完成';
      state.actionMessage = '缓存已清理完成';
      state.errorMessage = undefined;
    });
  }

  async refreshIntegrationStatusAction(): Promise<void> {
    await this.refreshIntegrationStatus(true);
  }

  async saveZoteroConfig(): Promise<void> {
    this.updateSettingsState((state: SettingsStatus) => {
      state.isConfigBusy = true;
      state.errorMessage = undefined;
    });

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
      this.updateSettingsState((state: SettingsStatus) => {
        state.isConfigBusy = false;
        state.isZoteroDetailDialogVisible = false;
        state.actionMessage = 'Zotero 配置已保存';
        state.errorMessage = undefined;
      });
    } catch (error) {
      this.updateSettingsState((state: SettingsStatus) => {
        state.isConfigBusy = false;
        state.errorMessage = mapUserFriendlyError('Zotero 配置保存失败', error);
      });
    }
  }

  async saveLlmConfig(): Promise<void> {
    this.updateSettingsState((state: SettingsStatus) => {
      state.isConfigBusy = true;
      state.errorMessage = undefined;
    });

    try {
      const status = await paperService.saveLlmConfig(
        this.settingsState.llmBaseUrlDraft.trim().length > 0 ? this.settingsState.llmBaseUrlDraft.trim() : DEFAULT_LLM_BASE_URL,
        normalizeOptionalDraft(this.settingsState.llmApiKeyDraft),
        this.settingsState.llmModelDraft.trim().length > 0 ? this.settingsState.llmModelDraft.trim() : DEFAULT_LLM_MODEL
      );
      this.applyRemoteIntegrationStatus(status);
      this.updateSettingsState((state: SettingsStatus) => {
        state.isConfigBusy = false;
        state.isLlmDetailDialogVisible = false;
        state.actionMessage = '大模型配置已保存';
        state.errorMessage = undefined;
      });
    } catch (error) {
      this.updateSettingsState((state: SettingsStatus) => {
        state.isConfigBusy = false;
        state.errorMessage = mapUserFriendlyError('大模型配置保存失败', error);
      });
    }
  }

  async testZoteroConfig(): Promise<void> {
    this.updateSettingsState((state: SettingsStatus) => {
      state.isConfigBusy = true;
      state.errorMessage = undefined;
    });

    try {
      const result = await paperService.testZoteroConfig();
      this.updateSettingsState((state: SettingsStatus) => {
        state.isConfigBusy = false;
        state.actionMessage = result.ok ? result.message : undefined;
        state.errorMessage = result.ok ? undefined : result.message;
      });
    } catch (error) {
      this.updateSettingsState((state: SettingsStatus) => {
        state.isConfigBusy = false;
        state.errorMessage = mapUserFriendlyError('Zotero 连接测试失败', error);
      });
    }
  }

  async testLlmConfig(): Promise<void> {
    this.updateSettingsState((state: SettingsStatus) => {
      state.isConfigBusy = true;
      state.errorMessage = undefined;
    });

    try {
      const result = await paperService.testLlmConfig();
      this.updateSettingsState((state: SettingsStatus) => {
        state.isConfigBusy = false;
        state.actionMessage = result.ok ? result.message : undefined;
        state.errorMessage = result.ok ? undefined : result.message;
      });
    } catch (error) {
      this.updateSettingsState((state: SettingsStatus) => {
        state.isConfigBusy = false;
        state.errorMessage = mapUserFriendlyError('大模型连接测试失败', error);
      });
    }
  }

  private async refreshIntegrationStatus(showSuccessMessage: boolean): Promise<void> {
    try {
      const remoteStatus = await paperService.getIntegrationConfigStatus();
      this.applyRemoteIntegrationStatus(remoteStatus);
      this.updateSettingsState((state: SettingsStatus) => {
        state.integrationStatusFailed = false;
        state.errorMessage = undefined;
        state.actionMessage = showSuccessMessage ? '配置状态已刷新' : state.actionMessage;
      });
    } catch (error) {
      this.updateSettingsState((state: SettingsStatus) => {
        state.integrationStatusFailed = true;
        state.zoteroTargetCollectionStatus = 'error';
        state.errorMessage = mapUserFriendlyError('配置状态刷新失败', error);
      });
    }
  }

  private applyLocalSettings(nextSettings: SettingsStatus): void {
    const nextState: SettingsStatus = this.cloneSettingsState(nextSettings);
    nextState.isThemePickerVisible = false;
    nextState.isLanguagePickerVisible = false;
    nextState.isZoteroDetailDialogVisible = false;
    nextState.isLlmDetailDialogVisible = false;
    nextState.isAboutDialogVisible = false;
    nextState.isUpdateDialogVisible = false;
    nextState.isClearCacheDialogVisible = false;
    nextState.actionMessage = undefined;
    nextState.errorMessage = undefined;
    this.settingsState = nextState;

    this.updateHomeState((state: HomeUiState) => {
      state.customTags = nextSettings.customTags.slice();
      state.selectedDays = nextSettings.defaultDays;
      const availableCategories = state.categories.concat(nextSettings.customTags);
      if (availableCategories.indexOf(state.selectedCategory) < 0) {
        state.selectedCategory = availableCategories[0] ?? 'cs.CV';
      } else if (state.selectedCategory.indexOf('cs.') === 0) {
        state.selectedCategory = availableCategories.indexOf(nextSettings.defaultCategory) >= 0
          ? nextSettings.defaultCategory
          : state.selectedCategory;
      }
    });
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

  private cloneHomeState(source: HomeUiState): HomeUiState {
    let nextTrendSummary: TrendSummary | undefined = undefined;
    if (source.trendSummary) {
      const nextTrendItems: TrendItem[] = source.trendSummary.items.map((item: TrendItem): TrendItem => {
        const nextItem: TrendItem = {
          rank: item.rank,
          trendTitle: item.trendTitle,
          summary: item.summary,
          representativePaperIds: item.representativePaperIds.slice()
        };
        return nextItem;
      });
      nextTrendSummary = {
        intro: source.trendSummary.intro,
        items: nextTrendItems,
        status: source.trendSummary.status,
        warning: source.trendSummary.warning
      };
    }

    const nextTranslationErrors: Record<string, string> = {};
    Object.keys(source.translationErrors).forEach((key: string) => {
      nextTranslationErrors[key] = source.translationErrors[key];
    });

    const nextActionMessage = source.actionMessage ? this.cloneHomeActionMessage(source.actionMessage) : undefined;

    const nextState: HomeUiState = {
      categories: source.categories.slice(),
      customTags: source.customTags.slice(),
      dayOptions: source.dayOptions.slice(),
      selectedCategory: source.selectedCategory,
      selectedDays: source.selectedDays,
      searchKeywordDraft: source.searchKeywordDraft,
      searchKeyword: source.searchKeyword,
      papers: source.papers.slice(),
      trendSummary: nextTrendSummary,
      listStatus: source.listStatus,
      listWarning: source.listWarning,
      emptyReason: source.emptyReason,
      isLoading: source.isLoading,
      isSummaryLoading: source.isSummaryLoading,
      summaryExpanded: source.summaryExpanded,
      dismissedSummary: source.dismissedSummary,
      expandedAbstractPaperIds: source.expandedAbstractPaperIds.slice(),
      translatingPaperIds: source.translatingPaperIds.slice(),
      syncingPaperIds: source.syncingPaperIds.slice(),
      translationErrors: nextTranslationErrors,
      actionMessage: nextActionMessage,
      errorMessage: source.errorMessage,
      trendErrorMessage: source.trendErrorMessage
    };
    return nextState;
  }

  private cloneLibraryState(source: LibraryUiState): LibraryUiState {
    const nextState: LibraryUiState = {
      favorites: source.favorites.slice(),
      selectedPaperIds: source.selectedPaperIds.slice(),
      syncFilter: source.syncFilter,
      syncingPaperIds: source.syncingPaperIds.slice(),
      exportContent: source.exportContent,
      actionMessage: source.actionMessage,
      errorMessage: source.errorMessage
    };
    return nextState;
  }

  private cloneHomeActionMessage(source: HomeActionMessage): HomeActionMessage {
    const nextMessage: HomeActionMessage = {
      id: source.id,
      text: source.text
    };
    return nextMessage;
  }

  // ArkUI 对嵌套对象字段原地赋值不总能触发刷新，这里统一用克隆后整对象替换。
  private updateHomeState(mutator: (state: HomeUiState) => void): void {
    const nextState = this.cloneHomeState(this.homeState);
    mutator(nextState);
    this.homeState = nextState;
  }

  private updateLibraryState(mutator: (state: LibraryUiState) => void): void {
    const nextState = this.cloneLibraryState(this.libraryState);
    mutator(nextState);
    this.libraryState = nextState;
  }

  private updateSettingsState(mutator: (state: SettingsStatus) => void): void {
    const previousFeedbackSignature = this.settingsFeedbackSignature(this.settingsState);
    const nextState = this.cloneSettingsState(this.settingsState);
    mutator(nextState);
    this.settingsState = nextState;
    this.syncSettingsFeedbackTimer(previousFeedbackSignature, this.settingsFeedbackSignature(nextState));
  }

  private applyRemoteIntegrationStatus(status: SettingsStatus): void {
    this.updateSettingsState((state: SettingsStatus) => {
      state.zoteroConfigured = status.zoteroConfigured;
      state.zoteroUserId = status.zoteroUserId;
      state.zoteroLibraryType = status.zoteroLibraryType;
      state.zoteroApiKeyMasked = status.zoteroApiKeyMasked;
      state.zoteroTargetCollectionName = status.zoteroTargetCollectionName;
      state.zoteroTargetCollectionKey = status.zoteroTargetCollectionKey;
      state.zoteroTargetCollectionStatus = status.zoteroTargetCollectionStatus;
      state.llmConfigured = status.llmConfigured;
      state.llmBaseUrl = status.llmBaseUrl;
      state.llmModel = status.llmModel;
      state.llmApiKeyMasked = status.llmApiKeyMasked;
      if (!state.isZoteroDetailDialogVisible) {
        state.zoteroUserIdDraft = status.zoteroUserId ?? '';
        state.zoteroLibraryTypeDraft = status.zoteroLibraryType ?? 'user';
        state.zoteroTargetCollectionNameDraft = status.zoteroTargetCollectionName;
      }
      if (!state.isLlmDetailDialogVisible) {
        state.llmBaseUrlDraft = status.llmBaseUrl;
        state.llmModelDraft = status.llmModel;
      }
      state.integrationStatusFailed = false;
    });
  }

  private settingsFeedbackSignature(state: SettingsStatus): string {
    if (state.errorMessage && state.errorMessage.length > 0) {
      return `error:${state.errorMessage}`;
    }
    if (state.actionMessage && state.actionMessage.length > 0) {
      return `action:${state.actionMessage}`;
    }
    return '';
  }

  private clearSettingsFeedbackTimer(): void {
    if (this.settingsFeedbackTimerId !== undefined) {
      clearTimeout(this.settingsFeedbackTimerId);
      this.settingsFeedbackTimerId = undefined;
    }
  }

  private syncSettingsFeedbackTimer(previousSignature: string, nextSignature: string): void {
    if (previousSignature === nextSignature) {
      return;
    }
    this.clearSettingsFeedbackTimer();
    if (nextSignature.length === 0) {
      return;
    }
    // 设置页提示条属于瞬时反馈，统一在短暂停留后自动消失，避免长期占据页面空间。
    this.settingsFeedbackTimerId = setTimeout(() => {
      if (this.settingsFeedbackSignature(this.settingsState) === nextSignature) {
        this.updateSettingsState((state: SettingsStatus) => {
          if (this.settingsFeedbackSignature(state) === nextSignature) {
            state.actionMessage = undefined;
            state.errorMessage = undefined;
          }
        });
      }
      this.settingsFeedbackTimerId = undefined;
    }, 2500) as number;
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
    this.updateHomeState((state: HomeUiState) => {
      state.actionMessage = message;
      state.errorMessage = undefined;
    });
    this.homeActionTimerId = setTimeout(() => {
      if (this.homeState.actionMessage?.id === message.id) {
        this.updateHomeState((state: HomeUiState) => {
          if (state.actionMessage?.id === message.id) {
            state.actionMessage = undefined;
          }
        });
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

const DEFAULT_LLM_BASE_URL: string = 'https://example.com/v1';
const DEFAULT_LLM_MODEL: string = 'grok-4.20-0309-non-reasoning-console';
