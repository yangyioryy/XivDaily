package com.xivdaily.app.ui.viewmodel

import com.xivdaily.app.data.datastore.UserPreferences
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.advanceUntilIdle
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Test

@OptIn(ExperimentalCoroutinesApi::class)
class HomeViewModelTest {
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
}
