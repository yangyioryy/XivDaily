package com.xivdaily.app.di

import android.content.Context
import androidx.room.Room
import com.xivdaily.app.BuildConfig
import com.xivdaily.app.data.datastore.UserPreferencesRepository
import com.xivdaily.app.data.local.AppDatabase
import com.xivdaily.app.data.remote.NetworkModule
import com.xivdaily.app.data.repository.PaperRepository

class AppContainer(private val context: Context) {
    // 网络基址只允许从构建期注入，避免普通设置页再暴露开发地址。
    private val apiService = NetworkModule.createApiService(BuildConfig.BACKEND_BASE_URL)

    val database: AppDatabase = Room.databaseBuilder(
        context,
        AppDatabase::class.java,
        "xivdaily.db",
    ).build()

    val userPreferencesRepository = UserPreferencesRepository(context)
    val paperRepository = PaperRepository(apiService, database.favoritePaperDao())
}
