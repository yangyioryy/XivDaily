package com.xivdaily.app.ui.viewmodel

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.xivdaily.app.data.model.PaperItem
import com.xivdaily.app.data.repository.PaperRepository
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

class HomeViewModel(private val repository: PaperRepository) : ViewModel() {
    private val _uiState = MutableStateFlow(HomeUiState())
    val uiState: StateFlow<HomeUiState> = _uiState.asStateFlow()

    init {
        refreshPapers()
        refreshTrendSummary()
    }

    fun updateKeyword(keyword: String) {
        _uiState.update { it.copy(searchKeyword = keyword) }
        refreshPapers()
    }

    fun selectCategory(category: String) {
        _uiState.update { it.copy(selectedCategory = category, dismissedSummary = false) }
        refreshPapers()
        refreshTrendSummary()
    }

    fun selectDays(days: Int) {
        _uiState.update { it.copy(selectedDays = days, dismissedSummary = false) }
        refreshPapers()
        refreshTrendSummary()
    }

    fun toggleSummaryExpanded() {
        _uiState.update { it.copy(summaryExpanded = !it.summaryExpanded) }
    }

    fun dismissSummary() {
        _uiState.update { it.copy(dismissedSummary = true) }
    }

    fun translatePaper(paper: PaperItem) {
        viewModelScope.launch {
            runCatching { repository.translatePaper(paper) }
                .onSuccess { translated ->
                    _uiState.update { state ->
                        state.copy(
                            papers = state.papers.map { if (it.id == translated.id) translated else it },
                            actionMessage = "摘要翻译已完成",
                            errorMessage = null,
                        )
                    }
                }
                .onFailure { error -> setError("翻译失败：${error.message ?: "未知错误"}") }
        }
    }

    fun toggleFavorite(paper: PaperItem) {
        viewModelScope.launch {
            runCatching {
                if (paper.favoriteState) {
                    repository.deleteFavorite(paper.id)
                    paper.copy(favoriteState = false)
                } else {
                    repository.saveFavorite(paper.copy(favoriteState = true))
                    paper.copy(favoriteState = true)
                }
            }.onSuccess { updated ->
                _uiState.update { state ->
                    state.copy(
                        papers = state.papers.map { if (it.id == updated.id) updated else it },
                        actionMessage = if (updated.favoriteState) "已加入收藏库" else "已取消收藏",
                        errorMessage = null,
                    )
                }
            }.onFailure { error -> setError("收藏操作失败：${error.message ?: "未知错误"}") }
        }
    }

    fun syncToZotero(paper: PaperItem) {
        viewModelScope.launch {
            runCatching { repository.syncPaperToZotero(paper) }
                .onSuccess { synced ->
                    _uiState.update { state ->
                        state.copy(
                            papers = state.papers.map { if (it.id == synced.id) synced else it },
                            actionMessage = "Zotero 同步状态：${synced.zoteroSyncState}",
                            errorMessage = null,
                        )
                    }
                }
                .onFailure { error -> setError("Zotero 同步失败：${error.message ?: "未知错误"}") }
        }
    }

    private fun refreshPapers() {
        viewModelScope.launch {
            val current = _uiState.value
            _uiState.update { it.copy(isLoading = true, errorMessage = null) }
            runCatching {
                repository.listHomePapers(
                    keyword = current.searchKeyword,
                    category = current.selectedCategory,
                    days = current.selectedDays,
                )
            }.onSuccess { papers ->
                _uiState.update { it.copy(papers = papers, isLoading = false) }
            }.onFailure { error ->
                _uiState.update { it.copy(isLoading = false) }
                setError("论文刷新失败：${error.message ?: "未知错误"}")
            }
        }
    }

    private fun refreshTrendSummary() {
        viewModelScope.launch {
            val current = _uiState.value
            _uiState.update { it.copy(isSummaryLoading = true) }
            runCatching { repository.getTrendSummary(current.selectedCategory, current.selectedDays) }
                .onSuccess { summary ->
                    _uiState.update { it.copy(trendSummary = summary, isSummaryLoading = false, errorMessage = null) }
                }
                .onFailure { error ->
                    _uiState.update { it.copy(isSummaryLoading = false) }
                    setError("趋势摘要加载失败：${error.message ?: "未知错误"}")
                }
        }
    }

    private fun setError(message: String) {
        _uiState.update { it.copy(errorMessage = message) }
    }
}
