package com.xivdaily.app.data.repository

import com.xivdaily.app.data.local.FavoritePaperDao
import com.xivdaily.app.data.local.FavoritePaperEntity
import com.xivdaily.app.data.model.FavoritePaperItem
import com.xivdaily.app.data.model.ConfigTestResult
import com.xivdaily.app.data.model.HomePaperResult
import com.xivdaily.app.data.model.IntegrationConfigStatus
import com.xivdaily.app.data.model.PaperItem
import com.xivdaily.app.data.model.TrendSummary
import com.xivdaily.app.data.model.TrendSummaryItem
import com.xivdaily.app.data.remote.ApiService
import com.xivdaily.app.data.remote.BibtexExportRequestDto
import com.xivdaily.app.data.remote.LlmConfigSaveRequestDto
import com.xivdaily.app.data.remote.PaperDto
import com.xivdaily.app.data.remote.TranslationRequestDto
import com.xivdaily.app.data.remote.ZoteroConfigSaveRequestDto
import java.time.Instant
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map

// 按 UI 使用场景拆分契约，避免 ViewModel 依赖不属于自己的远端能力。
interface HomePaperRepositoryContract {
    suspend fun listHomePapers(keyword: String?, category: String?, days: Int?): HomePaperResult
    suspend fun getTrendSummary(category: String?): TrendSummary
    suspend fun translatePaper(paper: PaperItem): PaperItem
    suspend fun saveFavorite(paper: PaperItem)
    suspend fun deleteFavorite(paperId: String)
    suspend fun syncPaperToZotero(paper: PaperItem): PaperItem
}

interface FavoritePaperRepositoryContract {
    fun observeFavorites(): Flow<List<FavoritePaperItem>>
    suspend fun deleteFavorite(paperId: String)
    suspend fun deleteFavorites(paperIds: List<String>)
    suspend fun syncFavoriteToZotero(paperId: String): PaperItem
    suspend fun exportBibtex(paperIds: List<String>): String
}

interface IntegrationConfigRepositoryContract {
    suspend fun getIntegrationConfigStatus(): IntegrationConfigStatus
    suspend fun saveZoteroConfig(userId: String?, libraryType: String, apiKey: String?, targetCollectionName: String): IntegrationConfigStatus
    suspend fun saveLlmConfig(baseUrl: String, apiKey: String?, model: String): IntegrationConfigStatus
    suspend fun testZoteroConfig(): ConfigTestResult
    suspend fun testLlmConfig(): ConfigTestResult
}

interface PaperRepositoryContract :
    HomePaperRepositoryContract,
    FavoritePaperRepositoryContract,
    IntegrationConfigRepositoryContract

