export type ZoteroSyncState = 'synced' | 'not_synced' | 'failed';

export interface TrendItem {
  rank: number;
  trendTitle: string;
  summary: string;
  representativePaperIds: string[];
}

export interface TrendSummary {
  intro: string;
  items: TrendItem[];
  status: string;
  warning?: string;
}

export interface PaperItem {
  id: string;
  title: string;
  authors: string[];
  summary: string;
  translatedSummary?: string;
  publishedAt: string;
  updatedAt?: string;
  primaryCategory: string;
  sourceUrl: string;
  pdfUrl: string;
  favoriteState: boolean;
  zoteroSyncState: ZoteroSyncState;
}

export interface FavoritePaperItem {
  paper: PaperItem;
  savedAt: string;
}

export interface HomeActionMessage {
  id: number;
  text: string;
}

export interface HomeUiState {
  categories: string[];
  customTags: string[];
  dayOptions: number[];
  selectedCategory: string;
  selectedDays: number;
  searchKeywordDraft: string;
  searchKeyword: string;
  papers: PaperItem[];
  trendSummary?: TrendSummary;
  listStatus: string;
  listWarning?: string;
  emptyReason?: string;
  isLoading: boolean;
  isSummaryLoading: boolean;
  summaryExpanded: boolean;
  dismissedSummary: boolean;
  expandedAbstractPaperIds: string[];
  translatingPaperIds: string[];
  syncingPaperIds: string[];
  translationErrors: Record<string, string>;
  actionMessage?: HomeActionMessage;
  errorMessage?: string;
  trendErrorMessage?: string;
}

export interface LibraryUiState {
  favorites: FavoritePaperItem[];
  selectedPaperIds: string[];
  syncFilter: string;
  syncingPaperIds: string[];
  exportContent?: string;
  actionMessage?: string;
  errorMessage?: string;
}

export interface PaperChatMessage {
  role: 'user' | 'assistant';
  content: string;
}

export interface PaperChatUsedPaper {
  paperId: string;
  title: string;
  status: string;
  contextChars: number;
  warning?: string;
}

export interface PaperChatUiState {
  favorites: FavoritePaperItem[];
  selectedPaperIds: string[];
  messages: PaperChatMessage[];
  inputDraft: string;
  isSending: boolean;
  errorMessage?: string;
  warningMessage?: string;
  usedPapers: PaperChatUsedPaper[];
}

export interface SettingsStatus {
  defaultCategory: string;
  customTags: string[];
  defaultDays: number;
  themeMode: string;
  hasSeenOnboarding: boolean;
  displayName: string;
  avatarPreset: string;
  avatarImageUri?: string;
  language: string;
  zoteroConfigured: boolean;
  zoteroUserId?: string;
  zoteroLibraryType?: string;
  zoteroApiKeyMasked?: string;
  zoteroTargetCollectionName: string;
  zoteroTargetCollectionKey?: string;
  zoteroTargetCollectionStatus: string;
  llmConfigured: boolean;
  llmBaseUrl: string;
  llmModel: string;
  llmApiKeyMasked?: string;
  integrationStatusFailed: boolean;
  isConfigBusy: boolean;
  actionMessage?: string;
  errorMessage?: string;
}
