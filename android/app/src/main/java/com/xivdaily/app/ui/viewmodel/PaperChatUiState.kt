package com.xivdaily.app.ui.viewmodel

import com.xivdaily.app.data.model.FavoritePaperItem
import com.xivdaily.app.data.model.PaperChatMessage
import com.xivdaily.app.data.model.PaperChatUsedPaper

data class PaperChatUiState(
    val favorites: List<FavoritePaperItem> = emptyList(),
    val selectedPaperIds: Set<String> = emptySet(),
    val messages: List<PaperChatMessage> = emptyList(),
    val inputDraft: String = "",
    val isSending: Boolean = false,
    val errorMessage: String? = null,
    val warningMessage: String? = null,
    val usedPapers: List<PaperChatUsedPaper> = emptyList(),
) {
    val selectedPapers: List<FavoritePaperItem>
        get() = favorites.filter { it.paper.id in selectedPaperIds }
}
