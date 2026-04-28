package com.xivdaily.app.data.local

import androidx.room.Entity
import androidx.room.PrimaryKey

@Entity(tableName = "favorite_papers")
data class FavoritePaperEntity(
    @PrimaryKey val paperId: String,
    val title: String,
    val authorsJson: String,
    val summary: String,
    val publishedAt: String,
    val primaryCategory: String,
    val sourceUrl: String,
    val pdfUrl: String,
    val savedAt: String,
    val zoteroSyncState: String,
)

