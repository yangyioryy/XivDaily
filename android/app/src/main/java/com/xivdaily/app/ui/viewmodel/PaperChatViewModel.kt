package com.xivdaily.app.ui.viewmodel

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.xivdaily.app.data.model.PaperChatMessage
import com.xivdaily.app.data.repository.PaperChatRepositoryContract
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.launchIn
import kotlinx.coroutines.flow.onEach
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

class PaperChatViewModel(
    private val repository: PaperChatRepositoryContract,
    private val initialPaperId: String? = null,
) : ViewModel() {
    private val _uiState = MutableStateFlow(PaperChatUiState())
    val uiState: StateFlow<PaperChatUiState> = _uiState.asStateFlow()
    private var pendingInitialPaperId = initialPaperId

    init {
        repository.observeFavorites()
            .onEach { favorites ->
                _uiState.update { state ->
                    val availableIds = favorites.map { it.paper.id }.toSet()
                    val retainedSelection = state.selectedPaperIds.intersect(availableIds)
                    val preselectedId = pendingInitialPaperId
                        ?.takeIf { retainedSelection.isEmpty() && it in availableIds }
                    if (preselectedId != null) {
                        pendingInitialPaperId = null
                    }
                    val initialSelection = preselectedId?.let { setOf(it) } ?: retainedSelection
                    state.copy(
                        favorites = favorites,
                        selectedPaperIds = initialSelection,
                    )
                }
            }
            .launchIn(viewModelScope)
    }

    fun togglePaperSelection(paperId: String) {
        _uiState.update { state ->
            val current = state.selectedPaperIds
            val next = if (paperId in current) {
                current - paperId
            } else {
                if (current.size >= MAX_SELECTED_PAPERS) {
                    return@update state.copy(errorMessage = "一次最多选择 $MAX_SELECTED_PAPERS 篇论文")
                }
                current + paperId
            }
            state.copy(selectedPaperIds = next, errorMessage = null)
        }
    }

    fun updateInput(value: String) {
        _uiState.update { it.copy(inputDraft = value, errorMessage = null) }
    }

    fun sendMessage() {
        val state = _uiState.value
        val question = state.inputDraft.trim()
        val selectedPapers = state.selectedPapers.map { it.paper }
        when {
            selectedPapers.isEmpty() -> {
                setError("请先选择至少一篇收藏论文")
                return
            }
            question.isBlank() -> {
                setError("请输入要询问的问题")
                return
            }
        }

        val nextMessages = state.messages + PaperChatMessage(role = "user", content = question)
        _uiState.update {
            it.copy(
                messages = nextMessages,
                inputDraft = "",
                isSending = true,
                errorMessage = null,
                warningMessage = null,
            )
        }

        viewModelScope.launch {
            runCatching {
                // Android 只上传收藏论文元数据，全文 PDF 下载和抽取统一交给后端安全处理。
                repository.chatWithPapers(selectedPapers, nextMessages)
            }.onSuccess { result ->
                _uiState.update {
                    it.copy(
                        messages = nextMessages + PaperChatMessage(role = "assistant", content = result.answer),
                        isSending = false,
                        usedPapers = result.usedPapers,
                        warningMessage = result.warning.takeIf { warning -> result.status == "degraded" || !warning.isNullOrBlank() },
                    )
                }
            }.onFailure { error ->
                _uiState.update {
                    it.copy(
                        isSending = false,
                        errorMessage = mapPaperChatError(error),
                    )
                }
            }
        }
    }

    fun clearConversation() {
        _uiState.update {
            it.copy(messages = emptyList(), warningMessage = null, errorMessage = null, usedPapers = emptyList())
        }
    }

    private fun setError(message: String) {
        _uiState.update { it.copy(errorMessage = message) }
    }

    private companion object {
        const val MAX_SELECTED_PAPERS = 3
    }
}

private fun mapPaperChatError(error: Throwable): String {
    val detail = error.message.orEmpty()
    return when {
        detail.contains("timeout", ignoreCase = true) -> "论文对话请求超时，请稍后重试。"
        detail.contains("Unable to resolve host", ignoreCase = true) -> "论文对话失败，请检查网络连接。"
        detail.contains("Failed to connect", ignoreCase = true) ||
            detail.contains("Connection refused", ignoreCase = true) -> "论文对话失败，请确认后端服务已经启动。"
        else -> "论文对话暂时失败，请稍后再试。"
    }
}
