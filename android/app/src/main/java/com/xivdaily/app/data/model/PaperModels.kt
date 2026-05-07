package com.xivdaily.app.data.model

data class PaperItem(
    val id: String,
    val title: String,
    val authors: List<String>,
    val summary: String,
    val translatedSummary: String?,
    val publishedAt: String,
    val updatedAt: String,
    val primaryCategory: String,
    val sourceUrl: String,
    val pdfUrl: String,
    val favoriteState: Boolean,
    val zoteroSyncState: String,
)

data class HomePaperResult(
    val items: List<PaperItem>,
    val status: String,
    val warning: String?,
    val emptyReason: String?,
)

data class TrendSummaryItem(
    val rank: Int,
    val trendTitle: String,
    val summary: String,
    val representativePaperIds: List<String>,
)

data class TrendSummary(
    val intro: String,
    val items: List<TrendSummaryItem>,
    val status: String,
    val warning: String?,
)

data class FavoritePaperItem(
    val paper: PaperItem,
    val savedAt: String,
)

data class IntegrationConfigStatus(
    val zoteroConfigured: Boolean,
    val zoteroUserId: String?,
    val zoteroLibraryType: String?,
    val zoteroApiKeyMasked: String?,
    val zoteroTargetCollectionName: String,
    val zoteroTargetCollectionKey: String?,
    val zoteroTargetCollectionStatus: String,
    val llmConfigured: Boolean,
    val llmBaseUrl: String,
    val llmModel: String,
    val llmApiKeyMasked: String?,
)

data class ConfigTestResult(
    val ok: Boolean,
    val status: String,
    val message: String,
)

data class PaperChatMessage(
    val role: String,
    val content: String,
)

data class PaperChatUsedPaper(
    val paperId: String,
    val title: String,
    val status: String,
    val contextChars: Int,
    val warning: String?,
)

data class PaperChatResult(
    val answer: String,
    val status: String,
    val warning: String?,
    val usedPapers: List<PaperChatUsedPaper>,
)
