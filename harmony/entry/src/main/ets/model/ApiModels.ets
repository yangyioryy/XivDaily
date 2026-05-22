export interface PaperQuery {
  keyword?: string;
  category?: string;
  days?: number;
  page?: number;
  pageSize?: number;
}

export interface SecretFieldStatePayload {
  configured: boolean;
  masked?: string;
}

export interface ZoteroConfigPayload {
  userId?: string;
  libraryType: string;
  apiKeyMasked?: string;
  targetCollectionName: string;
}

export interface LlmConfigPayload {
  baseUrl: string;
  model: string;
  apiKeyMasked?: string;
}

export interface IntegrationConfigPayload {
  zotero: ZoteroConfigPayload;
  llm: LlmConfigPayload;
}
