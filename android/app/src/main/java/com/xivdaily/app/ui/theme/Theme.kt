package com.xivdaily.app.ui.theme

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider

private val LightColors = lightColorScheme(
    primary = XivDailyPrimary,
    onPrimary = XivDailyOnPrimary,
    primaryContainer = XivDailyPrimaryContainer,
    onPrimaryContainer = XivDailyOnPrimaryContainer,
    secondary = XivDailySecondary,
    onSecondary = XivDailyOnSecondary,
    secondaryContainer = XivDailySecondaryContainer,
    onSecondaryContainer = XivDailyOnSecondaryContainer,
    tertiary = XivDailyTertiary,
    onTertiary = XivDailyOnTertiary,
    tertiaryContainer = XivDailyTertiaryContainer,
    onTertiaryContainer = XivDailyOnTertiaryContainer,
    background = XivDailyBackground,
    surface = XivDailySurface,
    surfaceVariant = XivDailySurfaceVariant,
    onSurface = XivDailyOnSurface,
    onSurfaceVariant = XivDailyOnSurfaceVariant,
    outline = XivDailyOutline,
    error = XivDailyDanger,
)

private val DarkColors = darkColorScheme(
    primary = XivDailyDarkPrimary,
    onPrimary = XivDailyDarkOnPrimary,
    primaryContainer = XivDailyDarkPrimaryContainer,
    onPrimaryContainer = XivDailyDarkOnPrimaryContainer,
    secondary = XivDailyDarkSecondary,
    onSecondary = XivDailyDarkOnSecondary,
    secondaryContainer = XivDailyDarkSecondaryContainer,
    onSecondaryContainer = XivDailyDarkOnSecondaryContainer,
    tertiary = XivDailyDarkTertiary,
    onTertiary = XivDailyDarkOnTertiary,
    tertiaryContainer = XivDailyDarkTertiaryContainer,
    onTertiaryContainer = XivDailyDarkOnTertiaryContainer,
    background = XivDailyDarkBackground,
    surface = XivDailyDarkSurface,
    surfaceVariant = XivDailyDarkSurfaceVariant,
    onSurface = XivDailyDarkOnSurface,
    onSurfaceVariant = XivDailyDarkOnSurfaceVariant,
    outline = XivDailyDarkOutline,
    error = XivDailyDanger,
)

@Composable
fun XivDailyTheme(themeMode: String = "system", content: @Composable () -> Unit) {
    val colorScheme = when (themeMode) {
        "dark" -> DarkColors
        "light" -> LightColors
        else -> if (isSystemInDarkTheme()) DarkColors else LightColors
    }

    CompositionLocalProvider(LocalXivDailySpacing provides XivDailySpacing()) {
        MaterialTheme(
            colorScheme = colorScheme,
            typography = XivDailyTypography,
            shapes = XivDailyShapes,
            content = content,
        )
    }
}
