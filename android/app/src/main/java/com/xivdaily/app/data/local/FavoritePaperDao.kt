package com.xivdaily.app.data.local

import androidx.room.Dao
import androidx.room.Query
import androidx.room.Upsert
import kotlinx.coroutines.flow.Flow

@Dao
interface FavoritePaperDao {
    @Query("SELECT * FROM favorite_papers ORDER BY savedAt DESC")
    fun observeFavorites(): Flow<List<FavoritePaperEntity>>

    @Upsert
    suspend fun upsertFavorite(entity: FavoritePaperEntity)

    @Query("DELETE FROM favorite_papers WHERE paperId = :paperId")
    suspend fun deleteFavorite(paperId: String)
}

