package com.xivdaily.app.ui.viewmodel

import androidx.lifecycle.ViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

class LibraryViewModel : ViewModel() {
    private val _uiState = MutableStateFlow(LibraryUiState())
    val uiState: StateFlow<LibraryUiState> = _uiState.asStateFlow()

    fun togglePaperSelection(paperId: String) {
        val current = _uiState.value.selectedPaperIds
        val next = if (paperId in current) current - paperId else current + paperId
        // 收藏库的批量选择必须和删除、导出动作保持一致。
        _uiState.value = _uiState.value.copy(selectedPaperIds = next, isBatchMode = next.isNotEmpty())
    }

    fun clearSelection() {
        _uiState.value = _uiState.value.copy(selectedPaperIds = emptySet(), isBatchMode = false)
    }

    fun changeSyncFilter(filter: String) {
        _uiState.value = _uiState.value.copy(syncFilter = filter)
    }
}

