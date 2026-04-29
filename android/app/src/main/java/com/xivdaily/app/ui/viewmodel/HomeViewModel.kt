package com.xivdaily.app.ui.viewmodel

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.xivdaily.app.data.datastore.UserPreferencesRepositoryContract
import com.xivdaily.app.data.model.PaperItem
import com.xivdaily.app.data.repository.PaperRepositoryContract
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.launchIn
import kotlinx.coroutines.flow.onEach
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

class HomeViewModel(
    private val repository: PaperRepositoryContract,
    private val preferencesRepository: UserPreferencesRepositoryContract,
) : ViewModel() {
    private val _uiState = MutableStateFlow(HomeUiState())
    val uiState: StateFlow<HomeUiState> = _uiState.asStateFlow()

    init {
        preferencesRepository.preferences
            .onEach { preferences ->
                _uiState.update {
                    it.copy(
                        selectedCategory = preferences.defaultCategory,
                        selectedDays = preferences.defaultDays,
                    )
                }
                refreshPapers()
                refreshTrendSummary()
            }
            .launchIn(viewModelScope)
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
                .onFailure { error -> setError(mapUserFriendlyError("摘要翻译暂时不可用", error)) }
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
            }.onFailure { error -> setError(mapUserFriendlyError("收藏操作暂时失败", error)) }
        }
    }

    fun syncToZotero(paper: PaperItem) {
        viewModelScope.launch {
            runCatching { repository.syncPaperToZotero(paper) }
                .onSuccess { synced ->
                    _uiState.update { state ->
                        state.copy(
                            papers = state.papers.map { if (it.id == synced.id) synced else it },
                            actionMessage = if (synced.zoteroSyncState == "synced") "已同步到 Zotero" else "Zotero 同步暂未完成",
                            errorMessage = null,
                        )
                    }
                }
                .onFailure { error -> setError(mapUserFriendlyError("Zotero 同步暂时失败", error)) }
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
                setError(mapUserFriendlyError("论文列表暂时无法刷新", error))
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
                    setError(mapUserFriendlyError("趋势摘要暂时不可用", error))
                }
        }
    }

    private fun setError(message: String) {
        _uiState.update { it.copy(errorMessage = message) }
    }
}

private fun mapUserFriendlyError(prefix: String, error: Throwable): String {
    val detail = error.message.orEmpty()
    return when {
        detail.contains("timeout", ignoreCase = true) -> "$prefix，请稍后重试。"
        detail.contains("Unable to resolve host", ignoreCase = true) -> "$prefix，请检查当前网络连接。"
        detail.contains("Failed to connect", ignoreCase = true) ||
            detail.contains("Connection refused", ignoreCase = true) -> "$prefix，请确认本地服务已经启动。"
        else -> "$prefix，请稍后再试。"
    }
}
