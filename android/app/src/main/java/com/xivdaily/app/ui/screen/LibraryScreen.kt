package com.xivdaily.app.ui.screen

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.animateContentSize
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Bookmarks
import androidx.compose.material.icons.rounded.ChevronRight
import androidx.compose.material.icons.rounded.DeleteSweep
import androidx.compose.material.icons.rounded.Download
import androidx.compose.material.icons.rounded.Sync
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.FilterChip
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.xivdaily.app.data.model.FavoritePaperItem
import com.xivdaily.app.ui.theme.XivDailyDanger
import com.xivdaily.app.ui.theme.XivDailyInfo
import com.xivdaily.app.ui.theme.XivDailySuccess
import com.xivdaily.app.ui.theme.XivDailyWarning
import com.xivdaily.app.ui.theme.xivSpacing
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
    val spacing = MaterialTheme.xivSpacing
    val filtered = uiState.favorites.filter {
        uiState.syncFilter == "all" || it.paper.zoteroSyncState == uiState.syncFilter
    }

    LazyColumn(
        modifier = Modifier
            .fillMaxSize()
            .background(MaterialTheme.colorScheme.background)
            .padding(horizontal = spacing.md),
        verticalArrangement = Arrangement.spacedBy(spacing.lg),
    ) {
        item {
            Spacer(modifier = Modifier.height(spacing.xs))
            LibraryHeroSection(uiState = uiState, filteredCount = filtered.size)
        }
        item {
            LibraryToolbar(
                selectedCount = uiState.selectedPaperIds.size,
                onDeleteSelected = onDeleteSelected,
                onExportSelected = onExportSelected,
                batchEnabled = uiState.selectedPaperIds.isNotEmpty(),
            )
        }
        item {
            LibraryFilterToolbar(
                syncFilter = uiState.syncFilter,
                onChangeSyncFilter = onChangeSyncFilter,
            )
        }
        if (uiState.actionMessage != null) {
            item {
                // 操作反馈只做淡入淡出，减少列表内容被硬切打断的感觉。
                AnimatedVisibility(visible = true, enter = fadeIn(), exit = fadeOut()) {
                    StatusCard(
                        title = "操作反馈",
                        message = uiState.actionMessage,
                        background = MaterialTheme.colorScheme.primaryContainer,
                        foreground = MaterialTheme.colorScheme.onPrimaryContainer,
                    )
                }
            }
        }
        if (uiState.errorMessage != null) {
            item {
                AnimatedVisibility(visible = true, enter = fadeIn(), exit = fadeOut()) {
                    StatusCard(
                        title = "操作提醒",
                        message = uiState.errorMessage,
                        background = MaterialTheme.colorScheme.tertiaryContainer,
                        foreground = MaterialTheme.colorScheme.onTertiaryContainer,
                    )
                }
            }
        }
        uiState.exportContent?.let { content ->
            item {
                ExportResultCard(content = content)
            }
        }
        item {
            Text(
                text = "收藏论文",
                style = MaterialTheme.typography.titleLarge,
                color = MaterialTheme.colorScheme.onSurface,
            )
        }
        if (uiState.favorites.isEmpty()) {
            item {
                EmptyLibraryStateCard(
                    title = "还没有收藏论文",
                    subtitle = "在首页收藏感兴趣的论文后，这里会成为你的研究资料库。",
                )
            }
        } else if (filtered.isEmpty()) {
            item {
                EmptyLibraryStateCard(
                    title = "当前筛选下没有结果",
                    subtitle = "可以切换同步状态，或者检查导出与同步后的收藏记录。",
                )
            }
        } else {
            item {
                Text(
                    text = "共 ${uiState.favorites.size} 条 · 当前展示 ${filtered.size} 条",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
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
        item {
            Spacer(modifier = Modifier.height(spacing.xl))
        }
    }
}

@Composable
private fun LibraryHeroSection(
    uiState: LibraryUiState,
    filteredCount: Int,
) {
    val spacing = MaterialTheme.xivSpacing
    Column(
        modifier = Modifier.fillMaxWidth(),
        verticalArrangement = Arrangement.spacedBy(spacing.md),
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(
                text = "收藏库",
                style = MaterialTheme.typography.headlineLarge,
                color = MaterialTheme.colorScheme.onBackground,
            )
            Surface(
                shape = MaterialTheme.shapes.medium,
                color = MaterialTheme.colorScheme.primaryContainer,
            ) {
                Text(
                    text = "${filterLabel(uiState.syncFilter)} · ${filteredCount} 条",
                    modifier = Modifier.padding(horizontal = spacing.md, vertical = spacing.xs),
                    style = MaterialTheme.typography.labelLarge,
                    color = MaterialTheme.colorScheme.onPrimaryContainer,
                )
            }
        }
        Text(
            text = "保留真正值得长期跟进的论文，批量管理同步与导出。",
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
    }
}

@Composable
private fun LibraryToolbar(
    selectedCount: Int,
    batchEnabled: Boolean,
    onDeleteSelected: () -> Unit,
    onExportSelected: () -> Unit,
) {
    val spacing = MaterialTheme.xivSpacing
    Card(
        modifier = Modifier.fillMaxWidth(),
        shape = MaterialTheme.shapes.large,
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
        elevation = CardDefaults.cardElevation(defaultElevation = 2.dp),
    ) {
        Column(
            modifier = Modifier
                .padding(horizontal = spacing.md, vertical = spacing.lg)
                .animateContentSize(),
            verticalArrangement = Arrangement.spacedBy(spacing.md),
        ) {
            Row(
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically,
                modifier = Modifier.fillMaxWidth(),
            ) {
                Column {
                    Text(
                        text = "批量操作",
                        style = MaterialTheme.typography.titleMedium,
                        color = MaterialTheme.colorScheme.onSurface,
                    )
                    Text(
                        text = "已选 $selectedCount 项",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
                LeadingPill(icon = Icons.Rounded.Bookmarks)
            }
            Row(horizontalArrangement = Arrangement.spacedBy(spacing.xs)) {
                Button(
                    onClick = onDeleteSelected,
                    enabled = batchEnabled,
                    shape = MaterialTheme.shapes.medium,
                    colors = ButtonDefaults.buttonColors(
                        containerColor = MaterialTheme.colorScheme.tertiaryContainer,
                        contentColor = MaterialTheme.colorScheme.onTertiaryContainer,
                    ),
                ) {
                    Icon(
                        imageVector = Icons.Rounded.DeleteSweep,
                        contentDescription = "批量删除",
                        modifier = Modifier.size(16.dp),
                    )
                    Spacer(modifier = Modifier.size(spacing.xs))
                    Text("批量删除")
                }
                Button(
                    onClick = onExportSelected,
                    enabled = batchEnabled,
                    shape = MaterialTheme.shapes.medium,
                    colors = ButtonDefaults.buttonColors(
                        containerColor = MaterialTheme.colorScheme.primaryContainer,
                        contentColor = MaterialTheme.colorScheme.onPrimaryContainer,
                    ),
                ) {
                    Icon(
                        imageVector = Icons.Rounded.Download,
                        contentDescription = "导出 BibTeX",
                        modifier = Modifier.size(16.dp),
                    )
                    Spacer(modifier = Modifier.size(spacing.xs))
                    Text("导出 BibTeX")
                }
            }
        }
    }
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun LibraryFilterToolbar(
    syncFilter: String,
    onChangeSyncFilter: (String) -> Unit,
) {
    val spacing = MaterialTheme.xivSpacing
    Card(
        modifier = Modifier.fillMaxWidth(),
        shape = MaterialTheme.shapes.large,
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
        elevation = CardDefaults.cardElevation(defaultElevation = 2.dp),
    ) {
        Column(
            modifier = Modifier.padding(horizontal = spacing.md, vertical = spacing.lg),
            verticalArrangement = Arrangement.spacedBy(spacing.sm),
        ) {
            Text(
                text = "同步状态筛选",
                style = MaterialTheme.typography.titleSmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            FlowRow(
                horizontalArrangement = Arrangement.spacedBy(spacing.xs),
                verticalArrangement = Arrangement.spacedBy(spacing.xs),
            ) {
                listOf(
                    "all" to "全部",
                    "not_synced" to "未同步",
                    "synced" to "已同步",
                    "failed" to "失败",
                ).forEach { (value, label) ->
                    FilterChip(
                        selected = syncFilter == value,
                        onClick = { onChangeSyncFilter(value) },
                        label = { Text(label, style = MaterialTheme.typography.labelLarge) },
                    )
                }
            }
        }
    }
}

@Composable
private fun StatusCard(
    title: String,
    message: String,
    background: Color,
    foreground: Color,
) {
    val spacing = MaterialTheme.xivSpacing
    Surface(
        modifier = Modifier.fillMaxWidth(),
        shape = MaterialTheme.shapes.medium,
        color = background,
    ) {
        Column(
            modifier = Modifier.padding(horizontal = spacing.md, vertical = spacing.sm),
            verticalArrangement = Arrangement.spacedBy(4.dp),
        ) {
            Text(
                text = title,
                style = MaterialTheme.typography.labelLarge,
                color = foreground,
            )
            Text(
                text = message,
                style = MaterialTheme.typography.bodySmall,
                color = foreground,
            )
        }
    }
}

@Composable
private fun ExportResultCard(content: String) {
    val spacing = MaterialTheme.xivSpacing
    Card(
        modifier = Modifier.fillMaxWidth(),
        shape = MaterialTheme.shapes.large,
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.secondaryContainer),
    ) {
        Column(
            modifier = Modifier.padding(horizontal = spacing.md, vertical = spacing.lg),
            verticalArrangement = Arrangement.spacedBy(spacing.sm),
        ) {
            Text(
                text = "BibTeX 导出结果",
                style = MaterialTheme.typography.titleMedium,
                color = MaterialTheme.colorScheme.onSecondaryContainer,
            )
            Text(
                text = "生成后可直接复制到你的文献管理工具中。",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSecondaryContainer,
            )
            Text(
                text = content.ifBlank { "未导出任何条目" },
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSecondaryContainer,
            )
        }
    }
}

@Composable
private fun EmptyLibraryStateCard(
    title: String,
    subtitle: String,
) {
    val spacing = MaterialTheme.xivSpacing
    Card(
        modifier = Modifier.fillMaxWidth(),
        shape = MaterialTheme.shapes.large,
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
    ) {
        Column(
            modifier = Modifier.padding(horizontal = spacing.md, vertical = spacing.xl),
            verticalArrangement = Arrangement.spacedBy(spacing.xs),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            LeadingPill(icon = Icons.Rounded.Bookmarks)
            Text(
                text = title,
                style = MaterialTheme.typography.titleMedium,
                color = MaterialTheme.colorScheme.onSurface,
            )
            Text(
                text = subtitle,
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
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
    val spacing = MaterialTheme.xivSpacing
    Card(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onToggleSelection),
        shape = MaterialTheme.shapes.large,
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
        elevation = CardDefaults.cardElevation(defaultElevation = 2.dp),
    ) {
        Column(
            modifier = Modifier
                .padding(horizontal = spacing.md, vertical = spacing.lg)
                .animateContentSize(),
            verticalArrangement = Arrangement.spacedBy(spacing.sm),
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.Top,
            ) {
                Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                    Text(
                        text = favorite.paper.title,
                        style = MaterialTheme.typography.titleMedium,
                        color = MaterialTheme.colorScheme.onSurface,
                    )
                    Text(
                        text = "收藏于 ${favorite.savedAt.take(10)}",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
                Icon(
                    imageVector = Icons.Rounded.ChevronRight,
                    contentDescription = null,
                    tint = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
            Row(
                horizontalArrangement = Arrangement.spacedBy(spacing.xs),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                StatusPill(
                    label = statusLabel(favorite.paper.zoteroSyncState),
                    color = statusColor(favorite.paper.zoteroSyncState),
                )
                StatusPill(
                    label = if (selected) "已选中" else "点按可加入批量选择",
                    color = if (selected) XivDailyInfo else MaterialTheme.colorScheme.outline,
                )
            }
            Text(
                text = favorite.paper.summary,
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            Row(horizontalArrangement = Arrangement.spacedBy(spacing.xs)) {
                if (favorite.paper.zoteroSyncState != "synced") {
                    Button(
                        onClick = onSyncFavorite,
                        shape = MaterialTheme.shapes.medium,
                        colors = ButtonDefaults.buttonColors(
                            containerColor = MaterialTheme.colorScheme.primaryContainer,
                            contentColor = MaterialTheme.colorScheme.onPrimaryContainer,
                        ),
                    ) {
                        Icon(
                            imageVector = Icons.Rounded.Sync,
                            contentDescription = "同步 Zotero",
                            modifier = Modifier.size(16.dp),
                        )
                        Spacer(modifier = Modifier.size(spacing.xs))
                        Text("同步 Zotero")
                    }
                }
                Button(
                    onClick = onDeleteFavorite,
                    shape = MaterialTheme.shapes.medium,
                    colors = ButtonDefaults.buttonColors(
                        containerColor = MaterialTheme.colorScheme.tertiaryContainer,
                        contentColor = XivDailyDanger,
                    ),
                ) {
                    Icon(
                        imageVector = Icons.Rounded.DeleteSweep,
                        contentDescription = "删除",
                        modifier = Modifier.size(16.dp),
                    )
                    Spacer(modifier = Modifier.size(spacing.xs))
                    Text("删除")
                }
            }
        }
    }
}

@Composable
private fun StatusPill(
    label: String,
    color: Color,
) {
    val spacing = MaterialTheme.xivSpacing
    Surface(
        shape = MaterialTheme.shapes.medium,
        color = MaterialTheme.colorScheme.surfaceVariant,
    ) {
        Row(
            modifier = Modifier.padding(horizontal = spacing.sm, vertical = spacing.xs),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(6.dp),
        ) {
            Box(
                modifier = Modifier
                    .size(8.dp)
                    .background(color = color, shape = MaterialTheme.shapes.extraSmall),
            )
            Text(
                text = label,
                style = MaterialTheme.typography.labelMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
    }
}

@Composable
private fun LeadingPill(icon: androidx.compose.ui.graphics.vector.ImageVector) {
    Box(
        modifier = Modifier
            .size(36.dp)
            .background(
                color = MaterialTheme.colorScheme.primaryContainer,
                shape = MaterialTheme.shapes.small,
            ),
        contentAlignment = Alignment.Center,
    ) {
        Icon(
            imageVector = icon,
            contentDescription = null,
            tint = MaterialTheme.colorScheme.primary,
            modifier = Modifier.size(18.dp),
        )
    }
}

private fun filterLabel(syncFilter: String): String {
    return when (syncFilter) {
        "synced" -> "已同步"
        "failed" -> "同步失败"
        "not_synced" -> "待同步"
        else -> "全部"
    }
}

private fun statusLabel(syncState: String): String {
    return when (syncState) {
        "synced" -> "已同步"
        "failed" -> "同步失败"
        "not_synced" -> "待同步"
        else -> syncState.ifBlank { "未知状态" }
    }
}

private fun statusColor(syncState: String): Color {
    return when (syncState) {
        "synced" -> XivDailySuccess
        "failed" -> XivDailyDanger
        "not_synced" -> XivDailyWarning
        else -> XivDailyInfo
    }
}
