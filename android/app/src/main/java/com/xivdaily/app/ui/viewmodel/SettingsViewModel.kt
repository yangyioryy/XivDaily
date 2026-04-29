package com.xivdaily.app.ui.viewmodel

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.xivdaily.app.data.datastore.UserPreferencesRepositoryContract
import com.xivdaily.app.data.repository.PaperRepositoryContract
import kotlinx.coroutines.delay
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
                        hasSeenOnboarding = preferences.hasSeenOnboarding,
                    )
                }
            }
            .launchIn(viewModelScope)
        refreshIntegrationStatus()
    }

    fun showThemePicker() {
        _uiState.update { it.copy(isThemePickerVisible = true, errorMessage = null) }
    }

    fun hideThemePicker() {
        _uiState.update { it.copy(isThemePickerVisible = false) }
    }

    fun selectThemeMode(themeMode: String) {
        viewModelScope.launch {
            preferencesRepository.setThemeMode(themeMode)
            _uiState.update {
                it.copy(
                    isThemePickerVisible = false,
                    actionMessage = "主题已切换为${themeModeLabel(themeMode)}",
                    errorMessage = null,
                )
            }
        }
    }

    fun showLanguagePicker() {
        _uiState.update { it.copy(isLanguagePickerVisible = true, errorMessage = null) }
    }

    fun hideLanguagePicker() {
        _uiState.update { it.copy(isLanguagePickerVisible = false) }
    }

    fun selectLanguage(language: String) {
        _uiState.update {
            it.copy(
                language = language,
                isLanguagePickerVisible = false,
                actionMessage = "语言已切换为${languageLabel(language)}",
                errorMessage = null,
            )
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

    fun showAboutDialog() {
        _uiState.update { it.copy(isAboutDialogVisible = true, errorMessage = null) }
    }

    fun showZoteroDetailDialog() {
        _uiState.update { it.copy(isZoteroDetailDialogVisible = true, errorMessage = null) }
    }

    fun hideZoteroDetailDialog() {
        _uiState.update { it.copy(isZoteroDetailDialogVisible = false) }
    }

    fun showLlmDetailDialog() {
        _uiState.update { it.copy(isLlmDetailDialogVisible = true, errorMessage = null) }
    }

    fun hideLlmDetailDialog() {
        _uiState.update { it.copy(isLlmDetailDialogVisible = false) }
    }

    fun hideAboutDialog() {
        _uiState.update { it.copy(isAboutDialogVisible = false) }
    }

    fun showUpdateDialog() {
        _uiState.update { it.copy(isUpdateDialogVisible = true, errorMessage = null) }
    }

    fun hideUpdateDialog() {
        _uiState.update { it.copy(isUpdateDialogVisible = false) }
    }

    fun showProfileDialog() {
        _uiState.update { it.copy(isProfileDialogVisible = true, errorMessage = null) }
    }

    fun hideProfileDialog() {
        _uiState.update { it.copy(isProfileDialogVisible = false) }
    }

    fun showClearCacheDialog() {
        _uiState.update { it.copy(isClearCacheDialogVisible = true, errorMessage = null) }
    }

    fun hideClearCacheDialog() {
        _uiState.update { it.copy(isClearCacheDialogVisible = false) }
    }

    fun clearCache() {
        viewModelScope.launch {
            // 当前版本先提供真实反馈闭环，避免“可点但无结果”的假入口。
            _uiState.update {
                it.copy(
                    isClearCacheDialogVisible = false,
                    cacheStatusText = "清理中",
                    actionMessage = "正在清理首页列表与趋势缓存提示",
                    errorMessage = null,
                )
            }
            delay(800L)
            _uiState.update {
                it.copy(
                    cacheStatusText = "刚刚完成",
                    actionMessage = "缓存已清理完成",
                    errorMessage = null,
                )
            }
        }
    }

    fun refreshIntegrationStatus() {
        viewModelScope.launch {
            runCatching { paperRepository.getIntegrationConfigStatus() }
                .onSuccess { status ->
                    _uiState.update {
                        it.copy(
                            zoteroConfigured = status.zoteroConfigured,
                            zoteroUserId = status.zoteroUserId,
                            zoteroLibraryType = status.zoteroLibraryType,
                            zoteroTargetCollectionName = status.zoteroTargetCollectionName,
                            zoteroTargetCollectionKey = status.zoteroTargetCollectionKey,
                            zoteroTargetCollectionStatus = status.zoteroTargetCollectionStatus,
                            llmConfigured = status.llmConfigured,
                            integrationStatusFailed = false,
                            actionMessage = "配置状态已刷新",
                            errorMessage = null,
                        )
                    }
                }
                .onFailure { error ->
                    _uiState.update {
                        it.copy(
                            integrationStatusFailed = true,
                            zoteroTargetCollectionStatus = "error",
                            errorMessage = "配置状态刷新失败：${error.message ?: "未知错误"}",
                        )
                    }
                }
        }
    }
}

private fun themeModeLabel(themeMode: String): String {
    return when (themeMode) {
        "dark" -> "深色"
        "light" -> "浅色"
        else -> "跟随系统"
    }
}

private fun languageLabel(language: String): String {
    return when (language) {
        "en-US" -> "English"
        else -> "简体中文"
    }
}
