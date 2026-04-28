package com.xivdaily.app.ui.viewmodel

import androidx.lifecycle.ViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

class HomeViewModel : ViewModel() {
    private val _uiState = MutableStateFlow(HomeUiState())
    val uiState: StateFlow<HomeUiState> = _uiState.asStateFlow()

    fun updateKeyword(keyword: String) {
        // 首页搜索词会影响论文流刷新，后续这里会接入 Repository。
        _uiState.value = _uiState.value.copy(searchKeyword = keyword)
    }

    fun selectCategory(category: String) {
        // 分类切换需要同步刷新趋势摘要与论文流。
        _uiState.value = _uiState.value.copy(selectedCategory = category, dismissedSummary = false)
    }

    fun selectDays(days: Int) {
        // 时间窗变化是首页最核心的筛选动作。
        _uiState.value = _uiState.value.copy(selectedDays = days, dismissedSummary = false)
    }

    fun toggleSummaryExpanded() {
        _uiState.value = _uiState.value.copy(summaryExpanded = !_uiState.value.summaryExpanded)
    }

    fun dismissSummary() {
        _uiState.value = _uiState.value.copy(dismissedSummary = true)
    }
}

