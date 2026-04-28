package com.xivdaily.app.ui.navigation

import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.foundation.layout.padding
import androidx.compose.ui.res.stringResource
import androidx.navigation.NavDestination.Companion.hierarchy
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.rememberNavController
import com.xivdaily.app.R
import com.xivdaily.app.ui.screen.LibraryScreen
import com.xivdaily.app.ui.screen.SettingsScreen
import com.xivdaily.app.ui.screen.HomeScreen

private data class BottomTab(val route: String, val labelRes: Int)

@Composable
fun AppNavGraph() {
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
            composable("home") { HomeScreen() }
            composable("library") { LibraryScreen() }
            composable("settings") { SettingsScreen() }
        }
    }
}
