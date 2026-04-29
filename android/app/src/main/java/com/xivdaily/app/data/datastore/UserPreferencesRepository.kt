package com.xivdaily.app.data.datastore

import android.content.Context
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.intPreferencesKey
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map

private val Context.dataStore by preferencesDataStore(name = "user_preferences")

data class UserPreferences(
    val defaultCategory: String = "cs.CV",
    val defaultDays: Int = 3,
    val themeMode: String = "system",
    val backendBaseUrl: String = "http://10.0.2.2:8000/",
)

interface UserPreferencesRepositoryContract {
    val preferences: Flow<UserPreferences>
    suspend fun setDefaultCategory(category: String)
    suspend fun setDefaultDays(days: Int)
    suspend fun setThemeMode(themeMode: String)
    suspend fun setBackendBaseUrl(baseUrl: String)
}

class UserPreferencesRepository(private val context: Context) : UserPreferencesRepositoryContract {
    private val defaultCategoryKey = stringPreferencesKey("default_category")
    private val defaultDaysKey = intPreferencesKey("default_days")
    private val themeModeKey = stringPreferencesKey("theme_mode")
    private val backendBaseUrlKey = stringPreferencesKey("backend_base_url")

    override val preferences: Flow<UserPreferences> = context.dataStore.data.map { preferences ->
        UserPreferences(
            defaultCategory = preferences[defaultCategoryKey] ?: "cs.CV",
            defaultDays = preferences[defaultDaysKey] ?: 3,
            themeMode = preferences[themeModeKey] ?: "system",
            backendBaseUrl = preferences[backendBaseUrlKey] ?: "http://10.0.2.2:8000/",
        )
    }

    override suspend fun setDefaultCategory(category: String) {
        context.dataStore.edit { it[defaultCategoryKey] = category }
    }

    override suspend fun setDefaultDays(days: Int) {
        context.dataStore.edit { it[defaultDaysKey] = days }
    }

    override suspend fun setThemeMode(themeMode: String) {
        context.dataStore.edit { it[themeModeKey] = themeMode }
    }

    override suspend fun setBackendBaseUrl(baseUrl: String) {
        context.dataStore.edit { it[backendBaseUrlKey] = baseUrl }
    }
}
