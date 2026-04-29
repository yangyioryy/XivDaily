package com.xivdaily.app.ui.viewmodel

import com.xivdaily.app.data.model.PaperItem
import com.xivdaily.app.data.model.TrendSummary

data class HomeUiState(
    val categories: List<String> = listOf("cs.CV", "cs.LG", "cs.AI", "cs.CL"),
    val dayOptions: List<Int> = listOf(1, 3, 7, 30),
    val selectedCategory: String = "cs.CV",
    val selectedDays: Int = 3,
    val searchKeyword: String = "",
    val papers: List<PaperItem> = emptyList(),
    val trendSummary: TrendSummary? = null,
    val summaryExpanded: Boolean = true,
    val dismissedSummary: Boolean = false,
    val isLoading: Boolean = false,
    val isSummaryLoading: Boolean = false,
    val actionMessage: String? = null,
    val errorMessage: String? = null,
)
