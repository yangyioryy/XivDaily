package com.xivdaily.app.ui.viewmodel

data class SettingsUiState(
    val defaultCategory: String = "cs.CV",
    val defaultDays: Int = 3,
    val themeMode: String = "system",
    val zoteroConfigured: Boolean = false,
    val llmConfigured: Boolean = false,
    val actionMessage: String? = null,
    val errorMessage: String? = null,
)
