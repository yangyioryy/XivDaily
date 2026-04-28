package com.xivdaily.app.data.local

import androidx.room.Database
import androidx.room.RoomDatabase

@Database(entities = [FavoritePaperEntity::class], version = 1)
abstract class AppDatabase : RoomDatabase() {
    abstract fun favoritePaperDao(): FavoritePaperDao
}

