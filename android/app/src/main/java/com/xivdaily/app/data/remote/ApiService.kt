package com.xivdaily.app.data.remote

import retrofit2.http.GET
import retrofit2.http.Query

interface ApiService {
    @GET("papers")
    suspend fun listPapers(
        @Query("category") category: String?,
        @Query("days") days: Int,
        @Query("page") page: Int,
        @Query("pageSize") pageSize: Int,
    ): PaperListDto
}

data class PaperListDto(
    val items: List<PaperDto>,
    val total: Int,
    val hasMore: Boolean,
)

data class PaperDto(
    val id: String,
    val title: String,
    val authors: List<String>,
    val summary: String,
    val publishedAt: String,
    val primaryCategory: String,
)

