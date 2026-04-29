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
                .onFailure { error -> setError(mapLibraryError("删除收藏暂时失败", error)) }
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
                .onFailure { error -> setError(mapLibraryError("批量删除暂时失败", error)) }
        }
    }

    fun syncFavoriteToZotero(paperId: String) {
        val favorite = _uiState.value.favorites.firstOrNull { it.paper.id == paperId }
        if (favorite?.paper?.zoteroSyncState == "synced") {
            _uiState.update {
                it.copy(
                    actionMessage = "这篇论文已经同步到 Zotero",
                    errorMessage = null,
                )
            }
            return
        }
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
                .onFailure { error -> setError(mapLibraryError("收藏同步暂时失败", error)) }
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
                .onFailure { error -> setError(mapLibraryError("导出暂时失败", error)) }
        }
    }

    private fun setError(message: String) {
        _uiState.update { it.copy(errorMessage = message) }
    }
}

private fun mapLibraryError(prefix: String, error: Throwable): String {
    val detail = error.message.orEmpty()
    return when {
        detail.contains("timeout", ignoreCase = true) -> "$prefix，请稍后重试。"
        detail.contains("Unable to resolve host", ignoreCase = true) -> "$prefix，请检查当前网络连接。"
        detail.contains("Failed to connect", ignoreCase = true) ||
            detail.contains("Connection refused", ignoreCase = true) -> "$prefix，请确认本地服务已经启动。"
        else -> "$prefix，请稍后再试。"
    }
}
