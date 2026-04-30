package com.xivdaily.app.ui

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.platform.LocalContext
import androidx.lifecycle.viewmodel.compose.viewModel
import com.xivdaily.app.XivDailyApplication
import com.xivdaily.app.ui.navigation.AppNavGraph
import com.xivdaily.app.ui.navigation.viewModelFactory
import com.xivdaily.app.ui.theme.XivDailyTheme
import com.xivdaily.app.ui.viewmodel.SettingsViewModel

@Composable
fun AppRoot() {
    val app = LocalContext.current.applicationContext as XivDailyApplication
    val settingsViewModel: SettingsViewModel = viewModel(
        factory = viewModelFactory {
            SettingsViewModel(
                preferencesRepository = app.container.userPreferencesRepository,
                configRepository = app.container.paperRepository,
            )
        }
    )
    val settingsState by settingsViewModel.uiState.collectAsState()

    XivDailyTheme(themeMode = settingsState.themeMode) {
        Surface(color = MaterialTheme.colorScheme.background) {
            // 这里只预留首次引导分流入口，后续补 onboarding 页面时不需要再返工根导航。
            AppNavGraph(
                settingsViewModel = settingsViewModel,
                hasSeenOnboarding = settingsState.hasSeenOnboarding,
            )
        }
    }
}
