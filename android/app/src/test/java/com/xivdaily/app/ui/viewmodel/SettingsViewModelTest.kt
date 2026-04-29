package com.xivdaily.app.ui.viewmodel

import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.advanceUntilIdle
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

@OptIn(ExperimentalCoroutinesApi::class)
class SettingsViewModelTest {
    @Test
    fun toggleThemeAndPreferenceUpdates_arePersistedIntoUiState() {
        runTest {
            val preferences = FakePreferencesRepository()
            val viewModel = SettingsViewModel(preferences, FakePaperRepository())
            advanceUntilIdle()

            viewModel.toggleThemeMode()
            viewModel.updateDefaultCategory("cs.LG")
            viewModel.updateDefaultDays(30)
            advanceUntilIdle()

            assertEquals("light", viewModel.uiState.value.themeMode)
            assertEquals("cs.LG", viewModel.uiState.value.defaultCategory)
            assertEquals(30, viewModel.uiState.value.defaultDays)
            assertTrue(viewModel.uiState.value.llmConfigured)
            assertTrue(viewModel.uiState.value.zoteroConfigured)
        }
    }
}
