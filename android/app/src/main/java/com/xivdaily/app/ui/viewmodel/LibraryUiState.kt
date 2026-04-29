package com.xivdaily.app.ui.viewmodel

import com.xivdaily.app.data.model.FavoritePaperItem

data class LibraryUiState(
    val favorites: List<FavoritePaperItem> = emptyList(),
    val selectedPaperIds: Set<String> = emptySet(),
    val isBatchMode: Boolean = false,
    val syncFilter: String = "all",
    val exportContent: String? = null,
    val actionMessage: String? = null,
    val errorMessage: String? = null,
)
