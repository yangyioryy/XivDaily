package com.xivdaily.app.ui.screen

import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.animateContentSize
import androidx.compose.animation.expandVertically
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.shrinkVertically
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
import androidx.compose.material.icons.rounded.Add
import androidx.compose.material.icons.rounded.AutoAwesome
import androidx.compose.material.icons.rounded.Bookmark
import androidx.compose.material.icons.rounded.BookmarkBorder
import androidx.compose.material.icons.rounded.ChevronRight
import androidx.compose.material.icons.rounded.Close
import androidx.compose.material.icons.rounded.Notifications
import androidx.compose.material.icons.rounded.Refresh
import androidx.compose.material.icons.rounded.Search
import androidx.compose.material.icons.rounded.Star
import androidx.compose.material.icons.rounded.StarBorder
import androidx.compose.material.icons.rounded.Sync
import androidx.compose.material.icons.rounded.Translate
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.FilterChip
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Surface
import androidx.compose.material3.SwipeToDismissBox
import androidx.compose.material3.SwipeToDismissBoxValue
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.rememberSwipeToDismissBoxState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalUriHandler
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
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
    onKeywordSubmit: () -> Unit,
    onExitSearch: () -> Unit,
    onCategorySelect: (String) -> Unit,
    onShowAddTagDialog: () -> Unit,
    onHideAddTagDialog: () -> Unit,
    onCustomTagDraftChange: (String) -> Unit,
    onAddCustomTag: () -> Unit,
    onTagLongPress: (String) -> Unit,
    onClearTagPendingDeletion: () -> Unit,
    onDeleteCustomTag: (String) -> Unit,
    onDaysSelect: (Int) -> Unit,
    onDismissPaper: (PaperItem) -> Unit,
    onTranslate: (PaperItem) -> Unit,
    onFavorite: (PaperItem) -> Unit,
    onSyncToZotero: (PaperItem) -> Unit,
    onToggleSummary: () -> Unit,
    onTogglePaperAbstract: (String) -> Unit,
    onDismissSummary: () -> Unit,
    onRefresh: () -> Unit,
) {
    val spacing = MaterialTheme.xivSpacing
    val uriHandler = LocalUriHandler.current
    AddTagDialog(
        visible = uiState.isAddTagDialogVisible,
        value = uiState.customTagDraft,
        onValueChange = onCustomTagDraftChange,
        onDismiss = onHideAddTagDialog,
        onConfirm = onAddCustomTag,
    )
    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(MaterialTheme.colorScheme.background)
            .padding(horizontal = spacing.md),
    ) {
        LazyColumn(
            modifier = Modifier.fillMaxSize(),
            verticalArrangement = Arrangement.spacedBy(spacing.md),
        ) {
            item {
                Spacer(modifier = Modifier.height(spacing.xs))
                HomeHeroSection(uiState = uiState)
            }
            item {
                ExploreControlCard(
                    uiState = uiState,
                    onKeywordChange = onKeywordChange,
                    onKeywordSubmit = onKeywordSubmit,
                    onExitSearch = onExitSearch,
                    onCategorySelect = onCategorySelect,
                    onShowAddTagDialog = onShowAddTagDialog,
                    onTagLongPress = onTagLongPress,
                    onClearTagPendingDeletion = onClearTagPendingDeletion,
                    onDeleteCustomTag = onDeleteCustomTag,
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
            uiState.errorMessage?.let { message ->
                item {
                    InlineMessageCard(
                        message = message,
                        background = MaterialTheme.colorScheme.tertiaryContainer,
                        foreground = MaterialTheme.colorScheme.onTertiaryContainer,
                    )
                }
            }
            uiState.listWarning?.let { warning ->
                item {
                    InlineMessageCard(
                        message = warning,
                        background = MaterialTheme.colorScheme.secondaryContainer,
                        foreground = MaterialTheme.colorScheme.onSecondaryContainer,
                    )
                }
            }
            item {
                SectionHeader(
                    title = if (uiState.isLoading) "论文加载中..." else "论文列表",
                    subtitle = if (uiState.isSearchActive) {
                        "全 arXiv 搜索：${uiState.searchKeyword}，分类过滤：${uiState.selectedCategory}"
                    } else {
                        "围绕 ${uiState.selectedCategory} 的最新研究流"
                    },
                    actionLabel = "刷新",
                    onAction = onRefresh,
                )
            }
            if (uiState.papers.isEmpty()) {
                item {
                    EmptyStateCard(
                        title = resolveEmptyTitle(uiState),
                        subtitle = resolveEmptySubtitle(uiState),
                    )
                }
            }
            items(uiState.papers, key = { it.id }) { paper ->
                HomePaperCard(
                    paper = paper,
                    isTranslating = paper.id in uiState.translatingPaperIds,
                    translationError = uiState.translationErrors[paper.id],
                    isAbstractExpanded = paper.id in uiState.expandedAbstractPaperIds,
                    onOpenPaper = { uriHandler.openUri(paper.sourceUrl) },
                    onDismiss = { onDismissPaper(paper) },
                    onToggleAbstract = { onTogglePaperAbstract(paper.id) },
                    onTranslate = { onTranslate(paper) },
                    onFavorite = { onFavorite(paper) },
                    onSyncToZotero = { onSyncToZotero(paper) },
                )
            }
            item {
                Spacer(modifier = Modifier.height(spacing.xl))
            }
        }
        AnimatedVisibility(
            visible = uiState.actionMessage != null,
            modifier = Modifier
                .align(Alignment.BottomCenter)
                .padding(bottom = spacing.lg),
            enter = fadeIn() + expandVertically(),
            exit = fadeOut() + shrinkVertically(),
        ) {
            Surface(
                shape = MaterialTheme.shapes.medium,
                color = MaterialTheme.colorScheme.inverseSurface,
                tonalElevation = spacing.xs,
            ) {
                Text(
                    text = uiState.actionMessage?.text.orEmpty(),
                    modifier = Modifier.padding(horizontal = spacing.lg, vertical = spacing.sm),
                    style = MaterialTheme.typography.labelLarge,
                    color = MaterialTheme.colorScheme.inverseOnSurface,
                )
            }
        }
    }
}

@Composable
private fun HomeHeroSection(uiState: HomeUiState) {
    val spacing = MaterialTheme.xivSpacing
    Column(
        modifier = Modifier.fillMaxWidth(),
        verticalArrangement = Arrangement.spacedBy(spacing.sm),
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(
                text = "首页",
                style = MaterialTheme.typography.titleLarge,
                color = MaterialTheme.colorScheme.onBackground,
            )
            LeadingPill(icon = Icons.Rounded.Notifications)
        }
        Text(
            text = if (uiState.isSearchActive) {
                "正在全 arXiv 搜索“${uiState.searchKeyword}”，时间筛选不会缩小搜索范围。"
            } else {
                "围绕当天筛选范围快速浏览、收藏和同步论文。"
            },
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
    }
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun ExploreControlCard(
    uiState: HomeUiState,
    onKeywordChange: (String) -> Unit,
    onKeywordSubmit: () -> Unit,
    onExitSearch: () -> Unit,
    onCategorySelect: (String) -> Unit,
    onShowAddTagDialog: () -> Unit,
    onTagLongPress: (String) -> Unit,
    onClearTagPendingDeletion: () -> Unit,
    onDeleteCustomTag: (String) -> Unit,
    onDaysSelect: (Int) -> Unit,
) {
    val spacing = MaterialTheme.xivSpacing
    Column(
        modifier = Modifier.fillMaxWidth(),
        verticalArrangement = Arrangement.spacedBy(spacing.sm),
    ) {
        OutlinedTextField(
            value = uiState.searchKeywordDraft,
            onValueChange = onKeywordChange,
            modifier = Modifier.fillMaxWidth(),
            label = { Text("搜索论文、作者、关键词") },
            singleLine = true,
            keyboardOptions = KeyboardOptions(imeAction = ImeAction.Search),
            keyboardActions = KeyboardActions(onSearch = { onKeywordSubmit() }),
            leadingIcon = {
                Icon(
                    imageVector = Icons.Rounded.Search,
                    contentDescription = "搜索",
                )
            },
            trailingIcon = {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    if (uiState.isSearchActive) {
                        IconButton(onClick = onExitSearch) {
                            Icon(
                                imageVector = Icons.Rounded.Close,
                                contentDescription = "退出搜索",
                            )
                        }
                    }
                    TextButton(onClick = onKeywordSubmit) {
                        Text("搜索")
                    }
                }
            },
        )
        TagFilterBlock(
            title = "领域",
            values = uiState.allTags,
            selected = uiState.selectedCategory,
            customTags = uiState.customTags,
            pendingDeletionTag = uiState.tagPendingDeletion,
            onClick = onCategorySelect,
            onLongClick = onTagLongPress,
            onClearPending = onClearTagPendingDeletion,
            onDelete = onDeleteCustomTag,
            onAddClick = onShowAddTagDialog,
        )
        if (uiState.isSearchActive) {
            Surface(
                shape = MaterialTheme.shapes.medium,
                color = MaterialTheme.colorScheme.secondaryContainer,
            ) {
                Text(
                    text = "关键词搜索覆盖全 arXiv；领域只做结果过滤，时间 Pills 只影响无关键词列表。",
                    modifier = Modifier.padding(horizontal = spacing.md, vertical = spacing.sm),
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSecondaryContainer,
                )
            }
        } else {
            if (uiState.isCustomTagSelected) {
                Surface(
                    shape = MaterialTheme.shapes.medium,
                    color = MaterialTheme.colorScheme.secondaryContainer,
                ) {
                    Text(
                        text = "自定义标签会用关键词在全 arXiv 召回论文，适合 embodied-ai 这类研究方向。",
                        modifier = Modifier.padding(horizontal = spacing.md, vertical = spacing.sm),
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSecondaryContainer,
                    )
                }
            }
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
private fun AddTagDialog(
    visible: Boolean,
    value: String,
    onValueChange: (String) -> Unit,
    onDismiss: () -> Unit,
    onConfirm: () -> Unit,
) {
    if (!visible) {
        return
    }
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("添加自定义标签") },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                Text(
                    text = "输入研究方向，例如 embodied-ai。标签会作为关键词检索论文。",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
                OutlinedTextField(
                    value = value,
                    onValueChange = onValueChange,
                    modifier = Modifier.fillMaxWidth(),
                    label = { Text("标签名称") },
                    singleLine = true,
                )
            }
        },
        confirmButton = {
            TextButton(onClick = onConfirm) {
                Text("添加")
            }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) {
                Text("取消")
            }
        },
    )
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
        shape = MaterialTheme.shapes.medium,
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.primaryContainer.copy(alpha = 0.55f)),
        elevation = CardDefaults.cardElevation(defaultElevation = 0.dp),
    ) {
        Column(
            modifier = Modifier
                .padding(horizontal = spacing.md, vertical = spacing.md)
                .animateContentSize(),
            verticalArrangement = Arrangement.spacedBy(spacing.sm),
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
                        text = "最近 3 天 · ${uiState.selectedCategory}",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
                TextButton(onClick = onDismissSummary) { Text("关闭") }
            }
            if (uiState.isSummaryLoading) {
                Text(
                    text = "趋势摘要加载中...",
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
                return@Column
            }
            uiState.trendErrorMessage?.let { message ->
                Surface(
                    shape = MaterialTheme.shapes.medium,
                    color = MaterialTheme.colorScheme.tertiaryContainer,
                ) {
                    Text(
                        text = message,
                        modifier = Modifier.padding(horizontal = spacing.md, vertical = spacing.sm),
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onTertiaryContainer,
                    )
                }
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
            Surface(shape = MaterialTheme.shapes.medium, color = MaterialTheme.colorScheme.surface.copy(alpha = 0.75f)) {
                Text(
                    text = summary.intro,
                    modifier = Modifier.padding(horizontal = spacing.md, vertical = spacing.sm),
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSecondaryContainer,
                )
            }
            // 趋势详情只做轻量展开/收起，避免打断首页连续浏览节奏。
            AnimatedVisibility(
                visible = uiState.summaryExpanded,
                enter = fadeIn() + expandVertically(),
                exit = fadeOut() + shrinkVertically(),
            ) {
                Column(verticalArrangement = Arrangement.spacedBy(spacing.sm)) {
                    summary.items.forEach { item ->
                        val representativeTitles = item.representativePaperIds.mapNotNull { paperId ->
                            uiState.papers.firstOrNull { it.id == paperId }?.title
                        }
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
                            if (representativeTitles.isNotEmpty()) {
                                Text(
                                    text = "代表论文：${representativeTitles.joinToString(" / ")}",
                                    style = MaterialTheme.typography.labelMedium,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                                )
                            }
                        }
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
@OptIn(ExperimentalFoundationApi::class, ExperimentalLayoutApi::class)
private fun HomePaperCard(
    paper: PaperItem,
    isTranslating: Boolean,
    translationError: String?,
    isAbstractExpanded: Boolean,
    onOpenPaper: () -> Unit,
    onDismiss: () -> Unit,
    onToggleAbstract: () -> Unit,
    onTranslate: () -> Unit,
    onFavorite: () -> Unit,
    onSyncToZotero: () -> Unit,
) {
    val spacing = MaterialTheme.xivSpacing
    val dismissState = rememberSwipeToDismissBoxState(
        positionalThreshold = { distance -> distance * 0.35f },
        confirmValueChange = { value ->
            when (value) {
                SwipeToDismissBoxValue.StartToEnd -> {
                    // 右滑只触发同步提示，不直接把卡片从列表中移除。
                    onSyncToZotero()
                    false
                }
                SwipeToDismissBoxValue.EndToStart -> true
                SwipeToDismissBoxValue.Settled -> true
            }
        },
    )
    LaunchedEffect(dismissState.currentValue) {
        if (dismissState.currentValue == SwipeToDismissBoxValue.EndToStart) {
            onDismiss()
        }
    }
    SwipeToDismissBox(
        state = dismissState,
        backgroundContent = {
            SwipeHintBackground(
                dismissValue = dismissState.dismissDirection,
                isSettled = dismissState.currentValue == SwipeToDismissBoxValue.Settled,
            )
        },
        content = {
            Card(
                modifier = Modifier
                    .fillMaxWidth()
                    .animateContentSize()
                    .combinedClickable(
                        onClick = onOpenPaper,
                        onDoubleClick = onFavorite,
                    ),
                shape = MaterialTheme.shapes.medium,
                colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
                elevation = CardDefaults.cardElevation(defaultElevation = 1.dp),
            ) {
                Column(
                    modifier = Modifier.padding(horizontal = spacing.md, vertical = spacing.md),
                    verticalArrangement = Arrangement.spacedBy(spacing.sm),
                ) {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.Top,
                    ) {
                        Text(
                            text = paper.title,
                            modifier = Modifier.weight(1f),
                            style = MaterialTheme.typography.titleSmall,
                            color = MaterialTheme.colorScheme.onSurface,
                        )
                        Icon(
                            imageVector = if (paper.favoriteState) Icons.Rounded.Star else Icons.Rounded.StarBorder,
                            contentDescription = if (paper.favoriteState) "已收藏" else "未收藏",
                            tint = XivDailyWarning,
                            modifier = Modifier.size(20.dp),
                        )
                    }
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
                    AnimatedVisibility(
                        visible = isAbstractExpanded,
                        enter = fadeIn() + expandVertically(),
                        exit = fadeOut() + shrinkVertically(),
                    ) {
                        Column(verticalArrangement = Arrangement.spacedBy(spacing.xs)) {
                            if (paper.translatedSummary.isNullOrBlank()) {
                                OriginalSummaryBlock(paper = paper)
                            } else {
                                BilingualSummaryBlock(paper = paper)
                            }
                            when {
                                isTranslating -> TranslationStateBlock(text = "摘要翻译中...")
                                translationError != null -> TranslationStateBlock(text = translationError)
                            }
                        }
                    }
                    FlowRow(
                        horizontalArrangement = Arrangement.spacedBy(spacing.xs),
                        verticalArrangement = Arrangement.spacedBy(spacing.xs),
                    ) {
                        ActionButton(
                            icon = Icons.Rounded.ChevronRight,
                            label = if (isAbstractExpanded) "收起摘要" else "展开摘要",
                            onClick = onToggleAbstract,
                        )
                        if (isAbstractExpanded) {
                            ActionButton(
                                icon = Icons.Rounded.Translate,
                                label = "翻译",
                                onClick = onTranslate,
                            )
                        }
                        ActionButton(
                            icon = Icons.Rounded.BookmarkBorder,
                            label = if (paper.favoriteState) "取消收藏" else "收藏",
                            onClick = onFavorite,
                        )
                        if (paper.zoteroSyncState != "synced") {
                            ActionButton(
                                icon = Icons.Rounded.Sync,
                                label = "同步",
                                onClick = onSyncToZotero,
                            )
                        }
                    }
                }
            }
        },
    )
}

@Composable
private fun SwipeHintBackground(
    dismissValue: SwipeToDismissBoxValue,
    isSettled: Boolean,
) {
    val spacing = MaterialTheme.xivSpacing
    val (background, foreground, icon, text, alignment) = when {
        isSettled || dismissValue == SwipeToDismissBoxValue.Settled -> {
            SwipeHintVisual(
                background = MaterialTheme.colorScheme.surfaceVariant,
                foreground = MaterialTheme.colorScheme.onSurfaceVariant,
                icon = Icons.Rounded.ChevronRight,
                text = "左右滑动可触发快捷操作",
                alignment = Alignment.Center,
            )
        }
        dismissValue == SwipeToDismissBoxValue.StartToEnd -> {
            SwipeHintVisual(
                background = XivDailySuccess.copy(alpha = 0.18f),
                foreground = XivDailySuccess,
                icon = Icons.Rounded.Sync,
                text = "右滑执行 Zotero 同步",
                alignment = Alignment.CenterStart,
            )
        }
        else -> {
            SwipeHintVisual(
                background = XivDailyWarning.copy(alpha = 0.18f),
                foreground = XivDailyWarning,
                icon = Icons.Rounded.ChevronRight,
                text = "左滑移出当前流",
                alignment = Alignment.CenterEnd,
            )
        }
    }
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .background(color = background, shape = MaterialTheme.shapes.medium)
            .padding(horizontal = spacing.md, vertical = spacing.md),
        contentAlignment = alignment,
    ) {
        Row(
            horizontalArrangement = Arrangement.spacedBy(spacing.xs),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Icon(
                imageVector = icon,
                contentDescription = null,
                tint = foreground,
            )
            Text(
                text = text,
                style = MaterialTheme.typography.labelLarge,
                color = foreground,
            )
        }
    }
}

private data class SwipeHintVisual(
    val background: Color,
    val foreground: Color,
    val icon: androidx.compose.ui.graphics.vector.ImageVector,
    val text: String,
    val alignment: Alignment,
)

@Composable
private fun TranslationStateBlock(text: String) {
    val spacing = MaterialTheme.xivSpacing
    Surface(
        shape = MaterialTheme.shapes.medium,
        color = MaterialTheme.colorScheme.secondaryContainer,
    ) {
        Text(
            text = text,
            modifier = Modifier.padding(horizontal = spacing.md, vertical = spacing.sm),
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSecondaryContainer,
        )
    }
}

@Composable
private fun OriginalSummaryBlock(paper: PaperItem) {
    val spacing = MaterialTheme.xivSpacing
    Column(verticalArrangement = Arrangement.spacedBy(spacing.xs)) {
        Text(
            text = "Original Abstract",
            style = MaterialTheme.typography.labelLarge,
            color = MaterialTheme.colorScheme.primary,
        )
        Text(
            text = paper.summary,
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
    }
}

@Composable
private fun BilingualSummaryBlock(paper: PaperItem) {
    val spacing = MaterialTheme.xivSpacing
    Column(verticalArrangement = Arrangement.spacedBy(spacing.xs)) {
        Text(
            text = "中文翻译",
            style = MaterialTheme.typography.labelLarge,
            color = MaterialTheme.colorScheme.primary,
        )
        Text(
            text = paper.translatedSummary.orEmpty(),
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurface,
        )
        Text(
            text = "Original Abstract",
            style = MaterialTheme.typography.labelLarge,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        Text(
            text = paper.summary,
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
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
        shape = MaterialTheme.shapes.medium,
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
    ) {
        Column(
            modifier = Modifier.padding(horizontal = spacing.md, vertical = spacing.lg),
            verticalArrangement = Arrangement.spacedBy(spacing.xs),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            LeadingPill(icon = Icons.Rounded.AutoAwesome)
            Text(
                text = title,
                style = MaterialTheme.typography.titleSmall,
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
    actionLabel: String? = null,
    onAction: (() -> Unit)? = null,
) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Column {
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
        if (actionLabel != null && onAction != null) {
            TextButton(onClick = onAction) {
                Icon(
                    imageVector = Icons.Rounded.Refresh,
                    contentDescription = actionLabel,
                    modifier = Modifier.size(16.dp),
                )
                Spacer(modifier = Modifier.size(MaterialTheme.xivSpacing.xs))
                Text(actionLabel)
            }
        }
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

@OptIn(ExperimentalFoundationApi::class, ExperimentalLayoutApi::class)
@Composable
private fun TagFilterBlock(
    title: String,
    values: List<String>,
    selected: String,
    customTags: List<String>,
    pendingDeletionTag: String?,
    onClick: (String) -> Unit,
    onLongClick: (String) -> Unit,
    onClearPending: () -> Unit,
    onDelete: (String) -> Unit,
    onAddClick: () -> Unit,
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
            values.forEach { tag ->
                val isSelected = selected == tag
                val pendingDeletion = pendingDeletionTag == tag
                Surface(
                    modifier = Modifier.combinedClickable(
                        onClick = {
                            if (pendingDeletion) {
                                onClearPending()
                            } else {
                                onClick(tag)
                            }
                        },
                        onLongClick = { onLongClick(tag) },
                    ),
                    shape = MaterialTheme.shapes.medium,
                    color = if (isSelected) {
                        MaterialTheme.colorScheme.primary
                    } else if (pendingDeletion) {
                        MaterialTheme.colorScheme.tertiaryContainer
                    } else {
                        MaterialTheme.colorScheme.surface
                    },
                    tonalElevation = if (isSelected) 2.dp else 0.dp,
                ) {
                    Row(
                        modifier = Modifier.padding(horizontal = spacing.sm, vertical = spacing.xs),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(spacing.xs),
                    ) {
                        Text(
                            text = tag,
                            style = MaterialTheme.typography.labelLarge,
                            color = if (isSelected) {
                                MaterialTheme.colorScheme.onPrimary
                            } else {
                                MaterialTheme.colorScheme.onSurface
                            },
                        )
                        if (pendingDeletion && tag in customTags) {
                            // 固定删除按钮尺寸，避免长按后 chip 宽度突然跳动。
                            Box(
                                modifier = Modifier
                                    .size(22.dp)
                                    .background(
                                        color = MaterialTheme.colorScheme.errorContainer,
                                        shape = MaterialTheme.shapes.extraSmall,
                                    )
                                    .combinedClickable(onClick = { onDelete(tag) }),
                                contentAlignment = Alignment.Center,
                            ) {
                                Text(
                                    text = "-",
                                    style = MaterialTheme.typography.labelMedium,
                                    color = MaterialTheme.colorScheme.onErrorContainer,
                                )
                            }
                        }
                    }
                }
            }
            Surface(
                modifier = Modifier.combinedClickable(onClick = onAddClick),
                shape = MaterialTheme.shapes.medium,
                color = MaterialTheme.colorScheme.surface,
                tonalElevation = 0.dp,
            ) {
                Row(
                    modifier = Modifier.padding(horizontal = spacing.sm, vertical = spacing.xs),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(spacing.xs),
                ) {
                    Icon(
                        imageVector = Icons.Rounded.Add,
                        contentDescription = "添加标签",
                        modifier = Modifier.size(16.dp),
                    )
                    Text(text = "添加", style = MaterialTheme.typography.labelLarge)
                }
            }
        }
    }
}

@Composable
private fun LeadingPill(icon: androidx.compose.ui.graphics.vector.ImageVector) {
    Box(
        modifier = Modifier
            .size(32.dp)
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
            modifier = Modifier.size(16.dp),
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

private fun resolveEmptyTitle(uiState: HomeUiState): String {
    if (uiState.isLoading) {
        return "正在刷新论文列表"
    }
    return when (uiState.listStatus) {
        "unavailable" -> "当前暂时无法获取论文"
        else -> "当前暂无可展示论文"
    }
}

private fun resolveEmptySubtitle(uiState: HomeUiState): String {
    if (uiState.isLoading) {
        return "稍后将自动填充最新内容"
    }
    return when (uiState.emptyReason) {
        "time_window_filtered" -> "当前时间窗口过窄，可以尝试切换到 7 天或 30 天。"
        "no_results" -> "当前搜索条件下没有命中论文，可以切换领域或重新搜索。"
        else -> if (uiState.listStatus == "unavailable") {
            "请稍后重试，或先检查本地网络与服务状态。"
        } else {
            "可以切换领域、时间窗口或重新搜索"
        }
    }
}
