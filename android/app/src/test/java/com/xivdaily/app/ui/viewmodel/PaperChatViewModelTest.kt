package com.xivdaily.app.ui.viewmodel

import com.xivdaily.app.data.model.FavoritePaperItem
import com.xivdaily.app.data.model.PaperChatResult
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.flowOf
import kotlinx.coroutines.test.advanceUntilIdle
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test

@OptIn(ExperimentalCoroutinesApi::class)
class PaperChatViewModelTest {
    @get:Rule
    val mainDispatcherRule = MainDispatcherRule()

    @Test
    fun sendMessage_usesSelectedFavoritePapers() {
        runTest {
            val favorites = listOf(FavoritePaperItem(samplePaper(), "2026-04-29T10:00:00Z"))
            val repository = FakePaperRepository(flowOf(favorites))
            val viewModel = PaperChatViewModel(repository)
            advanceUntilIdle()

            viewModel.togglePaperSelection("2401.00001")
            viewModel.updateInput("核心贡献是什么？")
            viewModel.sendMessage()
            advanceUntilIdle()

            assertEquals(listOf("2401.00001"), repository.paperChatRequests.single().first)
            assertEquals("user", repository.paperChatRequests.single().second.single().role)
            assertEquals("chat answer", viewModel.uiState.value.messages.last().content)
            assertEquals("full_text", viewModel.uiState.value.usedPapers.single().status)
        }
    }

    @Test
    fun sendMessage_keepsSendingStateUntilResponseCompletes() {
        runTest {
            val favorites = listOf(FavoritePaperItem(samplePaper(), "2026-04-29T10:00:00Z"))
            val repository = FakePaperRepository(flowOf(favorites))
            val deferred = CompletableDeferred<PaperChatResult>()
            repository.paperChatDeferred = deferred
            val viewModel = PaperChatViewModel(repository)
            advanceUntilIdle()

            viewModel.togglePaperSelection("2401.00001")
            viewModel.updateInput("请总结贡献")
            viewModel.sendMessage()
            runCurrent()

            assertTrue(viewModel.uiState.value.isSending)
            assertEquals("user", viewModel.uiState.value.messages.single().role)

            deferred.complete(repository.paperChatResult)
            advanceUntilIdle()

            assertFalse(viewModel.uiState.value.isSending)
            assertEquals("chat answer", viewModel.uiState.value.messages.last().content)
        }
    }

    @Test
    fun sendMessage_failureClearsSendingStateAndKeepsUserMessage() {
        runTest {
            val favorites = listOf(FavoritePaperItem(samplePaper(), "2026-04-29T10:00:00Z"))
            val repository = FakePaperRepository(flowOf(favorites))
            repository.paperChatError = RuntimeException("timeout")
            val viewModel = PaperChatViewModel(repository)
            advanceUntilIdle()

            viewModel.togglePaperSelection("2401.00001")
            viewModel.updateInput("请总结贡献")
            viewModel.sendMessage()
            advanceUntilIdle()

            assertFalse(viewModel.uiState.value.isSending)
            assertEquals("user", viewModel.uiState.value.messages.single().role)
            assertEquals("论文对话请求超时，请稍后重试。", viewModel.uiState.value.errorMessage)
        }
    }

    @Test
    fun sendMessage_requiresSelectedPaper() {
        runTest {
            val viewModel = PaperChatViewModel(FakePaperRepository())
            advanceUntilIdle()

            viewModel.updateInput("总结一下")
            viewModel.sendMessage()

            assertEquals("请先选择至少一篇收藏论文", viewModel.uiState.value.errorMessage)
        }
    }

    @Test
    fun initialPaperId_preselectsFavoriteFromLibraryNavigation() {
        runTest {
            val favorites = listOf(
                FavoritePaperItem(samplePaper("2401.00001"), "2026-04-29T10:00:00Z"),
                FavoritePaperItem(samplePaper("2401.00002"), "2026-04-29T10:00:00Z"),
            )
            val viewModel = PaperChatViewModel(
                repository = FakePaperRepository(flowOf(favorites)),
                initialPaperId = "2401.00002",
            )
            advanceUntilIdle()

            assertEquals(setOf("2401.00002"), viewModel.uiState.value.selectedPaperIds)
        }
    }

    @Test
    fun togglePaperSelection_limitsSelectedPapers() {
        runTest {
            val favorites = (1..4).map { index ->
                FavoritePaperItem(samplePaper("2401.0000$index"), "2026-04-29T10:00:00Z")
            }
            val viewModel = PaperChatViewModel(FakePaperRepository(flowOf(favorites)))
            advanceUntilIdle()

            favorites.forEach { viewModel.togglePaperSelection(it.paper.id) }

            assertEquals(3, viewModel.uiState.value.selectedPaperIds.size)
            assertTrue(viewModel.uiState.value.errorMessage!!.contains("最多选择"))
        }
    }
}
