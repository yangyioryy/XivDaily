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
}

