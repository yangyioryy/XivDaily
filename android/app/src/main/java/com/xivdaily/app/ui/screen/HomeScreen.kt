package com.xivdaily.app.ui.screen

import androidx.compose.foundation.background
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
import androidx.compose.material.icons.rounded.AutoAwesome
import androidx.compose.material.icons.rounded.BookmarkBorder
import androidx.compose.material.icons.rounded.ChevronRight
import androidx.compose.material.icons.rounded.Search
import androidx.compose.material.icons.rounded.Sync
import androidx.compose.material.icons.rounded.Translate
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.FilterChip
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.xivdaily.app.data.model.PaperItem
import com.xivdaily.app.ui.theme.XivDailyInfo
import com.xivdaily.app.ui.theme.XivDailySuccess
import com.xivdaily.app.ui.theme.XivDailyWarning
import com.xivdaily.app.ui.theme.xivSpacing
import com.xivdaily.app.ui.viewmodel.HomeUiState

@OptIn(ExperimentalLayoutApi::class)
@Composable
fun HomeScreen(
    uiState: HomeUiState,
    onKeywordChange: (String) -> Unit,
    onCategorySelect: (String) -> Unit,
    onDaysSelect: (Int) -> Unit,
    onTranslate: (PaperItem) -> Unit,
    onFavorite: (PaperItem) -> Unit,
    onSyncToZotero: (PaperItem) -> Unit,
    onToggleSummary: () -> Unit,
    onDismissSummary: () -> Unit,
) {
    val spacing = MaterialTheme.xivSpacing
    LazyColumn(
        modifier = Modifier
            .fillMaxSize()
            .background(MaterialTheme.colorScheme.background)
            .padding(horizontal = spacing.md),
        verticalArrangement = Arrangement.spacedBy(spacing.lg),
    ) {
        item {
            Spacer(modifier = Modifier.height(spacing.xs))
            HomeHeroSection(uiState = uiState)
        }
        item {
            ExploreControlCard(
                uiState = uiState,
                onKeywordChange = onKeywordChange,
                onCategorySelect = onCategorySelect,
                onDaysSelect = onDaysSelect,
            )
        }
        if (!uiState.dismissedSummary) {
            item {
                TrendSummaryCard(
                    uiState = uiState,
                    onToggleSummary = onToggleSummary,
                    onDismissSummary = onDismissSummary,
                )
            }
        }
        uiState.actionMessage?.let { message ->
            item {
                InlineMessageCard(
                    message = message,
                    background = MaterialTheme.colorScheme.primaryContainer,
                    foreground = MaterialTheme.colorScheme.onPrimaryContainer,
                )
            }
        }
        uiState.errorMessage?.let { message ->
            item {
                InlineMessageCard(
                    message = message,
                    background = MaterialTheme.colorScheme.tertiaryContainer,
                    foreground = MaterialTheme.colorScheme.onTertiaryContainer,
                )
            }
        }
        item {
            SectionHeader(
                title = if (uiState.isLoading) "论文加载中..." else "今日论文",
                subtitle = "围绕 ${uiState.selectedCategory} 的最新研究流",
            )
        }
        if (uiState.papers.isEmpty()) {
            item {
                EmptyStateCard(
                    title = if (uiState.isLoading) "正在刷新论文列表" else "当前暂无可展示论文",
                    subtitle = if (uiState.isLoading) "稍后将自动填充最新内容" else "可以切换领域、时间窗口或重新搜索",
                )
            }
        }
        items(uiState.papers, key = { it.id }) { paper ->
            HomePaperCard(
                paper = paper,
                onTranslate = { onTranslate(paper) },
                onFavorite = { onFavorite(paper) },
                onSyncToZotero = { onSyncToZotero(paper) },
            )
        }
        item {
            Spacer(modifier = Modifier.height(spacing.xl))
        }
    }
}

