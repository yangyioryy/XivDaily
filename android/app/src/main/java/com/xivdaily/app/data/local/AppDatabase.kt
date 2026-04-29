package com.xivdaily.app.data.local

import androidx.room.Database
import androidx.room.RoomDatabase

// 首版本地库暂不导出 Room schema 文件，避免生成物进入仓库。
@Database(entities = [FavoritePaperEntity::class], version = 1, exportSchema = false)
abstract class AppDatabase : RoomDatabase() {
    abstract fun favoritePaperDao(): FavoritePaperDao
}
