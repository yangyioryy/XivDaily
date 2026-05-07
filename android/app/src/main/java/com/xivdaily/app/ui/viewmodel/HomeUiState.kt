package com.xivdaily.app.ui.viewmodel

import com.xivdaily.app.data.model.PaperItem
import com.xivdaily.app.data.model.TrendSummary

data class HomeActionMessage(
    val id: Long,
    val text: String,
)

data class HomeUiState(
    val categories: List<String> = listOf("cs.CV", "cs.LG", "cs.AI", "cs.CL"),
    val customTags: List<String> = emptyList(),
    val dayOptions: List<Int> = listOf(1, 3, 7, 30),
    val selectedCategory: String = "cs.CV",
    val tagPendingDeletion: String? = null,
    val isAddTagDialogVisible: Boolean = false,
    val customTagDraft: String = "",
    val selectedDays: Int = 3,
    val searchKeywordDraft: String = "",
    val searchKeyword: String = "",
    val papers: List<PaperItem> = emptyList(),
    val translatingPaperIds: Set<String> = emptySet(),
    val translationErrors: Map<String, String> = emptyMap(),
    val listStatus: String = "ok",
    val listWarning: String? = null,
    val emptyReason: String? = null,
    val expandedAbstractPaperIds: Set<String> = emptySet(),
    val trendSummary: TrendSummary? = null,
    val trendErrorMessage: String? = null,
    val summaryExpanded: Boolean = true,
    val dismissedSummary: Boolean = false,
    val isLoading: Boolean = false,
    val isSummaryLoading: Boolean = false,
    val actionMessage: HomeActionMessage? = null,
    val errorMessage: String? = null,
) {
    val allTags: List<String>
        get() = (categories + customTags).distinct()

    val isSearchActive: Boolean
        get() = searchKeyword.isNotBlank()

    val isCustomTagSelected: Boolean
        get() = selectedCategory in customTags

    fun isCustomTag(tag: String): Boolean = tag in customTags
}
