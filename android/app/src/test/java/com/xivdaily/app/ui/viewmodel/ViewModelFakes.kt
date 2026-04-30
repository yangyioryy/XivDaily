package com.xivdaily.app.ui.viewmodel

import com.xivdaily.app.data.datastore.UserPreferences
import com.xivdaily.app.data.datastore.UserPreferencesRepositoryContract
import com.xivdaily.app.data.model.FavoritePaperItem
import com.xivdaily.app.data.model.ConfigTestResult
import com.xivdaily.app.data.model.HomePaperResult
import com.xivdaily.app.data.model.IntegrationConfigStatus
import com.xivdaily.app.data.model.PaperItem
import com.xivdaily.app.data.model.TrendSummary
import com.xivdaily.app.data.repository.PaperRepositoryContract
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.flowOf

internal class FakePreferencesRepository(
    initial: UserPreferences = UserPreferences(),
) : UserPreferencesRepositoryContract {
    private val state = MutableStateFlow(initial)
    override val preferences: Flow<UserPreferences> = state

    override suspend fun setDefaultCategory(category: String) {
        state.value = state.value.copy(defaultCategory = category)
    }

    override suspend fun setDefaultDays(days: Int) {
        state.value = state.value.copy(defaultDays = days)
    }

    override suspend fun setThemeMode(themeMode: String) {
        state.value = state.value.copy(themeMode = themeMode)
    }

    override suspend fun setHasSeenOnboarding(hasSeen: Boolean) {
        state.value = state.value.copy(hasSeenOnboarding = hasSeen)
    }

    override suspend fun setDisplayName(displayName: String) {
        state.value = state.value.copy(displayName = displayName)
    }

    override suspend fun setAvatarPreset(avatarPreset: String) {
        state.value = state.value.copy(avatarPreset = avatarPreset)
    }

    override suspend fun setAvatarImageUri(uri: String?) {
        state.value = state.value.copy(avatarImageUri = uri)
    }
}

internal open class FakePaperRepository(
    private val favoritesFlow: Flow<List<FavoritePaperItem>> = flowOf(emptyList()),
) : PaperRepositoryContract {
    var listRequests: MutableList<Triple<String?, String?, Int?>> = mutableListOf()
    val trendRequests: MutableList<String?> = mutableListOf()
    val homePapers: MutableList<PaperItem> = mutableListOf()
    var homePaperStatus: String = "ok"
    var homePaperWarning: String? = null
    var homePaperEmptyReason: String? = null
    var trendError: Throwable? = null
    val savedFavoriteIds: MutableList<String> = mutableListOf()
    val deletedFavoriteIds: MutableList<String> = mutableListOf()
    val translationRequests: MutableList<String> = mutableListOf()
    val savedZoteroConfigs: MutableList<List<String?>> = mutableListOf()
    val savedLlmConfigs: MutableList<List<String?>> = mutableListOf()

    override suspend fun listHomePapers(keyword: String?, category: String?, days: Int?): HomePaperResult {
        listRequests.add(Triple(keyword, category, days))
        return HomePaperResult(
            items = homePapers.toList(),
            status = homePaperStatus,
            warning = homePaperWarning,
            emptyReason = homePaperEmptyReason,
        )
    }

    override suspend fun getTrendSummary(category: String?): TrendSummary {
        trendRequests += category
        trendError?.let { throw it }
        return TrendSummary(intro = "intro", items = emptyList(), status = "success", warning = null)
    }

    override suspend fun translatePaper(paper: PaperItem): PaperItem {
        translationRequests += paper.id
        return paper.copy(translatedSummary = "translated")
    }
    override fun observeFavorites(): Flow<List<FavoritePaperItem>> = favoritesFlow
    override suspend fun saveFavorite(paper: PaperItem) {
        savedFavoriteIds += paper.id
    }

    override suspend fun deleteFavorite(paperId: String) {
        deletedFavoriteIds += paperId
    }
    override suspend fun deleteFavorites(paperIds: List<String>) {}
    override suspend fun syncFavoriteToZotero(paperId: String): PaperItem = samplePaper(paperId)
    override suspend fun syncPaperToZotero(paper: PaperItem): PaperItem = paper.copy(zoteroSyncState = "synced")
    override suspend fun exportBibtex(paperIds: List<String>): String = "@misc{demo}"
    override suspend fun getIntegrationConfigStatus(): IntegrationConfigStatus = IntegrationConfigStatus(
        zoteroConfigured = true,
        zoteroUserId = "12345678",
        zoteroLibraryType = "user",
        zoteroApiKeyMasked = "***1234",
        zoteroTargetCollectionName = "XivDaily",
        zoteroTargetCollectionKey = "COLL1234",
        zoteroTargetCollectionStatus = "ready",
        llmConfigured = true,
        llmBaseUrl = "https://api.example.test/v1",
        llmModel = "gpt-test",
        llmApiKeyMasked = "***5678",
    )

    override suspend fun saveZoteroConfig(
        userId: String?,
        libraryType: String,
        apiKey: String?,
        targetCollectionName: String,
    ): IntegrationConfigStatus {
        savedZoteroConfigs += listOf(userId, libraryType, apiKey, targetCollectionName)
        return getIntegrationConfigStatus()
    }

    override suspend fun saveLlmConfig(baseUrl: String, apiKey: String?, model: String): IntegrationConfigStatus {
        savedLlmConfigs += listOf(baseUrl, apiKey, model)
        return getIntegrationConfigStatus()
    }

    override suspend fun testZoteroConfig(): ConfigTestResult {
        return ConfigTestResult(ok = true, status = "ready", message = "Zotero 配置字段已填写，可以发起连接测试。")
    }

    override suspend fun testLlmConfig(): ConfigTestResult {
        return ConfigTestResult(ok = true, status = "ready", message = "大模型配置字段已填写，可以发起摘要与翻译请求。")
    }
}

internal fun samplePaper(id: String = "2401.00001"): PaperItem {
    return PaperItem(
        id = id,
        title = "Test Paper",
        authors = listOf("Ada"),
        summary = "summary",
        translatedSummary = null,
        publishedAt = "2026-04-29T10:00:00Z",
        updatedAt = "2026-04-29T10:00:00Z",
        primaryCategory = "cs.CV",
        sourceUrl = "https://example.test/$id",
        pdfUrl = "https://example.test/$id.pdf",
        favoriteState = true,
        zoteroSyncState = "not_synced",
    )
}
