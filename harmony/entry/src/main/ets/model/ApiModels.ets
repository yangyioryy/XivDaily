export interface PaperQuery {
  keyword?: string;
  category?: string;
  days?: number;
  page?: number;
  pageSize?: number;
}

export interface IntegrationConfigPayload {
  zotero: {
    userId?: string;
    libraryType: string;
    apiKeyMasked?: string;
    targetCollectionName: string;
  };
  llm: {
    baseUrl: string;
    model: string;
    apiKeyMasked?: string;
  };
}
