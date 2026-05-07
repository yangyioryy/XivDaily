package com.xivdaily.app.ui.navigation

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class AppNavGraphTest {
    @Test
    fun bottomTabSelection_treatsPaperChatRouteAsChatTab() {
        assertTrue(isBottomTabSelected(currentRoute = "chat/{paperId}", tabRoute = "chat"))
        assertFalse(isBottomTabSelected(currentRoute = "chat/{paperId}", tabRoute = "library"))
    }

    @Test
    fun bottomTabBackStackRestore_isDisabledFromParameterizedRoute() {
        assertFalse(shouldRestoreBottomTabBackStack("chat/{paperId}"))
        assertTrue(shouldRestoreBottomTabBackStack("library"))
    }
}
