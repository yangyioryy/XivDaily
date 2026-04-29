package com.xivdaily.app.data.local

import androidx.room.Dao
import androidx.room.Query
import androidx.room.Upsert
import kotlinx.coroutines.flow.Flow

@Dao
interface FavoritePaperDao {
    @Query("SELECT * FROM favorite_papers ORDER BY savedAt DESC")
    fun observeFavorites(): Flow<List<FavoritePaperEntity>>

    @Query("SELECT paperId FROM favorite_papers")
    suspend fun getFavoriteIds(): List<String>

    @Upsert
    suspend fun upsertFavorite(entity: FavoritePaperEntity)

    @Query("DELETE FROM favorite_papers WHERE paperId = :paperId")
    suspend fun deleteFavorite(paperId: String)

    @Query("UPDATE favorite_papers SET zoteroSyncState = :syncState WHERE paperId = :paperId")
    suspend fun updateZoteroSyncState(paperId: String, syncState: String)
}
