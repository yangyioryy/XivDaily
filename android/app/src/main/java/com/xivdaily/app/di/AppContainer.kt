package com.xivdaily.app.di

import android.content.Context
import androidx.room.Room
import com.xivdaily.app.data.datastore.UserPreferencesRepository
import com.xivdaily.app.data.local.AppDatabase
import com.xivdaily.app.data.remote.NetworkModule
import com.xivdaily.app.data.repository.PaperRepository

class AppContainer(private val context: Context) {
    private val apiService = NetworkModule.createApiService("http://10.0.2.2:8000/")

    val database: AppDatabase = Room.databaseBuilder(
        context,
        AppDatabase::class.java,
        "xivdaily.db",
    ).build()

    val userPreferencesRepository = UserPreferencesRepository(context)
    val paperRepository = PaperRepository(apiService, database.favoritePaperDao())
}
