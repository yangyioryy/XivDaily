package com.xivdaily.app.ui.navigation

import androidx.compose.foundation.layout.padding
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.navigation.NavDestination.Companion.hierarchy
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.rememberNavController
import com.xivdaily.app.R
import com.xivdaily.app.XivDailyApplication
import com.xivdaily.app.ui.screen.HomeScreen
import com.xivdaily.app.ui.screen.LibraryScreen
import com.xivdaily.app.ui.screen.SettingsScreen
import com.xivdaily.app.ui.viewmodel.HomeViewModel
import com.xivdaily.app.ui.viewmodel.LibraryViewModel
import com.xivdaily.app.ui.viewmodel.SettingsViewModel

private data class BottomTab(val route: String, val labelRes: Int)

@Composable
fun AppNavGraph(settingsViewModel: SettingsViewModel) {
    val app = LocalContext.current.applicationContext as XivDailyApplication
    val navController = rememberNavController()
    val tabs = listOf(
        BottomTab("home", R.string.tab_home),
        BottomTab("library", R.string.tab_library),
        BottomTab("settings", R.string.tab_settings),
    )
    val backStackEntry by navController.currentBackStackEntryAsState()
    val currentDestination = backStackEntry?.destination

    Scaffold(
        bottomBar = {
            NavigationBar {
                tabs.forEach { tab ->
                    val selected = currentDestination?.hierarchy?.any { it.route == tab.route } == true
                    NavigationBarItem(
                        selected = selected,
                        onClick = {
                            navController.navigate(tab.route) {
                                launchSingleTop = true
                                restoreState = true
                                popUpTo(navController.graph.startDestinationId) {
                                    saveState = true
                                }
                            }
                        },
                        label = { Text(text = stringResource(tab.labelRes)) },
                        icon = {},
                    )
                }
            }
        }
    ) { paddingValues ->
        NavHost(
            navController = navController,
            startDestination = "home",
            modifier = Modifier.padding(paddingValues),
        ) {
            composable("home") {
                val homeViewModel: HomeViewModel = viewModel(
                    factory = viewModelFactory {
                        HomeViewModel(
                            repository = app.container.paperRepository,
                            preferencesRepository = app.container.userPreferencesRepository,
                        )
                    }
                )
                val uiState by homeViewModel.uiState.collectAsState()
                HomeScreen(
                    uiState = uiState,
                    onKeywordChange = homeViewModel::updateKeyword,
                    onCategorySelect = homeViewModel::selectCategory,
                    onDaysSelect = homeViewModel::selectDays,
                    onTranslate = homeViewModel::translatePaper,
                    onFavorite = homeViewModel::toggleFavorite,
                    onSyncToZotero = homeViewModel::syncToZotero,
                    onToggleSummary = homeViewModel::toggleSummaryExpanded,
                    onDismissSummary = homeViewModel::dismissSummary,
                )
            }
            composable("library") {
                val libraryViewModel: LibraryViewModel = viewModel(
                    factory = viewModelFactory { LibraryViewModel(app.container.paperRepository) }
                )
                val uiState by libraryViewModel.uiState.collectAsState()
                LibraryScreen(
                    uiState = uiState,
                    onToggleSelection = libraryViewModel::togglePaperSelection,
                    onChangeSyncFilter = libraryViewModel::changeSyncFilter,
                    onDeleteFavorite = libraryViewModel::deleteFavorite,
                    onDeleteSelected = libraryViewModel::deleteSelectedFavorites,
                    onSyncFavorite = libraryViewModel::syncFavoriteToZotero,
                    onExportSelected = libraryViewModel::exportSelectedBibtex,
                )
            }
            composable("settings") {
                val uiState by settingsViewModel.uiState.collectAsState()
                SettingsScreen(
                    uiState = uiState,
                    onToggleTheme = settingsViewModel::toggleThemeMode,
                    onUpdateDefaultCategory = settingsViewModel::updateDefaultCategory,
                    onUpdateDefaultDays = settingsViewModel::updateDefaultDays,
                    onRefreshConfigStatus = settingsViewModel::refreshIntegrationStatus,
                )
            }
        }
    }
}

fun <T : ViewModel> viewModelFactory(create: () -> T): ViewModelProvider.Factory {
    return object : ViewModelProvider.Factory {
        @Suppress("UNCHECKED_CAST")
        override fun <VM : ViewModel> create(modelClass: Class<VM>): VM = create() as VM
    }
}
