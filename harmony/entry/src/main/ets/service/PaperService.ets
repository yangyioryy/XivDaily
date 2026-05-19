import { http } from '@kit.NetworkKit';
import hilog from '@ohos.hilog';
import {
  FavoritePaperItem,
  PaperChatMessage,
  PaperChatUsedPaper,
  PaperItem,
  SettingsStatus,
  TrendItem,
  TrendSummary,
  ZoteroSyncState
} from '../model/AppModels';
import { PaperQuery } from '../model/ApiModels';

interface RequestOptions {
  method?: http.RequestMethod;
  bodyText?: string;
  readTimeoutMs?: number;
}

interface PaperDto {
  id: string;
  title: string;
  authors: string[];
  summary: string;
  translated_summary?: string | null;
  published_at: string;
  updated_at?: string | null;
  primary_category: string;
  source_url: string;
  pdf_url: string;
  favorite_state: boolean;
  zotero_sync_state: string;
}

interface PaperListResponseDto {
  items: PaperDto[];
  status: string;
  warning?: string | null;
  empty_reason?: string | null;
}

interface TrendSummaryItemDto {
  rank: number;
  trend_title: string;
  summary: string;
  representative_paper_ids: string[];
}

interface TrendSummaryResponseDto {
  intro: string;
  items: TrendSummaryItemDto[];
  status: string;
  warning?: string | null;
}

interface TranslationRequestPayload {
  paper_id: string;
  source_summary: string;
  target_language: string;
}

interface TranslationResponseDto {
  status: string;
  translated_summary: string;
  warning?: string | null;
}

interface PaperChatPaperPayload {
  paper_id: string;
  title: string;
  summary: string;
  pdf_url: string;
  source_url?: string;
}

interface PaperChatMessagePayload {
  role: string;
  content: string;
}

interface PaperChatRequestPayload {
  papers: PaperChatPaperPayload[];
  messages: PaperChatMessagePayload[];
}

interface PaperChatUsedPaperDto {
  paper_id: string;
  title: string;
  status: string;
  context_chars: number;
  warning?: string | null;
}

interface PaperChatResponseDto {
  answer: string;
  status: string;
  warning?: string | null;
  used_papers: PaperChatUsedPaperDto[];
}

interface SecretFieldStateDto {
  configured: boolean;
  masked?: string;
}

interface IntegrationZoteroDto {
  user_id?: string | null;
  library_type: string;
  api_key: SecretFieldStateDto;
  target_collection_name: string;
}

interface IntegrationLlmDto {
  base_url: string;
  api_key: SecretFieldStateDto;
  model: string;
}

interface IntegrationConfigResponseDto {
  zotero: IntegrationZoteroDto;
  llm: IntegrationLlmDto;
}

interface ZoteroConfigStatusDto {
  configured: boolean;
  user_id?: string | null;
  library_type?: string | null;
  target_collection_name: string;
  target_collection_key?: string | null;
  target_collection_status: string;
  warning?: string | null;
}

interface ZoteroConfigSavePayload {
  user_id?: string | null;
  library_type: string;
  api_key?: string | null;
  target_collection_name: string;
}

interface LlmConfigSavePayload {
  base_url: string;
  api_key?: string | null;
  model: string;
}

interface ConfigTestResultDto {
  ok: boolean;
  status: string;
  message: string;
}

interface ZoteroSyncPayload {
  id: string;
  title: string;
  authors: string[];
  summary: string;
  published_at: string;
  updated_at?: string;
  categories: string[];
  primary_category: string;
  source_url: string;
  pdf_url: string;
}

interface ZoteroSyncResponseDto {
  status: string;
  message?: string | null;
}

interface BibtexExportPayload {
  paper_ids: string[];
}

interface BibtexExportResponseDto {
  content: string;
}

interface ErrorResponsePayload {
  message?: string;
  detail?: string;
}

interface EmptyPayload {
}

export interface HomePaperResult {
  items: PaperItem[];
  status: string;
  warning?: string;
  emptyReason?: string;
}

export interface SyncPaperResult {
  paper: PaperItem;
  message?: string;
}

export interface ConfigTestResult {
  ok: boolean;
  status: string;
  message: string;
}

export interface PaperChatResult {
  answer: string;
  status: string;
  warning?: string;
  usedPapers: PaperChatUsedPaper[];
}

const CANDIDATE_BACKEND_BASE_URLS: string[] = [
  'http://10.0.2.2:8000/',
  'https://beginnerforever.eu.cc/',
  'http://127.0.0.1:8000/'
];
const DEFAULT_CONNECT_TIMEOUT_MS: number = 20_000;
const PAPER_CHAT_TIMEOUT_MS: number = 75_000;
const FIXED_TREND_DAYS: number = 3;