class PaperRepository(
    private val apiService: ApiService,
    private val favoritePaperDao: FavoritePaperDao,
) : PaperRepositoryContract {
    override suspend fun listHomePapers(keyword: String?, category: String?, days: Int?): HomePaperResult {
        val response = apiService.listPapers(
            keyword = keyword?.takeIf { it.isNotBlank() },
            category = category,
            days = days,
            page = 1,
            pageSize = 20,
        )
        val localFavoriteIds = favoritePaperDao.getFavoriteIds().toSet()
        val items = response.items.map { dto ->
            dto.toPaperItem().copy(favoriteState = dto.id in localFavoriteIds || dto.favoriteState)
        }
        return HomePaperResult(
            items = items,
            status = response.status,
            warning = response.warning,
            emptyReason = response.emptyReason,
        )
    }

    override suspend fun getTrendSummary(category: String?): TrendSummary {
        // 趋势简报在客户端固定取最近三天，和论文列表时间窗彻底解耦。
        val dto = apiService.getTrendSummary(category = category, days = FIXED_TREND_DAYS)
        return TrendSummary(
            intro = dto.intro,
            items = dto.items.map {
                TrendSummaryItem(
                    rank = it.rank,
                    trendTitle = it.trendTitle,
                    summary = it.summary,
                    representativePaperIds = it.representativePaperIds,
                )
            },
            status = dto.status,
            warning = dto.warning,
        )
    }

    override suspend fun translatePaper(paper: PaperItem): PaperItem {
        val dto = apiService.translateSummary(
            TranslationRequestDto(
                paperId = paper.id,
                sourceSummary = paper.summary,
                targetLanguage = "zh-CN",
            )
        )
        return paper.copy(translatedSummary = dto.translatedSummary)
    }

    override fun observeFavorites(): Flow<List<FavoritePaperItem>> {
        return favoritePaperDao.observeFavorites().map { entities ->
            entities.map { FavoritePaperItem(paper = it.toPaperItem(), savedAt = it.savedAt) }
        }
    }

    override suspend fun saveFavorite(paper: PaperItem) {
        favoritePaperDao.upsertFavorite(paper.toFavoriteEntity(syncState = paper.zoteroSyncState))
    }

    override suspend fun deleteFavorite(paperId: String) {
        favoritePaperDao.deleteFavorite(paperId)
    }

    override suspend fun deleteFavorites(paperIds: List<String>) {
        if (paperIds.isNotEmpty()) {
            favoritePaperDao.deleteFavorites(paperIds)
        }
    }

    override suspend fun syncFavoriteToZotero(paperId: String): PaperItem {
        val favorite = favoritePaperDao.getFavoriteById(paperId)
            ?: error("未找到要同步的收藏论文：$paperId")
        return syncPaperToZotero(favorite.toPaperItem())
    }

    override suspend fun syncPaperToZotero(paper: PaperItem): PaperItem {
        // 同步前先落本地收藏，保证同步状态回写有稳定记录。
        saveFavorite(paper.copy(favoriteState = true))
        val result = apiService.syncPaperToZotero(paper.id)
        val nextState = result.status.ifBlank { "failed" }
        favoritePaperDao.updateZoteroSyncState(paper.id, nextState)
        return paper.copy(favoriteState = true, zoteroSyncState = nextState)
    }

    override suspend fun exportBibtex(paperIds: List<String>): String {
        return apiService.exportBibtex(BibtexExportRequestDto(paperIds)).content
    }

    override suspend fun getIntegrationConfigStatus(): IntegrationConfigStatus {
        val config = apiService.getIntegrationConfig()
        val zotero = apiService.getZoteroConfigStatus()
        return IntegrationConfigStatus(
            zoteroConfigured = zotero.configured,
            zoteroUserId = config.zotero.userId,
            zoteroLibraryType = config.zotero.libraryType,
            zoteroApiKeyMasked = config.zotero.apiKey.masked,
            zoteroTargetCollectionName = zotero.targetCollectionName,
            zoteroTargetCollectionKey = zotero.targetCollectionKey,
            zoteroTargetCollectionStatus = zotero.targetCollectionStatus,
            llmConfigured = config.llm.apiKey.configured,
            llmBaseUrl = config.llm.baseUrl,
            llmModel = config.llm.model,
            llmApiKeyMasked = config.llm.apiKey.masked,
        )
    }

    override suspend fun saveZoteroConfig(
        userId: String?,
        libraryType: String,
        apiKey: String?,
        targetCollectionName: String,
    ): IntegrationConfigStatus {
        apiService.saveZoteroConfig(
            ZoteroConfigSaveRequestDto(
                userId = userId,
                libraryType = libraryType,
                apiKey = apiKey,
                targetCollectionName = targetCollectionName,
            )
        )
        return getIntegrationConfigStatus()
    }

    override suspend fun saveLlmConfig(baseUrl: String, apiKey: String?, model: String): IntegrationConfigStatus {
        apiService.saveLlmConfig(
            LlmConfigSaveRequestDto(
                baseUrl = baseUrl,
                apiKey = apiKey,
                model = model,
            )
        )
        return getIntegrationConfigStatus()
    }

    override suspend fun testZoteroConfig(): ConfigTestResult {
        val result = apiService.testZoteroConfig()
        return ConfigTestResult(ok = result.ok, status = result.status, message = result.message)
    }

    override suspend fun testLlmConfig(): ConfigTestResult {
        val result = apiService.testLlmConfig()
        return ConfigTestResult(ok = result.ok, status = result.status, message = result.message)
    }

    private fun PaperDto.toPaperItem(): PaperItem {
        return PaperItem(
            id = id,
            title = title,
            authors = authors,
            summary = summary,
            translatedSummary = translatedSummary,
            publishedAt = publishedAt,
            updatedAt = updatedAt,
            primaryCategory = primaryCategory,
            sourceUrl = sourceUrl,
            pdfUrl = pdfUrl,
            favoriteState = favoriteState,
            zoteroSyncState = zoteroSyncState,
        )
    }

    private fun FavoritePaperEntity.toPaperItem(): PaperItem {
        return PaperItem(
            id = paperId,
            title = title,
            authors = authorsJson.split(AUTHOR_SEPARATOR).filter { it.isNotBlank() },
            summary = summary,
            translatedSummary = null,
            publishedAt = publishedAt,
            updatedAt = publishedAt,
            primaryCategory = primaryCategory,
            sourceUrl = sourceUrl,
            pdfUrl = pdfUrl,
            favoriteState = true,
            zoteroSyncState = zoteroSyncState,
        )
    }

    private fun PaperItem.toFavoriteEntity(syncState: String): FavoritePaperEntity {
        return FavoritePaperEntity(
            paperId = id,
            title = title,
            authorsJson = authors.joinToString(AUTHOR_SEPARATOR),
            summary = summary,
            publishedAt = publishedAt,
            primaryCategory = primaryCategory,
            sourceUrl = sourceUrl,
            pdfUrl = pdfUrl,
            savedAt = Instant.now().toString(),
            zoteroSyncState = syncState,
        )
    }

    private companion object {
        const val AUTHOR_SEPARATOR = ";;"
        const val FIXED_TREND_DAYS = 3
    }
}
