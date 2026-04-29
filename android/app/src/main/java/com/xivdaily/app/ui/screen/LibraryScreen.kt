package com.xivdaily.app.ui.screen

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.FilterChip
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.xivdaily.app.data.model.FavoritePaperItem
import com.xivdaily.app.ui.viewmodel.LibraryUiState

@OptIn(ExperimentalLayoutApi::class)
@Composable
fun LibraryScreen(
    uiState: LibraryUiState,
    onToggleSelection: (String) -> Unit,
    onChangeSyncFilter: (String) -> Unit,
    onDeleteFavorite: (String) -> Unit,
    onDeleteSelected: () -> Unit,
    onSyncFavorite: (String) -> Unit,
    onExportSelected: () -> Unit,
) {
    val filtered = uiState.favorites.filter {
        uiState.syncFilter == "all" || it.paper.zoteroSyncState == uiState.syncFilter
    }

    LazyColumn(
        modifier = Modifier
            .fillMaxSize()
            .background(MaterialTheme.colorScheme.background)
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        item {
            Text(text = "收藏库", style = MaterialTheme.typography.headlineMedium, fontWeight = FontWeight.Bold)
        }
        item {
            Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                Text(text = "已选 ${uiState.selectedPaperIds.size} 项")
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    Button(onClick = onDeleteSelected, enabled = uiState.selectedPaperIds.isNotEmpty()) {
                        Text("批量删除")
                    }
                    Button(onClick = onExportSelected, enabled = uiState.selectedPaperIds.isNotEmpty()) {
                        Text("导出 BibTeX")
                    }
                }
            }
        }
        item {
            FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                listOf("all" to "全部", "not_synced" to "未同步", "synced" to "已同步", "failed" to "失败").forEach { (value, label) ->
                    FilterChip(
                        selected = uiState.syncFilter == value,
                        onClick = { onChangeSyncFilter(value) },
                        label = { Text(label) },
                    )
                }
            }
        }
        uiState.actionMessage?.let { item { Text(text = it, color = MaterialTheme.colorScheme.primary) } }
        uiState.errorMessage?.let { item { Text(text = it, color = MaterialTheme.colorScheme.error) } }
        uiState.exportContent?.let { content ->
            item {
                Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.secondaryContainer)) {
                    Column(modifier = Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        Text(text = "BibTeX 导出结果", fontWeight = FontWeight.Bold)
                        Text(text = "首版出口：在收藏库中直接复制这段文本。")
                        Text(text = content.ifBlank { "未导出任何条目" })
                    }
                }
            }
        }
        if (filtered.isEmpty()) {
            item { Text("暂无符合筛选条件的收藏论文") }
        }
        items(filtered, key = { it.paper.id }) { favorite ->
            FavoritePaperCard(
                favorite = favorite,
                selected = favorite.paper.id in uiState.selectedPaperIds,
                onToggleSelection = { onToggleSelection(favorite.paper.id) },
                onDeleteFavorite = { onDeleteFavorite(favorite.paper.id) },
                onSyncFavorite = { onSyncFavorite(favorite.paper.id) },
            )
        }
    }
}

@Composable
private fun FavoritePaperCard(
    favorite: FavoritePaperItem,
    selected: Boolean,
    onToggleSelection: () -> Unit,
    onDeleteFavorite: () -> Unit,
    onSyncFavorite: () -> Unit,
) {
    Card(
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
        modifier = Modifier.clickable(onClick = onToggleSelection),
    ) {
        Column(modifier = Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Text(text = favorite.paper.title, fontWeight = FontWeight.SemiBold)
            Text(text = "状态：${favorite.paper.zoteroSyncState} · 收藏于 ${favorite.savedAt.take(10)}")
            Text(text = if (selected) "已加入批量选择" else "点击加入批量选择")
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                Button(onClick = onSyncFavorite) { Text("同步 Zotero") }
                Button(onClick = onDeleteFavorite) { Text("删除") }
            }
        }
    }
}
