package com.xivdaily.app.ui

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.runtime.Composable
import com.xivdaily.app.ui.navigation.AppNavGraph
import com.xivdaily.app.ui.theme.XivDailyTheme

@Composable
fun AppRoot() {
    XivDailyTheme {
        Surface(color = MaterialTheme.colorScheme.background) {
            AppNavGraph()
        }
    }
}

