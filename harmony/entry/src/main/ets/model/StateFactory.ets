import {
  FavoritePaperItem,
  HomeUiState,
  LibraryUiState,
  PaperChatUiState,
  SettingsStatus
} from './AppModels';

export function createDefaultSettingsStatus(): SettingsStatus {
  return {
    defaultCategory: 'cs.CV',
    customTags: [],
    defaultDays: 3,
    themeMode: 'light',
    hasSeenOnboarding: false,
    displayName: 'XivDaily Reader',
    avatarPreset: 'study',
    language: 'zh-CN',
    zoteroConfigured: false,
    zoteroTargetCollectionName: 'XivDaily',
    zoteroTargetCollectionStatus: 'not_configured',
    llmConfigured: false,
    llmBaseUrl: 'https://example.com/v1',
    llmModel: 'grok-4.20-0309-non-reasoning',
    integrationStatusFailed: false,
    isConfigBusy: false,
    zoteroUserIdDraft: '',
    zoteroLibraryTypeDraft: 'user',
    zoteroApiKeyDraft: '',
    zoteroTargetCollectionNameDraft: 'XivDaily',
    llmBaseUrlDraft: 'https://example.com/v1',
    llmApiKeyDraft: '',
    llmModelDraft: 'grok-4.20-0309-non-reasoning',
    isThemePickerVisible: false,
    isLanguagePickerVisible: false,
    isZoteroDetailDialogVisible: false,
    isLlmDetailDialogVisible: false,
    isAboutDialogVisible: false,
    isUpdateDialogVisible: false,
    isClearCacheDialogVisible: false,
    cacheStatusText: '待清理'
  };
}

export function createDefaultHomeState(): HomeUiState {
  return {
    categories: ['cs.CV', 'cs.LG', 'cs.AI', 'cs.CL'],
    customTags: [],
    dayOptions: [1, 3, 7, 30],
    selectedCategory: 'cs.CV',
    selectedDays: 3,
    searchKeywordDraft: '',
    searchKeyword: '',
    papers: [],
    listStatus: 'ok',
    isLoading: false,
    isSummaryLoading: false,
    summaryExpanded: true,
    dismissedSummary: false,
    expandedAbstractPaperIds: [],
    translatingPaperIds: [],
    syncingPaperIds: [],
    translationErrors: {}
  };
}

export function createDefaultLibraryState(favorites: FavoritePaperItem[] = []): LibraryUiState {
  return {
    favorites,
    selectedPaperIds: [],
    syncFilter: 'all',
    syncingPaperIds: []
  };
}

export function createDefaultChatState(favorites: FavoritePaperItem[] = []): PaperChatUiState {
  return {
    favorites,
    selectedPaperIds: [],
    messages: [],
    inputDraft: '',
    isSending: false,
    usedPapers: []
  };
}