export class PaperService {
  async listHomePapers(query: PaperQuery): Promise<HomePaperResult> {
    const url = this.buildUrl('papers', this.buildPaperListQuery(query));
    const response = await this.request<PaperListResponseDto>(url, this.createGetOptions());
    const items: PaperItem[] = [];

    response.items.forEach((item: PaperDto) => {
      items.push(this.mapPaper(item));
    });

    return {
      items: items,
      status: response.status,
      warning: this.normalizeOptionalText(response.warning),
      emptyReason: this.normalizeOptionalText(response.empty_reason)
    };
  }

  async getTrendSummary(category?: string): Promise<TrendSummary> {
    const query = this.buildTrendSummaryQuery(category);
    const response = await this.request<TrendSummaryResponseDto>(this.buildUrl('summaries/trends', query), this.createGetOptions());
    const trendItems: TrendItem[] = [];

    response.items.forEach((item: TrendSummaryItemDto) => {
      trendItems.push({
        rank: item.rank,
        trendTitle: item.trend_title,
        summary: item.summary,
        representativePaperIds: item.representative_paper_ids
      });
    });

    return {
      intro: response.intro,
      items: trendItems,
      status: response.status,
      warning: this.normalizeOptionalText(response.warning)
    };
  }

  async translatePaper(paper: PaperItem): Promise<PaperItem> {
    const payload: TranslationRequestPayload = {
      paper_id: paper.id,
      source_summary: paper.summary,
      target_language: 'zh-CN'
    };
    const response = await this.request<TranslationResponseDto>('translations', this.createJsonOptions(payload));
    return this.withTranslatedSummary(paper, response.translated_summary);
  }

  async syncPaperToZotero(paper: PaperItem): Promise<SyncPaperResult> {
    const payload: ZoteroSyncPayload = {
      id: paper.id,
      title: paper.title,
      authors: paper.authors,
      summary: paper.summary,
      published_at: paper.publishedAt,
      updated_at: paper.updatedAt,
      categories: this.buildCategories(paper.primaryCategory),
      primary_category: paper.primaryCategory,
      source_url: paper.sourceUrl,
      pdf_url: paper.pdfUrl
    };
    const response = await this.request<ZoteroSyncResponseDto>(`zotero/sync/${encodeURIComponent(paper.id)}`, this.createJsonOptions(payload, http.RequestMethod.POST));

    return {
      paper: this.withSyncState(paper, this.normalizeSyncState(response.status)),
      message: this.normalizeOptionalText(response.message)
    };
  }

  async exportBibtex(paperIds: string[]): Promise<string> {
    const payload: BibtexExportPayload = {
      paper_ids: paperIds
    };
    const response = await this.request<BibtexExportResponseDto>('zotero/exports/bibtex', this.createJsonOptions(payload, http.RequestMethod.POST));
    return response.content;
  }

  async chatWithPapers(papers: FavoritePaperItem[], messages: PaperChatMessage[]): Promise<PaperChatResult> {
    const payload: PaperChatRequestPayload = {
      papers: this.buildPaperChatPayload(papers),
      messages: this.buildPaperChatMessages(messages)
    };
    const response = await this.request<PaperChatResponseDto>('paper-chat/messages', this.createJsonOptions(payload, http.RequestMethod.POST, PAPER_CHAT_TIMEOUT_MS));
    const usedPapers: PaperChatUsedPaper[] = [];

    response.used_papers.forEach((item: PaperChatUsedPaperDto) => {
      usedPapers.push({
        paperId: item.paper_id,
        title: item.title,
        status: item.status,
        contextChars: item.context_chars,
        warning: this.normalizeOptionalText(item.warning)
      });
    });

    return {
      answer: response.answer,
      status: response.status,
      warning: this.normalizeOptionalText(response.warning),
      usedPapers: usedPapers
    };
  }

