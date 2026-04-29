package com.xivdaily.app.ui.viewmodel

import com.xivdaily.app.data.datastore.UserPreferences
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.advanceTimeBy
import kotlinx.coroutines.test.advanceUntilIdle
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test

@OptIn(ExperimentalCoroutinesApi::class)
class HomeViewModelTest {
    @get:Rule
    val mainDispatcherRule = MainDispatcherRule()

    @Test
    fun initAndFilterChanges_refreshUsingPreferencesAndLatestSelection() {
        runTest {
            val repository = FakePaperRepository()
            val preferences = FakePreferencesRepository(
                UserPreferences(defaultCategory = "cs.AI", defaultDays = 7)
            )

            val viewModel = HomeViewModel(repository, preferences)
            advanceUntilIdle()

            assertEquals("cs.AI", viewModel.uiState.value.selectedCategory)
            assertEquals(7, viewModel.uiState.value.selectedDays)
            assertEquals(Triple(null, "cs.AI", 7), repository.listRequests.last())

            viewModel.selectCategory("cs.CL")
            viewModel.selectDays(30)
            advanceUntilIdle()

            assertEquals("cs.CL", viewModel.uiState.value.selectedCategory)
            assertEquals(30, viewModel.uiState.value.selectedDays)
            assertEquals(Triple(null, "cs.CL", 30), repository.listRequests.last())
        }
    }

    @Test
    fun dismissPaperFromFeed_onlyRemovesCurrentFeedCard() {
        runTest {
            val repository = FakePaperRepository().apply {
                homePapers += samplePaper().copy(favoriteState = true)
            }
            val preferences = FakePreferencesRepository()

            val viewModel = HomeViewModel(repository, preferences)
            advanceUntilIdle()
            val paper = viewModel.uiState.value.papers.single()

            viewModel.dismissPaperFromFeed(paper)
            advanceUntilIdle()

            assertTrue(viewModel.uiState.value.papers.isEmpty())
            assertTrue(repository.deletedFavoriteIds.isEmpty())
            assertEquals("已从当前流移出，收藏库保留不变", viewModel.uiState.value.actionMessage?.text)
        }
    }

    @Test
    fun toggleFavorite_actionMessageClearsAfterTimeout() {
        runTest {
            val repository = FakePaperRepository().apply {
                homePapers += samplePaper().copy(favoriteState = false)
            }
            val preferences = FakePreferencesRepository()

            val viewModel = HomeViewModel(repository, preferences)
            advanceUntilIdle()
            val paper = viewModel.uiState.value.papers.single()

            viewModel.toggleFavorite(paper)
            advanceUntilIdle()

            assertEquals("已加入收藏库", viewModel.uiState.value.actionMessage?.text)
            assertEquals(listOf(paper.id), repository.savedFavoriteIds)

            advanceTimeBy(2600L)
            runCurrent()

            assertNull(viewModel.uiState.value.actionMessage)
        }
    }
}
