package com.xivdaily.app.data.datastore

import android.content.Context
import androidx.datastore.preferences.core.intPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import kotlinx.coroutines.flow.map

private val Context.dataStore by preferencesDataStore(name = "user_preferences")

class UserPreferencesRepository(private val context: Context) {
    private val defaultDaysKey = intPreferencesKey("default_days")

    val defaultDays = context.dataStore.data.map { preferences ->
        preferences[defaultDaysKey] ?: 3
    }
}

