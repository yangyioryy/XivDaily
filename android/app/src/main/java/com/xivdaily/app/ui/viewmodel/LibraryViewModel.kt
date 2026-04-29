package com.xivdaily.app.ui.viewmodel

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.xivdaily.app.data.repository.PaperRepositoryContract
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.launchIn
import kotlinx.coroutines.flow.onEach
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

class LibraryViewModel(private val repository: PaperRepositoryContract) : ViewModel() {
    private val _uiState = MutableStateFlow(LibraryUiState())
    val uiState: StateFlow<LibraryUiState> = _uiState.asStateFlow()

    init {
        repository.observeFavorites()
            .onEach { favorites ->
                _uiState.update { state ->
                    val existingIds = favorites.map { it.paper.id }.toSet()
                    state.copy(
                        favorites = favorites,
                        selectedPaperIds = state.selectedPaperIds.intersect(existingIds),
                        isBatchMode = state.selectedPaperIds.intersect(existingIds).isNotEmpty(),
                    )
                }
            }
            .launchIn(viewModelScope)
    }

    fun togglePaperSelection(paperId: String) {
        val current = _uiState.value.selectedPaperIds
        val next = if (paperId in current) current - paperId else current + paperId
        // 收藏库的批量选择必须和删除、导出动作保持一致。
        _uiState.update { it.copy(selectedPaperIds = next, isBatchMode = next.isNotEmpty()) }
    }

    fun clearSelection() {
        _uiState.update { it.copy(selectedPaperIds = emptySet(), isBatchMode = false) }
    }

    fun changeSyncFilter(filter: String) {
        _uiState.update { it.copy(syncFilter = filter) }
    }

    fun deleteFavorite(paperId: String) {
        viewModelScope.launch {
            runCatching { repository.deleteFavorite(paperId) }
                .onSuccess { _uiState.update { it.copy(actionMessage = "已删除收藏", errorMessage = null) } }
                .onFailure { error -> setError("删除失败：${error.message ?: "未知错误"}") }
        }
    }

    fun deleteSelectedFavorites() {
        val ids = _uiState.value.selectedPaperIds.toList()
        if (ids.isEmpty()) {
            setError("请先选择要删除的论文")
            return
        }
        viewModelScope.launch {
            runCatching { repository.deleteFavorites(ids) }
                .onSuccess {
                    _uiState.update {
                        it.copy(
                            selectedPaperIds = emptySet(),
                            isBatchMode = false,
                            actionMessage = "已批量删除 ${ids.size} 条收藏",
                            errorMessage = null,
                        )
                    }
                }
                .onFailure { error -> setError("批量删除失败：${error.message ?: "未知错误"}") }
        }
    }

    fun syncFavoriteToZotero(paperId: String) {
        viewModelScope.launch {
            runCatching { repository.syncFavoriteToZotero(paperId) }
                .onSuccess { synced ->
                    _uiState.update {
                        it.copy(
                            actionMessage = "已同步到 Zotero：${synced.title}",
                            errorMessage = null,
                        )
                    }
                }
                .onFailure { error -> setError("收藏同步失败：${error.message ?: "未知错误"}") }
        }
    }

    fun exportSelectedBibtex() {
        val ids = _uiState.value.selectedPaperIds.toList()
        if (ids.isEmpty()) {
            setError("请先选择要导出的论文")
            return
        }
        viewModelScope.launch {
            runCatching { repository.exportBibtex(ids) }
                .onSuccess { content ->
                    _uiState.update { it.copy(exportContent = content, actionMessage = "BibTeX 已生成", errorMessage = null) }
                }
                .onFailure { error -> setError("导出失败：${error.message ?: "未知错误"}") }
        }
    }

    private fun setError(message: String) {
        _uiState.update { it.copy(errorMessage = message) }
    }
}
