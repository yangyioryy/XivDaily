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
    val themeMode: String = "light",
    val hasSeenOnboarding: Boolean = false,
    val displayName: String = "XivDaily Reader",
    val avatarPreset: String = "study",
    val avatarImageUri: String? = null,
)

interface UserPreferencesRepositoryContract {
    val preferences: Flow<UserPreferences>
    suspend fun setDefaultCategory(category: String)
    suspend fun setDefaultDays(days: Int)
    suspend fun setThemeMode(themeMode: String)
    suspend fun setHasSeenOnboarding(hasSeen: Boolean)
    suspend fun setDisplayName(displayName: String)
    suspend fun setAvatarPreset(avatarPreset: String)
    suspend fun setAvatarImageUri(uri: String?)
}

class UserPreferencesRepository(private val context: Context) : UserPreferencesRepositoryContract {
    private val defaultCategoryKey = stringPreferencesKey("default_category")
    private val defaultDaysKey = intPreferencesKey("default_days")
    private val themeModeKey = stringPreferencesKey("theme_mode")
    private val hasSeenOnboardingKey = androidx.datastore.preferences.core.booleanPreferencesKey("has_seen_onboarding")
    private val displayNameKey = stringPreferencesKey("display_name")
    private val avatarPresetKey = stringPreferencesKey("avatar_preset")
    private val avatarImageUriKey = stringPreferencesKey("avatar_image_uri")

    override val preferences: Flow<UserPreferences> = context.dataStore.data.map { preferences ->
        UserPreferences(
            defaultCategory = preferences[defaultCategoryKey] ?: "cs.CV",
            defaultDays = preferences[defaultDaysKey] ?: 3,
            themeMode = preferences[themeModeKey] ?: "light",
            hasSeenOnboarding = preferences[hasSeenOnboardingKey] ?: false,
            displayName = preferences[displayNameKey] ?: "XivDaily Reader",
            avatarPreset = preferences[avatarPresetKey] ?: "study",
            avatarImageUri = preferences[avatarImageUriKey],
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

    override suspend fun setHasSeenOnboarding(hasSeen: Boolean) {
        context.dataStore.edit { it[hasSeenOnboardingKey] = hasSeen }
    }

    override suspend fun setDisplayName(displayName: String) {
        context.dataStore.edit { it[displayNameKey] = displayName }
    }

    override suspend fun setAvatarPreset(avatarPreset: String) {
        context.dataStore.edit { it[avatarPresetKey] = avatarPreset }
    }

    override suspend fun setAvatarImageUri(uri: String?) {
        context.dataStore.edit { preferences ->
            if (uri.isNullOrBlank()) {
                preferences.remove(avatarImageUriKey)
            } else {
                preferences[avatarImageUriKey] = uri
            }
        }
    }
}
