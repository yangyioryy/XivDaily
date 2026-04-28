package com.xivdaily.app.ui.viewmodel

data class HomeUiState(
    val selectedCategory: String = "cs.CV",
    val selectedDays: Int = 3,
    val searchKeyword: String = "",
    val isLoading: Boolean = false,
)

