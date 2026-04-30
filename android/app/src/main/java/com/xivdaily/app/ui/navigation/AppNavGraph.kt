package com.xivdaily.app.ui.navigation

import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.AutoAwesome
import androidx.compose.material.icons.rounded.Bookmarks
import androidx.compose.material.icons.rounded.Tune
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.NavigationBarItemDefaults
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
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
import com.xivdaily.app.ui.theme.xivSpacing
import com.xivdaily.app.ui.viewmodel.HomeViewModel
import com.xivdaily.app.ui.viewmodel.LibraryViewModel
import com.xivdaily.app.ui.viewmodel.SettingsViewModel

private data class BottomTab(
    val route: String,
    val labelRes: Int,
    val icon: androidx.compose.ui.graphics.vector.ImageVector,
)

@Composable
fun AppNavGraph(
    settingsViewModel: SettingsViewModel,
    hasSeenOnboarding: Boolean,
) {
    val app = LocalContext.current.applicationContext as XivDailyApplication
    val navController = rememberNavController()
    val tabs = listOf(
        BottomTab("home", R.string.tab_home, Icons.Rounded.AutoAwesome),
        BottomTab("library", R.string.tab_library, Icons.Rounded.Bookmarks),
        BottomTab("settings", R.string.tab_settings, Icons.Rounded.Tune),
    )
    val backStackEntry by navController.currentBackStackEntryAsState()
    val currentDestination = backStackEntry?.destination
    val spacing = MaterialTheme.xivSpacing
    val startRoute = if (hasSeenOnboarding) "home" else "home"

    Scaffold(
        containerColor = MaterialTheme.colorScheme.background,
        bottomBar = {
            NavigationBar(
                containerColor = MaterialTheme.colorScheme.surface,
                tonalElevation = spacing.xs,
            ) {
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
                        label = {
                            Text(
                                text = stringResource(tab.labelRes),
                                style = MaterialTheme.typography.labelMedium,
                                fontWeight = if (selected) FontWeight.Bold else FontWeight.Medium,
                            )
                        },
                        icon = {
                            Icon(
                                imageVector = tab.icon,
                                contentDescription = stringResource(tab.labelRes),
                            )
                        },
                        colors = NavigationBarItemDefaults.colors(
                            selectedIconColor = MaterialTheme.colorScheme.primary,
                            selectedTextColor = MaterialTheme.colorScheme.primary,
                            indicatorColor = MaterialTheme.colorScheme.primaryContainer,
                            unselectedIconColor = MaterialTheme.colorScheme.onSurfaceVariant,
                            unselectedTextColor = MaterialTheme.colorScheme.onSurfaceVariant,
                        ),
                    )
                }
            }
        }
    ) { paddingValues ->
        NavHost(
            navController = navController,
            startDestination = startRoute,
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
                    onKeywordSubmit = homeViewModel::submitKeyword,
                    onCategorySelect = homeViewModel::selectCategory,
                    onDaysSelect = homeViewModel::selectDays,
                    onDismissPaper = homeViewModel::dismissPaperFromFeed,
                    onTranslate = homeViewModel::translatePaper,
                    onFavorite = homeViewModel::toggleFavorite,
                    onSyncToZotero = homeViewModel::syncToZotero,
                    onToggleSummary = homeViewModel::toggleSummaryExpanded,
                    onDismissSummary = homeViewModel::dismissSummary,
                    onRefresh = homeViewModel::refreshFeed,
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
                    onSelectAll = libraryViewModel::selectAll,
                )
            }
            composable("settings") {
                val uiState by settingsViewModel.uiState.collectAsState()
                SettingsScreen(
                    uiState = uiState,
                    onShowThemePicker = settingsViewModel::showThemePicker,
                    onHideThemePicker = settingsViewModel::hideThemePicker,
                    onSelectThemeMode = settingsViewModel::selectThemeMode,
                    onShowLanguagePicker = settingsViewModel::showLanguagePicker,
                    onHideLanguagePicker = settingsViewModel::hideLanguagePicker,
                    onSelectLanguage = settingsViewModel::selectLanguage,
                    onShowZoteroDetailDialog = settingsViewModel::showZoteroDetailDialog,
                    onHideZoteroDetailDialog = settingsViewModel::hideZoteroDetailDialog,
                    onUpdateZoteroUserId = settingsViewModel::updateZoteroUserIdDraft,
                    onUpdateZoteroLibraryType = settingsViewModel::updateZoteroLibraryTypeDraft,
                    onUpdateZoteroApiKey = settingsViewModel::updateZoteroApiKeyDraft,
                    onUpdateZoteroCollection = settingsViewModel::updateZoteroCollectionDraft,
                    onSaveZoteroConfig = settingsViewModel::saveZoteroConfig,
                    onTestZoteroConfig = settingsViewModel::testZoteroConfig,
                    onShowLlmDetailDialog = settingsViewModel::showLlmDetailDialog,
                    onHideLlmDetailDialog = settingsViewModel::hideLlmDetailDialog,
                    onUpdateLlmBaseUrl = settingsViewModel::updateLlmBaseUrlDraft,
                    onUpdateLlmApiKey = settingsViewModel::updateLlmApiKeyDraft,
                    onUpdateLlmModel = settingsViewModel::updateLlmModelDraft,
                    onSaveLlmConfig = settingsViewModel::saveLlmConfig,
                    onTestLlmConfig = settingsViewModel::testLlmConfig,
                    onUpdateDefaultCategory = settingsViewModel::updateDefaultCategory,
                    onUpdateDefaultDays = settingsViewModel::updateDefaultDays,
                    onShowUpdateDialog = settingsViewModel::showUpdateDialog,
                    onHideUpdateDialog = settingsViewModel::hideUpdateDialog,
                    onShowAboutDialog = settingsViewModel::showAboutDialog,
                    onHideAboutDialog = settingsViewModel::hideAboutDialog,
                    onShowProfileDialog = settingsViewModel::showProfileDialog,
                    onHideProfileDialog = settingsViewModel::hideProfileDialog,
                    onUpdateProfile = settingsViewModel::updateProfile,
                    onShowClearCacheDialog = settingsViewModel::showClearCacheDialog,
                    onHideClearCacheDialog = settingsViewModel::hideClearCacheDialog,
                    onConfirmClearCache = settingsViewModel::clearCache,
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
