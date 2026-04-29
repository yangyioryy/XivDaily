package com.xivdaily.app.data.remote

import com.squareup.moshi.Json
import retrofit2.http.Body
import retrofit2.http.GET
import retrofit2.http.POST
import retrofit2.http.Path
import retrofit2.http.Query

interface ApiService {
    @GET("papers")
    suspend fun listPapers(
        @Query("keyword") keyword: String?,
        @Query("category") category: String?,
        @Query("days") days: Int,
        @Query("page") page: Int,
        @Query("pageSize") pageSize: Int,
    ): PaperListDto

    @GET("summaries/trends")
    suspend fun getTrendSummary(
        @Query("category") category: String?,
        @Query("days") days: Int,
    ): TrendSummaryDto

    @POST("translations")
    suspend fun translateSummary(@Body request: TranslationRequestDto): TranslationTaskDto

    @GET("ai/config/status")
    suspend fun getAiConfigStatus(): AiConfigStatusDto

    @GET("zotero/config/status")
    suspend fun getZoteroConfigStatus(): ZoteroConfigStatusDto

    @POST("zotero/sync/{paper_id}")
    suspend fun syncPaperToZotero(@Path("paper_id") paperId: String): ZoteroSyncDto

    @POST("zotero/exports/bibtex")
    suspend fun exportBibtex(@Body request: BibtexExportRequestDto): BibtexExportResponseDto
}

data class PaperListDto(
    val query: PaperQueryDto,
    val items: List<PaperDto>,
    val page: Int,
    @Json(name = "page_size") val pageSize: Int,
    val total: Int,
    @Json(name = "has_more")
    val hasMore: Boolean,
)

data class PaperQueryDto(
    val keyword: String?,
    val category: String?,
    val days: Int,
    val page: Int,
    @Json(name = "page_size") val pageSize: Int,
)

data class PaperDto(
    val id: String,
    val title: String,
    val authors: List<String>,
    val summary: String,
    @Json(name = "translated_summary") val translatedSummary: String?,
    @Json(name = "published_at") val publishedAt: String,
    @Json(name = "updated_at") val updatedAt: String,
    val categories: List<String>,
    @Json(name = "primary_category") val primaryCategory: String,
    @Json(name = "source_url") val sourceUrl: String,
    @Json(name = "pdf_url") val pdfUrl: String,
    @Json(name = "favorite_state") val favoriteState: Boolean,
    @Json(name = "zotero_sync_state") val zoteroSyncState: String,
)

data class TrendSummaryDto(
    val intro: String,
    val items: List<TrendSummaryItemDto>,
    val status: String,
    val warning: String?,
)

data class TrendSummaryItemDto(
    val rank: Int,
    @Json(name = "trend_title") val trendTitle: String,
    val summary: String,
    @Json(name = "representative_paper_ids") val representativePaperIds: List<String>,
)

data class TranslationRequestDto(
    @Json(name = "paper_id") val paperId: String,
    @Json(name = "source_summary") val sourceSummary: String,
    @Json(name = "target_language") val targetLanguage: String,
)

data class TranslationTaskDto(
    @Json(name = "paper_id") val paperId: String,
    val status: String,
    @Json(name = "translated_summary") val translatedSummary: String,
    val warning: String?,
)

data class AiConfigStatusDto(
    val configured: Boolean,
)

data class ZoteroConfigStatusDto(
    val configured: Boolean,
    @Json(name = "user_id") val userId: String?,
    @Json(name = "library_type") val libraryType: String?,
    @Json(name = "target_collection_name") val targetCollectionName: String,
    @Json(name = "target_collection_key") val targetCollectionKey: String?,
    @Json(name = "target_collection_status") val targetCollectionStatus: String,
    val warning: String?,
)

data class ZoteroSyncDto(
    @Json(name = "paper_id") val paperId: String,
    val status: String,
    @Json(name = "zotero_item_key") val zoteroItemKey: String?,
    val message: String?,
    @Json(name = "synced_at") val syncedAt: String?,
)

data class BibtexExportRequestDto(
    @Json(name = "paper_ids") val paperIds: List<String>,
)

data class BibtexExportResponseDto(
    val content: String,
    @Json(name = "exported_count") val exportedCount: Int,
)
