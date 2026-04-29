package com.xivdaily.app.ui.viewmodel

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.xivdaily.app.data.datastore.UserPreferencesRepositoryContract
import com.xivdaily.app.data.repository.PaperRepositoryContract
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.launchIn
import kotlinx.coroutines.flow.onEach
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

class SettingsViewModel(
    private val preferencesRepository: UserPreferencesRepositoryContract,
    private val paperRepository: PaperRepositoryContract,
) : ViewModel() {
    private val _uiState = MutableStateFlow(SettingsUiState())
    val uiState: StateFlow<SettingsUiState> = _uiState.asStateFlow()

    init {
        preferencesRepository.preferences
            .onEach { preferences ->
                _uiState.update {
                    it.copy(
                        defaultCategory = preferences.defaultCategory,
                        defaultDays = preferences.defaultDays,
                        themeMode = preferences.themeMode,
                        backendBaseUrl = preferences.backendBaseUrl,
                    )
                }
            }
            .launchIn(viewModelScope)
        refreshIntegrationStatus()
    }

    fun toggleThemeMode() {
        val next = when (_uiState.value.themeMode) {
            "system" -> "light"
            "light" -> "dark"
            else -> "system"
        }
        viewModelScope.launch {
            preferencesRepository.setThemeMode(next)
            _uiState.update { it.copy(actionMessage = "主题已切换到 $next", errorMessage = null) }
        }
    }

    fun updateDefaultCategory(category: String) {
        viewModelScope.launch {
            preferencesRepository.setDefaultCategory(category)
            _uiState.update { it.copy(actionMessage = "默认领域已更新", errorMessage = null) }
        }
    }

    fun updateDefaultDays(days: Int) {
        viewModelScope.launch {
            preferencesRepository.setDefaultDays(days)
            _uiState.update { it.copy(actionMessage = "默认时间窗已更新", errorMessage = null) }
        }
    }

    fun refreshIntegrationStatus() {
        viewModelScope.launch {
            runCatching { paperRepository.getIntegrationConfigStatus() }
                .onSuccess { status ->
                    _uiState.update {
                        it.copy(
                            zoteroConfigured = status.zoteroConfigured,
                            llmConfigured = status.llmConfigured,
                            actionMessage = "配置状态已刷新",
                            errorMessage = null,
                        )
                    }
                }
                .onFailure { error ->
                    _uiState.update { it.copy(errorMessage = "配置状态刷新失败：${error.message ?: "未知错误"}") }
                }
        }
    }
}
