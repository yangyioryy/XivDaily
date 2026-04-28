package com.xivdaily.app.ui.theme

import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.Composable

private val LightColors = lightColorScheme(
    primary = XivDailyPrimary,
    secondary = XivDailySecondary,
    background = XivDailySurface,
)

private val DarkColors = darkColorScheme(
    primary = XivDailySecondary,
    secondary = XivDailyPrimary,
)

@Composable
fun XivDailyTheme(content: @Composable () -> Unit) {
    MaterialTheme(
        colorScheme = LightColors,
        typography = XivDailyTypography,
        shapes = XivDailyShapes,
        content = content,
    )
}
