package com.xivdaily.app.data.repository

import com.xivdaily.app.data.local.FavoritePaperDao
import com.xivdaily.app.data.local.FavoritePaperEntity
import com.xivdaily.app.data.model.FavoritePaperItem
import com.xivdaily.app.data.model.IntegrationConfigStatus
import com.xivdaily.app.data.model.PaperItem
import com.xivdaily.app.data.model.TrendSummary
import com.xivdaily.app.data.model.TrendSummaryItem
import com.xivdaily.app.data.remote.ApiService
import com.xivdaily.app.data.remote.BibtexExportRequestDto
import com.xivdaily.app.data.remote.PaperDto
import com.xivdaily.app.data.remote.TranslationRequestDto
import java.time.Instant
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map

class PaperRepository(
    private val apiService: ApiService,
    private val favoritePaperDao: FavoritePaperDao,
) {
    suspend fun listHomePapers(keyword: String?, category: String?, days: Int): List<PaperItem> {
        val response = apiService.listPapers(
            keyword = keyword?.takeIf { it.isNotBlank() },
            category = category,
            days = days,
            page = 1,
            pageSize = 20,
        )
        val localFavoriteIds = favoritePaperDao.getFavoriteIds().toSet()
        return response.items.map { dto ->
            dto.toPaperItem().copy(favoriteState = dto.id in localFavoriteIds || dto.favoriteState)
        }
    }

    suspend fun getTrendSummary(category: String?, days: Int): TrendSummary {
        val dto = apiService.getTrendSummary(category = category, days = days)
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

    suspend fun translatePaper(paper: PaperItem): PaperItem {
        val dto = apiService.translateSummary(
            TranslationRequestDto(
                paperId = paper.id,
                sourceSummary = paper.summary,
                targetLanguage = "zh-CN",
            )
        )
        return paper.copy(translatedSummary = dto.translatedSummary)
    }

    fun observeFavorites(): Flow<List<FavoritePaperItem>> {
        return favoritePaperDao.observeFavorites().map { entities ->
            entities.map { FavoritePaperItem(paper = it.toPaperItem(), savedAt = it.savedAt) }
        }
    }

    suspend fun saveFavorite(paper: PaperItem) {
        favoritePaperDao.upsertFavorite(paper.toFavoriteEntity(syncState = paper.zoteroSyncState))
    }

    suspend fun deleteFavorite(paperId: String) {
        favoritePaperDao.deleteFavorite(paperId)
    }

    suspend fun deleteFavorites(paperIds: List<String>) {
        if (paperIds.isNotEmpty()) {
            favoritePaperDao.deleteFavorites(paperIds)
        }
    }

    suspend fun syncFavoriteToZotero(paperId: String): PaperItem {
        val favorite = favoritePaperDao.getFavoriteById(paperId)
            ?: error("未找到要同步的收藏论文：$paperId")
        return syncPaperToZotero(favorite.toPaperItem())
    }

    suspend fun syncPaperToZotero(paper: PaperItem): PaperItem {
        // 同步前先落本地收藏，保证同步状态回写有稳定记录。
        saveFavorite(paper.copy(favoriteState = true))
        val result = apiService.syncPaperToZotero(paper.id)
        val nextState = result.status.ifBlank { "failed" }
        favoritePaperDao.updateZoteroSyncState(paper.id, nextState)
        return paper.copy(favoriteState = true, zoteroSyncState = nextState)
    }

    suspend fun exportBibtex(paperIds: List<String>): String {
        return apiService.exportBibtex(BibtexExportRequestDto(paperIds)).content
    }

    suspend fun getIntegrationConfigStatus(): IntegrationConfigStatus {
        val ai = apiService.getAiConfigStatus()
        val zotero = apiService.getZoteroConfigStatus()
        return IntegrationConfigStatus(
            zoteroConfigured = zotero.configured,
            zoteroUserId = zotero.userId,
            llmConfigured = ai.configured,
        )
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
    }
}
