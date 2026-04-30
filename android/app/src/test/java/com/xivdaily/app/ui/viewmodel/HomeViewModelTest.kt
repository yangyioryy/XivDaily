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
            assertEquals("cs.AI", repository.trendRequests.last())
            assertEquals(Triple(null, "cs.AI", 7), repository.listRequests.last())

            viewModel.selectCategory("cs.CL")
            viewModel.selectDays(30)
            advanceUntilIdle()

            assertEquals("cs.CL", viewModel.uiState.value.selectedCategory)
            assertEquals(30, viewModel.uiState.value.selectedDays)
            assertEquals(listOf("cs.AI", "cs.CL"), repository.trendRequests)
            assertEquals(Triple(null, "cs.CL", 30), repository.listRequests.last())
        }
    }

    @Test
    fun updateKeyword_onlyRefreshesAfterSubmit() {
        runTest {
            val repository = FakePaperRepository()
            val preferences = FakePreferencesRepository()

            val viewModel = HomeViewModel(repository, preferences)
            advanceUntilIdle()
            repository.listRequests.clear()

            viewModel.updateKeyword("diffusion")
            advanceUntilIdle()

            assertEquals("diffusion", viewModel.uiState.value.searchKeywordDraft)
            assertEquals("", viewModel.uiState.value.searchKeyword)
            assertTrue(repository.listRequests.isEmpty())

            viewModel.submitKeyword()
            advanceUntilIdle()

            assertEquals("diffusion", viewModel.uiState.value.searchKeyword)
            assertTrue(viewModel.uiState.value.isSearchActive)
            assertEquals(Triple("diffusion", "cs.CV", null), repository.listRequests.last())
        }
    }

    @Test
    fun selectDays_doesNotRefreshWhenKeywordSearchIsActive() {
        runTest {
            val repository = FakePaperRepository()
            val preferences = FakePreferencesRepository()

            val viewModel = HomeViewModel(repository, preferences)
            advanceUntilIdle()
            viewModel.updateKeyword("omibench")
            viewModel.submitKeyword()
            advanceUntilIdle()
            repository.listRequests.clear()

            viewModel.selectDays(30)
            advanceUntilIdle()

            assertEquals(30, viewModel.uiState.value.selectedDays)
            assertTrue(repository.listRequests.isEmpty())
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
            runCurrent()

            assertTrue(viewModel.uiState.value.papers.isEmpty())
            assertTrue(repository.deletedFavoriteIds.isEmpty())
            assertEquals("已忽视，收藏库保留不变", viewModel.uiState.value.actionMessage?.text)
        }
    }

    @Test
    fun emptyListFromTimeWindow_exposesWarningAndReason() {
        runTest {
            val repository = FakePaperRepository().apply {
                homePaperStatus = "empty"
                homePaperWarning = "当前 3 天时间窗内暂无结果，可以尝试切换到 7 天或 30 天。"
                homePaperEmptyReason = "time_window_filtered"
            }
            val preferences = FakePreferencesRepository(
                UserPreferences(defaultCategory = "cs.AI", defaultDays = 3)
            )

            val viewModel = HomeViewModel(repository, preferences)
            advanceUntilIdle()

            assertTrue(viewModel.uiState.value.papers.isEmpty())
            assertEquals("empty", viewModel.uiState.value.listStatus)
            assertEquals("time_window_filtered", viewModel.uiState.value.emptyReason)
            assertEquals(
                "当前 3 天时间窗内暂无结果，可以尝试切换到 7 天或 30 天。",
                viewModel.uiState.value.listWarning,
            )
        }
    }

    @Test
    fun trendSummaryFailure_staysInsideTrendStateAndKeepsPaperListVisible() {
        runTest {
            val repository = FakePaperRepository().apply {
                homePapers += samplePaper()
                trendError = IllegalStateException("context length exceeded")
            }
            val preferences = FakePreferencesRepository()

            val viewModel = HomeViewModel(repository, preferences)
            advanceUntilIdle()

            assertEquals(1, viewModel.uiState.value.papers.size)
            assertNull(viewModel.uiState.value.errorMessage)
            assertEquals(
                "趋势摘要暂时不可用，请稍后再试。",
                viewModel.uiState.value.trendErrorMessage,
            )
        }
    }

    @Test
    fun translatePaper_tracksPerPaperStateAndSkipsAlreadyTranslatedPaper() {
        runTest {
            val repository = FakePaperRepository().apply {
                homePapers += samplePaper()
            }
            val viewModel = HomeViewModel(repository, FakePreferencesRepository())
            advanceUntilIdle()
            val paper = viewModel.uiState.value.papers.single()

            viewModel.translatePaper(paper)
            advanceUntilIdle()

            val translated = viewModel.uiState.value.papers.single()
            assertEquals("translated", translated.translatedSummary)
            assertTrue(viewModel.uiState.value.translatingPaperIds.isEmpty())
            assertEquals(listOf(paper.id), repository.translationRequests)

            viewModel.translatePaper(translated)
            advanceUntilIdle()

            assertEquals(listOf(paper.id), repository.translationRequests)
            assertEquals("已显示中文翻译", viewModel.uiState.value.actionMessage?.text)
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
            runCurrent()

            assertEquals("已收藏", viewModel.uiState.value.actionMessage?.text)
            assertEquals(listOf(paper.id), repository.savedFavoriteIds)

            advanceTimeBy(2600L)
            runCurrent()

            assertNull(viewModel.uiState.value.actionMessage)
        }
    }
}