@Composable
private fun HomeHeroSection(uiState: HomeUiState) {
    val spacing = MaterialTheme.xivSpacing
    Column(verticalArrangement = Arrangement.spacedBy(spacing.sm)) {
        Text(
            text = "首页",
            style = MaterialTheme.typography.headlineLarge,
            color = MaterialTheme.colorScheme.onBackground,
        )
        Text(
            text = "把每日论文流整理成一眼能读懂的研究工作台。",
            style = MaterialTheme.typography.bodyLarge,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        Surface(
            shape = MaterialTheme.shapes.medium,
            color = MaterialTheme.colorScheme.primaryContainer,
        ) {
            Text(
                text = "当前聚焦：${uiState.selectedCategory} · ${formatDays(uiState.selectedDays)}",
                modifier = Modifier.padding(horizontal = spacing.md, vertical = spacing.sm),
                style = MaterialTheme.typography.labelLarge,
                color = MaterialTheme.colorScheme.onPrimaryContainer,
            )
        }
    }
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun ExploreControlCard(
    uiState: HomeUiState,
    onKeywordChange: (String) -> Unit,
    onCategorySelect: (String) -> Unit,
    onDaysSelect: (Int) -> Unit,
) {
    val spacing = MaterialTheme.xivSpacing
    Card(
        modifier = Modifier.fillMaxWidth(),
        shape = MaterialTheme.shapes.large,
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
        elevation = CardDefaults.cardElevation(defaultElevation = spacing.xs),
    ) {
        Column(
            modifier = Modifier.padding(horizontal = spacing.md, vertical = spacing.lg),
            verticalArrangement = Arrangement.spacedBy(spacing.md),
        ) {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(spacing.sm),
            ) {
                LeadingPill(icon = Icons.Rounded.Search)
                Column {
                    Text(
                        text = "探索控制台",
                        style = MaterialTheme.typography.titleMedium,
                        color = MaterialTheme.colorScheme.onSurface,
                    )
                    Text(
                        text = "搜索关键词并快速切换领域、时间窗口",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
            }
            OutlinedTextField(
                value = uiState.searchKeyword,
                onValueChange = onKeywordChange,
                modifier = Modifier.fillMaxWidth(),
                label = { Text("搜索论文、作者、关键词") },
                leadingIcon = {
                    Icon(
                        imageVector = Icons.Rounded.Search,
                        contentDescription = "搜索",
                    )
                },
            )
            FilterBlock(
                title = "领域",
                values = uiState.categories,
                selected = uiState.selectedCategory,
                labelMapper = { it },
                onClick = onCategorySelect,
            )
            FilterBlock(
                title = "时间",
                values = uiState.dayOptions,
                selected = uiState.selectedDays,
                labelMapper = { formatDays(it) },
                onClick = onDaysSelect,
            )
        }
    }
}

@Composable
private fun TrendSummaryCard(
    uiState: HomeUiState,
    onToggleSummary: () -> Unit,
    onDismissSummary: () -> Unit,
) {
    val spacing = MaterialTheme.xivSpacing
    Card(
        modifier = Modifier.fillMaxWidth(),
        shape = MaterialTheme.shapes.large,
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
        elevation = CardDefaults.cardElevation(defaultElevation = spacing.xs),
    ) {
        Column(
            modifier = Modifier.padding(horizontal = spacing.md, vertical = spacing.lg),
            verticalArrangement = Arrangement.spacedBy(spacing.md),
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                    Text(
                        text = "AI 趋势简报",
                        style = MaterialTheme.typography.titleMedium,
                        color = MaterialTheme.colorScheme.onSurface,
                    )
                    Text(
                        text = "最近 ${formatDays(uiState.selectedDays)} · ${uiState.selectedCategory}",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
                TextButton(onClick = onDismissSummary) {
                    Text("关闭")
                }
            }
            if (uiState.isSummaryLoading) {
                Text(
                    text = "趋势摘要加载中...",
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
                return@Column
            }
            val summary = uiState.trendSummary
            if (summary == null) {
                Text(
                    text = "暂无趋势摘要",
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
                return@Column
            }
            Surface(
                shape = MaterialTheme.shapes.medium,
                color = MaterialTheme.colorScheme.secondaryContainer,
            ) {
                Text(
                    text = summary.intro,
                    modifier = Modifier.padding(horizontal = spacing.md, vertical = spacing.sm),
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSecondaryContainer,
                )
            }
            if (uiState.summaryExpanded) {
                summary.items.forEach { item ->
                    Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                        Row(
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.spacedBy(spacing.xs),
                        ) {
                            StatusDot(color = XivDailyInfo)
                            Text(
                                text = "${item.rank}. ${item.trendTitle}",
                                style = MaterialTheme.typography.titleSmall,
                                color = MaterialTheme.colorScheme.onSurface,
                            )
                        }
                        Text(
                            text = item.summary,
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    }
                }
            }
            TextButton(onClick = onToggleSummary) {
                Text(if (uiState.summaryExpanded) "收起趋势详情" else "展开趋势详情")
            }
        }
    }
}

@Composable
private fun HomePaperCard(
    paper: PaperItem,
    onTranslate: () -> Unit,
    onFavorite: () -> Unit,
    onSyncToZotero: () -> Unit,
) {
    val spacing = MaterialTheme.xivSpacing
    Card(
        modifier = Modifier.fillMaxWidth(),
        shape = MaterialTheme.shapes.large,
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
        elevation = CardDefaults.cardElevation(defaultElevation = spacing.xs),
    ) {
        Column(
            modifier = Modifier.padding(horizontal = spacing.md, vertical = spacing.lg),
            verticalArrangement = Arrangement.spacedBy(spacing.sm),
        ) {
            Text(
                text = paper.title,
                style = MaterialTheme.typography.titleMedium,
                color = MaterialTheme.colorScheme.onSurface,
            )
            Text(
                text = paper.authors.joinToString(", "),
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            Surface(
                shape = MaterialTheme.shapes.medium,
                color = MaterialTheme.colorScheme.primaryContainer.copy(alpha = 0.6f),
            ) {
                Text(
                    text = "${paper.primaryCategory} · ${paper.publishedAt.take(10)} · Zotero ${paper.zoteroSyncState}",
                    modifier = Modifier.padding(horizontal = spacing.md, vertical = spacing.xs),
                    style = MaterialTheme.typography.labelMedium,
                    color = MaterialTheme.colorScheme.onPrimaryContainer,
                )
            }
            Text(
                text = paper.translatedSummary ?: paper.summary,
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurface,
            )
            Row(horizontalArrangement = Arrangement.spacedBy(spacing.xs)) {
                ActionButton(
                    icon = Icons.Rounded.Translate,
                    label = "翻译",
                    onClick = onTranslate,
                )
                ActionButton(
                    icon = Icons.Rounded.BookmarkBorder,
                    label = if (paper.favoriteState) "取消收藏" else "收藏",
                    onClick = onFavorite,
                )
                ActionButton(
                    icon = Icons.Rounded.Sync,
                    label = "同步",
                    onClick = onSyncToZotero,
                )
            }
        }
    }
}

@Composable
private fun InlineMessageCard(
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
        Text(
            text = message,
            modifier = Modifier.padding(horizontal = spacing.md, vertical = spacing.sm),
            style = MaterialTheme.typography.bodySmall,
            color = foreground,
        )
    }
}

@Composable
private fun EmptyStateCard(
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
            LeadingPill(icon = Icons.Rounded.AutoAwesome)
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
private fun SectionHeader(
    title: String,
    subtitle: String,
) {
    Column {
        Text(
            text = title,
            style = MaterialTheme.typography.titleLarge,
            color = MaterialTheme.colorScheme.onSurface,
        )
        Text(
            text = subtitle,
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
    }
}

@Composable
private fun ActionButton(
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    label: String,
    onClick: () -> Unit,
) {
    val spacing = MaterialTheme.xivSpacing
    Button(
        onClick = onClick,
        shape = MaterialTheme.shapes.medium,
        colors = ButtonDefaults.buttonColors(
            containerColor = MaterialTheme.colorScheme.primaryContainer,
            contentColor = MaterialTheme.colorScheme.onPrimaryContainer,
        ),
    ) {
        Icon(
            imageVector = icon,
            contentDescription = label,
            modifier = Modifier.size(16.dp),
        )
        Spacer(modifier = Modifier.size(spacing.xs))
        Text(text = label, style = MaterialTheme.typography.labelLarge)
    }
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun <T> FilterBlock(
    title: String,
    values: List<T>,
    selected: T,
    labelMapper: (T) -> String,
    onClick: (T) -> Unit,
) {
    val spacing = MaterialTheme.xivSpacing
    Column(verticalArrangement = Arrangement.spacedBy(spacing.xs)) {
        Text(
            text = title,
            style = MaterialTheme.typography.titleSmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        FlowRow(
            horizontalArrangement = Arrangement.spacedBy(spacing.xs),
            verticalArrangement = Arrangement.spacedBy(spacing.xs),
        ) {
            values.forEach { value ->
                FilterChip(
                    selected = selected == value,
                    onClick = { onClick(value) },
                    label = {
                        Text(
                            text = labelMapper(value),
                            style = MaterialTheme.typography.labelLarge,
                        )
                    },
                )
            }
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

@Composable
private fun StatusDot(color: Color) {
    Box(
        modifier = Modifier
            .size(8.dp)
            .background(color = color, shape = MaterialTheme.shapes.extraSmall),
    )
}

private fun formatDays(days: Int): String {
    return if (days == 1) "24h" else "$days 天"
}
