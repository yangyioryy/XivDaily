package com.xivdaily.app.ui.viewmodel

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.xivdaily.app.data.datastore.UserPreferencesRepositoryContract
import com.xivdaily.app.data.model.PaperItem
import com.xivdaily.app.data.repository.HomePaperRepositoryContract
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.launchIn
import kotlinx.coroutines.flow.onEach
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

class HomeViewModel(
    private val repository: HomePaperRepositoryContract,
    private val preferencesRepository: UserPreferencesRepositoryContract,
) : ViewModel() {
    private val _uiState = MutableStateFlow(HomeUiState())
    val uiState: StateFlow<HomeUiState> = _uiState.asStateFlow()
    private var nextActionMessageId = 0L
    private var actionMessageJob: Job? = null

    init {
        preferencesRepository.preferences
            .onEach { preferences ->
                _uiState.update {
                    val availableTags = it.categories + preferences.customTags
                    val preferredCategory = preferences.defaultCategory.takeIf { category -> category in availableTags }
                        ?: it.categories.firstOrNull()
                        ?: "cs.CV"
                    val nextCategory = if (it.selectedCategory in preferences.customTags) {
                        it.selectedCategory
                    } else {
                        preferredCategory
                    }
                    it.copy(
                        selectedCategory = nextCategory,
                        customTags = preferences.customTags,
                        selectedDays = preferences.defaultDays,
                    )
                }
                refreshPapers()
                refreshTrendSummary()
            }
            .launchIn(viewModelScope)
    }

    fun updateKeyword(keyword: String) {
        _uiState.update { it.copy(searchKeywordDraft = keyword) }
    }

    fun submitKeyword() {
        _uiState.update { it.copy(searchKeyword = it.searchKeywordDraft.trim()) }
        refreshPapers()
    }

    fun exitSearch() {
        _uiState.update { it.copy(searchKeyword = "", searchKeywordDraft = "") }
        refreshPapers()
    }

    fun selectCategory(category: String) {
        _uiState.update { it.copy(selectedCategory = category, tagPendingDeletion = null, dismissedSummary = false) }
        refreshPapers()
        refreshTrendSummary()
    }

    fun showAddTagDialog() {
        _uiState.update { it.copy(isAddTagDialogVisible = true, customTagDraft = "", tagPendingDeletion = null) }
    }

    fun hideAddTagDialog() {
        _uiState.update { it.copy(isAddTagDialogVisible = false, customTagDraft = "") }
    }

    fun updateCustomTagDraft(value: String) {
        _uiState.update { it.copy(customTagDraft = value) }
    }

    fun addCustomTag() {
        val normalizedTag = normalizeCustomTag(_uiState.value.customTagDraft)
        if (normalizedTag.isBlank()) {
            showActionMessage("请输入标签名称")
            return
        }
        val current = _uiState.value
        if (normalizedTag in current.categories || normalizedTag in current.customTags) {
            showActionMessage("标签已存在")
            return
        }
        viewModelScope.launch {
            val nextTags = current.customTags + normalizedTag
            preferencesRepository.setCustomTags(nextTags)
            _uiState.update {
                it.copy(
                    customTags = nextTags,
                    selectedCategory = normalizedTag,
                    isAddTagDialogVisible = false,
                    customTagDraft = "",
                    tagPendingDeletion = null,
                )
            }
            refreshPapers()
            refreshTrendSummary()
            showActionMessage("已添加标签：$normalizedTag")
        }
    }

    fun markTagPendingDeletion(tag: String) {
        if (tag !in _uiState.value.customTags) {
            return
        }
        _uiState.update { it.copy(tagPendingDeletion = tag) }
    }

    fun clearTagPendingDeletion() {
        _uiState.update { it.copy(tagPendingDeletion = null) }
    }

    fun deleteCustomTag(tag: String) {
        if (tag !in _uiState.value.customTags) {
            return
        }
        viewModelScope.launch {
            val state = _uiState.value
            val nextTags = state.customTags - tag
            val fallbackCategory = state.categories.firstOrNull() ?: "cs.CV"
            preferencesRepository.setCustomTags(nextTags)
            _uiState.update {
                it.copy(
                    customTags = nextTags,
                    selectedCategory = if (state.selectedCategory == tag) fallbackCategory else state.selectedCategory,
                    tagPendingDeletion = null,
                )
            }
            refreshPapers()
            refreshTrendSummary()
            showActionMessage("已删除标签：$tag")
        }
    }

    fun selectDays(days: Int) {
        _uiState.update { it.copy(selectedDays = days) }
        if (!_uiState.value.isSearchActive) {
            refreshPapers()
        }
    }

    fun refreshFeed() {
        refreshPapers()
        refreshTrendSummary()
    }

    fun toggleSummaryExpanded() {
        _uiState.update { it.copy(summaryExpanded = !it.summaryExpanded) }
    }

    fun togglePaperAbstract(paperId: String) {
        _uiState.update { state ->
            val nextExpanded = if (paperId in state.expandedAbstractPaperIds) {
                state.expandedAbstractPaperIds - paperId
            } else {
                state.expandedAbstractPaperIds + paperId
            }
            state.copy(expandedAbstractPaperIds = nextExpanded)
        }
    }

    fun dismissSummary() {
        _uiState.update { it.copy(dismissedSummary = true) }
    }

    fun dismissPaperFromFeed(paper: PaperItem) {
        // 左滑只影响首页当前流，不触碰收藏库实体，避免误删用户已收藏论文。
        _uiState.update { state ->
            state.copy(
                papers = state.papers.filterNot { it.id == paper.id },
                errorMessage = null,
            )
        }
        val message = if (paper.favoriteState) {
            "已忽视，收藏库保留不变"
        } else {
            "已忽视"
        }
        showActionMessage(message)
    }

    fun translatePaper(paper: PaperItem) {
        if (paper.id !in _uiState.value.expandedAbstractPaperIds) {
            showActionMessage("请先展开摘要")
            return
        }
        if (!paper.translatedSummary.isNullOrBlank()) {
            showActionMessage("已显示中文翻译")
            return
        }
        if (paper.id in _uiState.value.translatingPaperIds) {
            return
        }
        viewModelScope.launch {
            _uiState.update {
                it.copy(
                    translatingPaperIds = it.translatingPaperIds + paper.id,
                    translationErrors = it.translationErrors - paper.id,
                )
            }
            runCatching { repository.translatePaper(paper) }
                .onSuccess { translated ->
                    _uiState.update { state ->
                        state.copy(
                            papers = state.papers.map { if (it.id == translated.id) translated else it },
                            translatingPaperIds = state.translatingPaperIds - paper.id,
                            errorMessage = null,
                        )
                    }
                    showActionMessage("摘要翻译已完成")
                }
                .onFailure { error ->
                    val message = mapUserFriendlyError("摘要翻译暂时不可用", error)
                    _uiState.update {
                        it.copy(
                            translatingPaperIds = it.translatingPaperIds - paper.id,
                            translationErrors = it.translationErrors + (paper.id to message),
                        )
                    }
                }
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
                        errorMessage = null,
                    )
                }
                showActionMessage(if (updated.favoriteState) "已收藏" else "已取消收藏")
            }.onFailure { error -> setError(mapUserFriendlyError("收藏操作暂时失败", error)) }
        }
    }

    fun syncToZotero(paper: PaperItem) {
        if (paper.zoteroSyncState == "synced") {
            showActionMessage("这篇论文已经同步到 Zotero")
            return
        }
        viewModelScope.launch {
            runCatching { repository.syncPaperToZotero(paper) }
                .onSuccess { synced ->
                    _uiState.update { state ->
                        state.copy(
                            papers = state.papers.map { if (it.id == synced.id) synced else it },
                            errorMessage = null,
                        )
                    }
                    showActionMessage(
                        if (synced.zoteroSyncState == "synced") {
                            "已同步到 Zotero"
                        } else {
                            "Zotero 同步暂未完成"
                        }
                    )
                }
                .onFailure { error -> setError(mapUserFriendlyError("Zotero 同步暂时失败", error)) }
        }
    }

    private fun refreshPapers() {
        viewModelScope.launch {
            val current = _uiState.value
            _uiState.update { it.copy(isLoading = true, errorMessage = null) }
            runCatching {
                // 自定义标签保留 chip 里的短横线写法，但查询时转成空格，更贴近 arXiv 关键词搜索。
                val keyword = current.searchKeyword
                    .takeIf { it.isNotBlank() }
                    ?: current.selectedCategory.takeIf { current.isCustomTag(it) }?.toCustomTagSearchKeyword()
                val category = current.selectedCategory.takeUnless { current.isCustomTag(it) }
                // 有关键词时后端按全 arXiv 搜索处理，时间窗只服务无关键词首页流。
                val days = if (keyword == null) current.selectedDays else null
                repository.listHomePapers(
                    keyword = keyword,
                    category = category,
                    days = days,
                )
            }.onSuccess { result ->
                _uiState.update {
                    it.copy(
                        papers = result.items,
                        listStatus = result.status,
                        listWarning = result.warning,
                        emptyReason = result.emptyReason,
                        isLoading = false,
                    )
                }
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
            val summaryCategory = current.selectedCategory.takeUnless { current.isCustomTag(it) }
            runCatching { repository.getTrendSummary(summaryCategory) }
                .onSuccess { summary ->
                    _uiState.update {
                        it.copy(
                            trendSummary = summary,
                            trendErrorMessage = null,
                            isSummaryLoading = false,
                        )
                    }
                }
                .onFailure { error ->
                    _uiState.update {
                        it.copy(
                            isSummaryLoading = false,
                            trendErrorMessage = mapUserFriendlyError("趋势摘要暂时不可用", error),
                        )
                    }
                }
        }
    }

    private fun setError(message: String) {
        _uiState.update { it.copy(errorMessage = message) }
    }

    private fun showActionMessage(message: String) {
        // 用唯一 id 保护超时清理，避免旧协程把新提示提前清掉。
        val messageId = ++nextActionMessageId
        actionMessageJob?.cancel()
        _uiState.update { it.copy(actionMessage = HomeActionMessage(messageId, message), errorMessage = null) }
        actionMessageJob = viewModelScope.launch {
            delay(ACTION_MESSAGE_TIMEOUT_MS)
            _uiState.update { state ->
                if (state.actionMessage?.id == messageId) {
                    state.copy(actionMessage = null)
                } else {
                    state
                }
            }
        }
    }

    private companion object {
        const val ACTION_MESSAGE_TIMEOUT_MS = 2500L
    }
}

private fun normalizeCustomTag(value: String): String {
    return value.trim().replace(Regex("\\s+"), "-").lowercase()
}

private fun String.toCustomTagSearchKeyword(): String {
    return replace(Regex("[-_]+"), " ").replace(Regex("\\s+"), " ").trim()
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
