package com.xivdaily.app.ui.viewmodel

import androidx.lifecycle.ViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

class SettingsViewModel : ViewModel() {
    private val _uiState = MutableStateFlow(SettingsUiState())
    val uiState: StateFlow<SettingsUiState> = _uiState.asStateFlow()

    fun toggleThemeMode() {
        val next = when (_uiState.value.themeMode) {
            "system" -> "light"
            "light" -> "dark"
            else -> "system"
        }
        _uiState.value = _uiState.value.copy(themeMode = next)
    }

    fun updateDefaultCategory(category: String) {
        _uiState.value = _uiState.value.copy(defaultCategory = category)
    }

    fun updateDefaultDays(days: Int) {
        _uiState.value = _uiState.value.copy(defaultDays = days)
    }

    fun toggleZoteroConfigured() {
        _uiState.value = _uiState.value.copy(zoteroConfigured = !_uiState.value.zoteroConfigured)
    }

    fun toggleLlmConfigured() {
        _uiState.value = _uiState.value.copy(llmConfigured = !_uiState.value.llmConfigured)
    }
}

