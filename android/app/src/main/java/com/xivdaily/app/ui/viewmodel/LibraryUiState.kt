package com.xivdaily.app.ui.viewmodel

data class LibraryUiState(
    val selectedPaperIds: Set<String> = emptySet(),
    val isBatchMode: Boolean = false,
    val syncFilter: String = "all",
)