  async getIntegrationConfigStatus(): Promise<SettingsStatus> {
    const integration = await this.request<IntegrationConfigResponseDto>('config/integrations', this.createGetOptions());
    const zoteroStatus = await this.request<ZoteroConfigStatusDto>('zotero/config/status', this.createGetOptions());

    return {
      defaultCategory: 'cs.CV',
      customTags: [],
      defaultDays: 3,
      themeMode: 'light',
      hasSeenOnboarding: false,
      displayName: 'XivDaily Reader',
      avatarPreset: 'study',
      language: 'zh-CN',
      zoteroConfigured: zoteroStatus.configured,
      zoteroUserId: this.normalizeOptionalText(integration.zotero.user_id),
      zoteroLibraryType: integration.zotero.library_type,
      zoteroApiKeyMasked: this.normalizeOptionalText(integration.zotero.api_key.masked),
      zoteroTargetCollectionName: zoteroStatus.target_collection_name.length > 0
        ? zoteroStatus.target_collection_name
        : integration.zotero.target_collection_name,
      zoteroTargetCollectionKey: this.normalizeOptionalText(zoteroStatus.target_collection_key),
      zoteroTargetCollectionStatus: zoteroStatus.target_collection_status,
      llmConfigured: integration.llm.api_key.configured,
      llmBaseUrl: integration.llm.base_url,
      llmModel: integration.llm.model,
      llmApiKeyMasked: this.normalizeOptionalText(integration.llm.api_key.masked),
      integrationStatusFailed: false,
      isConfigBusy: false,
      zoteroUserIdDraft: this.normalizeOptionalText(integration.zotero.user_id) ?? '',
      zoteroLibraryTypeDraft: integration.zotero.library_type,
      zoteroApiKeyDraft: '',
      zoteroTargetCollectionNameDraft: zoteroStatus.target_collection_name.length > 0
        ? zoteroStatus.target_collection_name
        : integration.zotero.target_collection_name,
      llmBaseUrlDraft: integration.llm.base_url,
      llmApiKeyDraft: '',
      llmModelDraft: integration.llm.model,
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

  async saveZoteroConfig(
    userId: string | undefined,
    libraryType: string,
    apiKey: string | undefined,
    targetCollectionName: string
  ): Promise<SettingsStatus> {
    const payload: ZoteroConfigSavePayload = {
      user_id: this.normalizeOptionalText(userId),
      library_type: libraryType,
      api_key: this.normalizeOptionalText(apiKey),
      target_collection_name: targetCollectionName
    };
    await this.request<IntegrationConfigResponseDto>('config/zotero', this.createJsonOptions(payload, http.RequestMethod.PUT));
    return this.getIntegrationConfigStatus();
  }

  async saveLlmConfig(baseUrl: string, apiKey: string | undefined, model: string): Promise<SettingsStatus> {
    const payload: LlmConfigSavePayload = {
      base_url: baseUrl,
      api_key: this.normalizeOptionalText(apiKey),
      model: model
    };
    await this.request<IntegrationConfigResponseDto>('config/llm', this.createJsonOptions(payload, http.RequestMethod.PUT));
    return this.getIntegrationConfigStatus();
  }

  async testZoteroConfig(): Promise<ConfigTestResult> {
    const payload: EmptyPayload = {};
    const result = await this.request<ConfigTestResultDto>('config/zotero/test', this.createJsonOptions(payload, http.RequestMethod.POST));
    return {
      ok: result.ok,
      status: result.status,
      message: result.message
    };
  }

  async testLlmConfig(): Promise<ConfigTestResult> {
    const payload: EmptyPayload = {};
    const result = await this.request<ConfigTestResultDto>('config/llm/test', this.createJsonOptions(payload, http.RequestMethod.POST));
    return {
      ok: result.ok,
      status: result.status,
      message: result.message
    };
  }

  private async request<T>(path: string, options?: RequestOptions): Promise<T> {
    let lastError: Error = new Error('未知网络错误');
    let index: number = 0;

    while (index < CANDIDATE_BACKEND_BASE_URLS.length) {
      const baseUrl = CANDIDATE_BACKEND_BASE_URLS[index];
      const requestTask = http.createHttp();
      const requestUrl = this.resolveRequestUrl(baseUrl, path);

      try {
        const httpOptions = this.toHttpRequestOptions(options);
        const response = await requestTask.request(requestUrl, httpOptions);
        const responseText = this.responseToText(response.result);

        if (response.responseCode < 200 || response.responseCode >= 300) {
          throw new Error(this.buildHttpErrorMessage(response.responseCode, responseText));
        }
        return this.parseJson<T>(responseText);
      } catch (error) {
        lastError = this.normalizeError(error);
        hilog.warn(0x0000, 'XivDaily', 'PaperService request failed. url=%{public}s error=%{public}s', requestUrl, lastError.message);
        if (index >= CANDIDATE_BACKEND_BASE_URLS.length - 1 || !this.shouldTryNextBase(lastError)) {
          throw lastError;
        }
      } finally {
        requestTask.destroy();
      }

      index += 1;
    }

    throw lastError;
  }

  private toHttpRequestOptions(options?: RequestOptions): http.HttpRequestOptions {
    const requestOptions: http.HttpRequestOptions = {
      method: options && options.method ? options.method : http.RequestMethod.GET,
      expectDataType: http.HttpDataType.STRING,
      readTimeout: options && options.readTimeoutMs ? options.readTimeoutMs : DEFAULT_CONNECT_TIMEOUT_MS,
      connectTimeout: DEFAULT_CONNECT_TIMEOUT_MS
    };
    if (options && options.bodyText) {
      requestOptions.extraData = options.bodyText;
    }
    return requestOptions;
  }

  private createGetOptions(): RequestOptions {
    const options: RequestOptions = {
      method: http.RequestMethod.GET,
      readTimeoutMs: DEFAULT_CONNECT_TIMEOUT_MS
    };
    return options;
  }

  private createJsonOptions<T>(payload: T, method?: http.RequestMethod, readTimeoutMs?: number): RequestOptions {
    const options: RequestOptions = {
      method: method ? method : http.RequestMethod.POST,
      bodyText: JSON.stringify(payload),
      readTimeoutMs: readTimeoutMs ? readTimeoutMs : DEFAULT_CONNECT_TIMEOUT_MS
    };
    return options;
  }

  private buildUrl(baseOrPath: string, query: string = ''): string {
    let normalizedBase = baseOrPath;
    if (normalizedBase.indexOf('http://') !== 0 && normalizedBase.indexOf('https://') !== 0) {
      normalizedBase = this.getBaseUrl() + this.normalizePath(normalizedBase);
    }
    if (query.length === 0) {
      return normalizedBase;
    }
    return normalizedBase + '?' + query;
  }

  private resolveRequestUrl(baseUrl: string, path: string): string {
    if (path.indexOf('http://') === 0 || path.indexOf('https://') === 0) {
      return path.replace(this.getBaseUrl(), baseUrl);
    }
    return baseUrl + this.normalizePath(path);
  }

  private getBaseUrl(): string {
    return CANDIDATE_BACKEND_BASE_URLS[0];
  }

  private normalizePath(path: string): string {
    if (path.indexOf('/') === 0) {
      return path.slice(1);
    }
    return path;
  }

  private buildPaperListQuery(query: PaperQuery): string {
    const params: string[] = [];
    this.appendQueryParam(params, 'keyword', query.keyword);
    this.appendQueryParam(params, 'category', query.category);
    this.appendQueryParam(params, 'days', query.days);
    this.appendQueryParam(params, 'page', query.page ? query.page : 1);
    this.appendQueryParam(params, 'pageSize', query.pageSize ? query.pageSize : 20);
    return params.join('&');
  }

  private buildTrendSummaryQuery(category?: string): string {
    const params: string[] = [];
    this.appendQueryParam(params, 'category', category);
    this.appendQueryParam(params, 'days', FIXED_TREND_DAYS);
    return params.join('&');
  }

  private appendQueryParam(params: string[], key: string, value?: string | number): void {
    if (value === undefined || value === null || `${value}`.length === 0) {
      return;
    }
    params.push(`${encodeURIComponent(key)}=${encodeURIComponent(`${value}`)}`);
  }

  private buildPaperChatPayload(papers: FavoritePaperItem[]): PaperChatPaperPayload[] {
    const payloads: PaperChatPaperPayload[] = [];
    papers.forEach((item: FavoritePaperItem) => {
      payloads.push({
        paper_id: item.paper.id,
        title: item.paper.title,
        summary: item.paper.summary,
        pdf_url: item.paper.pdfUrl,
        source_url: item.paper.sourceUrl
      });
    });
    return payloads;
  }

  private buildPaperChatMessages(messages: PaperChatMessage[]): PaperChatMessagePayload[] {
    const payloads: PaperChatMessagePayload[] = [];
    messages.forEach((item: PaperChatMessage) => {
      payloads.push({
        role: item.role,
        content: item.content
      });
    });
    return payloads;
  }

  private parseJson<T>(text: string): T {
    if (text.trim().length === 0) {
      return JSON.parse('{}') as T;
    }
    return JSON.parse(text) as T;
  }

  private responseToText(result: string | Object | ArrayBuffer): string {
    if (typeof result === 'string') {
      return result;
    }
    return JSON.stringify(result);
  }

  private buildHttpErrorMessage(statusCode: number, responseText: string): string {
    const detail = this.extractRemoteMessage(responseText);
    if (detail.length > 0) {
      return 'HTTP ' + statusCode + ': ' + detail;
    }
    return 'HTTP ' + statusCode;
  }

  private extractRemoteMessage(responseText: string): string {
    if (responseText.trim().length === 0) {
      return '';
    }

    try {
      const payload = JSON.parse(responseText) as ErrorResponsePayload;
      if (payload.message && payload.message.trim().length > 0) {
        return payload.message;
      }
      if (payload.detail && payload.detail.trim().length > 0) {
        return payload.detail;
      }
    } catch (_error) {
      return responseText;
    }

    return responseText;
  }

  private shouldTryNextBase(error: Error): boolean {
    const message = error.message.toLowerCase();
    return message.includes('connect')
      || message.includes('resolve')
      || message.includes('timeout')
      || message.includes('refused')
      || message.includes('err: 111')
      || message.includes('err 111')
      || message.includes('code: 111')
      || message.includes('2300006')
      || message.includes('2300007')
      || message.includes('2300028');
  }

  private normalizeError(error: Object): Error {
    if (error instanceof Error) {
      return error;
    }
    const normalizedMessage = this.extractErrorMessage(error);
    return new Error(normalizedMessage.length > 0 ? normalizedMessage : `${error}`);
  }

  private extractErrorMessage(error: Object): string {
    if (typeof error === 'string') {
      return error;
    }
    if (typeof error !== 'object' || error === null) {
      return `${error}`;
    }

    const messageParts: string[] = [];
    const errorRecord = error as Record<string, Object>;
    this.pushErrorPart(messageParts, 'code', errorRecord['code']);
    this.pushErrorPart(messageParts, 'message', errorRecord['message']);
    this.pushErrorPart(messageParts, 'name', errorRecord['name']);
    this.pushErrorPart(messageParts, 'data', errorRecord['data']);
    this.pushErrorPart(messageParts, 'details', errorRecord['details']);

    const serialized = this.safeSerializeError(errorRecord);
    if (serialized.length > 0) {
      messageParts.push(serialized);
    }
    return messageParts.join(' | ');
  }

  private pushErrorPart(parts: string[], label: string, value: Object | undefined): void {
    if (value === undefined || value === null) {
      return;
    }
    const normalized = `${value}`.trim();
    if (normalized.length === 0 || normalized === '[object Object]') {
      return;
    }
    parts.push(`${label}: ${normalized}`);
  }

  private safeSerializeError(error: Record<string, Object>): string {
    try {
      const serialized = JSON.stringify(error);
      if (!serialized || serialized === '{}' || serialized === '[]') {
        return '';
      }
      return serialized;
    } catch (_serializeError) {
      return '';
    }
  }

  private normalizeOptionalText(value?: string | null): string | undefined {
    if (value && value.trim().length > 0) {
      return value;
    }
    return undefined;
  }

  private normalizeSyncState(value: string): ZoteroSyncState {
    if (value === 'synced') {
      return 'synced';
    }
    if (value === 'failed') {
      return 'failed';
    }
    return 'not_synced';
  }

  private mapPaper(item: PaperDto): PaperItem {
    const paper: PaperItem = {
      id: item.id,
      title: item.title,
      authors: item.authors,
      summary: item.summary,
      translatedSummary: this.normalizeOptionalText(item.translated_summary),
      publishedAt: this.normalizeDate(item.published_at),
      updatedAt: this.normalizeOptionalText(item.updated_at),
      primaryCategory: item.primary_category,
      sourceUrl: item.source_url,
      pdfUrl: item.pdf_url,
      favoriteState: item.favorite_state,
      zoteroSyncState: this.normalizeSyncState(item.zotero_sync_state)
    };
    return paper;
  }

  private withTranslatedSummary(paper: PaperItem, translatedSummary: string): PaperItem {
    const nextPaper: PaperItem = {
      id: paper.id,
      title: paper.title,
      authors: paper.authors,
      summary: paper.summary,
      translatedSummary: translatedSummary,
      publishedAt: paper.publishedAt,
      updatedAt: paper.updatedAt,
      primaryCategory: paper.primaryCategory,
      sourceUrl: paper.sourceUrl,
      pdfUrl: paper.pdfUrl,
      favoriteState: paper.favoriteState,
      zoteroSyncState: paper.zoteroSyncState
    };
    return nextPaper;
  }

  private withSyncState(paper: PaperItem, zoteroSyncState: ZoteroSyncState): PaperItem {
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
      favoriteState: true,
      zoteroSyncState: zoteroSyncState
    };
    return nextPaper;
  }

  private buildCategories(primaryCategory: string): string[] {
    const categories: string[] = [];
    if (primaryCategory.trim().length > 0) {
      categories.push(primaryCategory);
    }
    return categories;
  }

  private normalizeDate(value: string): string {
    const separatorIndex = value.indexOf('T');
    if (separatorIndex >= 0) {
      return value.slice(0, separatorIndex);
    }
    return value;
  }
}

export default new PaperService();
