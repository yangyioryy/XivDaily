package com.xivdaily.app.ui.viewmodel

import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.advanceTimeBy
import kotlinx.coroutines.test.advanceUntilIdle
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test

@OptIn(ExperimentalCoroutinesApi::class)
class SettingsViewModelTest {
    @get:Rule
    val mainDispatcherRule = MainDispatcherRule()

    @Test
    fun toggleThemeAndPreferenceUpdates_arePersistedIntoUiState() {
        runTest {
            val preferences = FakePreferencesRepository()
            val viewModel = SettingsViewModel(preferences, FakePaperRepository())
            advanceUntilIdle()

            viewModel.showThemePicker()
            viewModel.selectThemeMode("light")
            viewModel.updateDefaultCategory("cs.LG")
            viewModel.updateDefaultDays(30)
            advanceUntilIdle()

            assertEquals("light", viewModel.uiState.value.themeMode)
            assertEquals("cs.LG", viewModel.uiState.value.defaultCategory)
            assertEquals(30, viewModel.uiState.value.defaultDays)
            assertTrue(viewModel.uiState.value.llmConfigured)
            assertTrue(viewModel.uiState.value.zoteroConfigured)
            assertEquals("XivDaily", viewModel.uiState.value.zoteroTargetCollectionName)
            assertEquals("ready", viewModel.uiState.value.zoteroTargetCollectionStatus)
            assertTrue(!viewModel.uiState.value.hasSeenOnboarding)
        }
    }

    @Test
    fun localEntryDialogs_andCacheFeedback_updateUiState() {
        runTest {
            val viewModel = SettingsViewModel(FakePreferencesRepository(), FakePaperRepository())
            advanceUntilIdle()

            viewModel.showLanguagePicker()
            viewModel.selectLanguage("zh-CN")
            viewModel.showUpdateDialog()
            viewModel.showAboutDialog()
            viewModel.showProfileDialog()
            viewModel.showClearCacheDialog()

            assertTrue(viewModel.uiState.value.isUpdateDialogVisible)
            assertTrue(viewModel.uiState.value.isAboutDialogVisible)
            assertTrue(viewModel.uiState.value.isProfileDialogVisible)
            assertTrue(viewModel.uiState.value.isClearCacheDialogVisible)
            assertEquals("zh-CN", viewModel.uiState.value.language)

            viewModel.clearCache()
            advanceTimeBy(900L)
            runCurrent()

            assertEquals("刚刚完成", viewModel.uiState.value.cacheStatusText)
            assertEquals("缓存已清理完成", viewModel.uiState.value.actionMessage)
        }
    }

    @Test
    fun integrationDetailDialogs_followViewModelState() {
        runTest {
            val viewModel = SettingsViewModel(FakePreferencesRepository(), FakePaperRepository())
            advanceUntilIdle()

            viewModel.showZoteroDetailDialog()
            viewModel.showLlmDetailDialog()

            assertTrue(viewModel.uiState.value.isZoteroDetailDialogVisible)
            assertTrue(viewModel.uiState.value.isLlmDetailDialogVisible)
            assertEquals("COLL1234", viewModel.uiState.value.zoteroTargetCollectionKey)
        }
    }
}
