package com.xivdaily.app.ui.components

sealed class AppState<out T> {
    data object Loading : AppState<Nothing>()
    data class Success<T>(val data: T) : AppState<T>()
    data class Error(val message: String) : AppState<Nothing>()
}

