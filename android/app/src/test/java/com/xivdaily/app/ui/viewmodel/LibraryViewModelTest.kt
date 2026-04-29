package com.xivdaily.app.ui.viewmodel

import com.xivdaily.app.data.model.FavoritePaperItem
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.flowOf
import kotlinx.coroutines.test.advanceUntilIdle
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertFalse
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test

@OptIn(ExperimentalCoroutinesApi::class)
class LibraryViewModelTest {
    @get:Rule
    val mainDispatcherRule = MainDispatcherRule()

    @Test
    fun toggleSelection_enablesAndClearsBatchMode() {
        runTest {
            val favorites = listOf(FavoritePaperItem(samplePaper(), "2026-04-29T10:00:00Z"))
            val viewModel = LibraryViewModel(FakePaperRepository(flowOf(favorites)))
            advanceUntilIdle()

            viewModel.togglePaperSelection("2401.00001")
            assertTrue(viewModel.uiState.value.isBatchMode)
            assertTrue("2401.00001" in viewModel.uiState.value.selectedPaperIds)

            viewModel.togglePaperSelection("2401.00001")
            assertFalse(viewModel.uiState.value.isBatchMode)
            assertTrue(viewModel.uiState.value.selectedPaperIds.isEmpty())
        }
    }

    @Test
    fun syncFavoriteToZotero_skipsAlreadySyncedPaper() {
        runTest {
            val favorites = listOf(
                FavoritePaperItem(samplePaper().copy(zoteroSyncState = "synced"), "2026-04-29T10:00:00Z")
            )
            val repository = FakePaperRepository(flowOf(favorites))
            val viewModel = LibraryViewModel(repository)
            advanceUntilIdle()

            viewModel.syncFavoriteToZotero("2401.00001")
            advanceUntilIdle()

            assertEquals("这篇论文已经同步到 Zotero", viewModel.uiState.value.actionMessage)
        }
    }
}
