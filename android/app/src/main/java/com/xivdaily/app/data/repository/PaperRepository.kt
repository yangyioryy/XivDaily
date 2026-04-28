package com.xivdaily.app.data.repository

import com.xivdaily.app.data.remote.ApiService

class PaperRepository(private val apiService: ApiService) {
    suspend fun listHomePapers(category: String?, days: Int) =
        apiService.listPapers(category = category, days = days, page = 1, pageSize = 20)
}

