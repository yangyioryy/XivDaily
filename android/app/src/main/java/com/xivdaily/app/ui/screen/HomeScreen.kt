package com.xivdaily.app.ui.screen

import androidx.compose.foundation.background
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
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.xivdaily.app.data.model.PaperItem
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
    LazyColumn(
        modifier = Modifier
            .fillMaxSize()
            .background(MaterialTheme.colorScheme.background)
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        item {
            Text(text = "首页", style = MaterialTheme.typography.headlineMedium, fontWeight = FontWeight.Bold)
        }
        item {
            OutlinedTextField(
                value = uiState.searchKeyword,
                onValueChange = onKeywordChange,
                modifier = Modifier.fillMaxWidth(),
                label = { Text("搜索论文、作者、关键词") },
            )
        }
        item {
            FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                uiState.categories.forEach { category ->
                    FilterChip(
                        selected = category == uiState.selectedCategory,
                        onClick = { onCategorySelect(category) },
                        label = { Text(category) },
                    )
                }
            }
        }
        item {
            FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                uiState.dayOptions.forEach { day ->
                    FilterChip(
                        selected = day == uiState.selectedDays,
                        onClick = { onDaysSelect(day) },
                        label = { Text(if (day == 1) "24h" else "${day} Days") },
                    )
                }
            }
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
            item { Text(text = message, color = MaterialTheme.colorScheme.primary) }
        }
        uiState.errorMessage?.let { message ->
            item { Text(text = message, color = MaterialTheme.colorScheme.error) }
        }
        item {
            Text(text = if (uiState.isLoading) "论文加载中..." else "论文列表", style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold)
        }
        items(uiState.papers, key = { it.id }) { paper ->
            PaperCard(
                paper = paper,
                onTranslate = { onTranslate(paper) },
                onFavorite = { onFavorite(paper) },
                onSyncToZotero = { onSyncToZotero(paper) },
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
    Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface)) {
        Column(modifier = Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                Text(text = "AI 趋势简报（最近 ${uiState.selectedDays} 天）", fontWeight = FontWeight.Bold)
                TextButton(onClick = onDismissSummary) { Text("关闭") }
            }
            if (uiState.isSummaryLoading) {
                Text("趋势摘要加载中...")
                return@Column
            }
            val summary = uiState.trendSummary
            if (summary == null) {
                Text("暂无趋势摘要")
                return@Column
            }
            Text(text = summary.intro)
            if (uiState.summaryExpanded) {
                summary.items.forEach { item ->
                    Text(text = "${item.rank}. ${item.trendTitle}", fontWeight = FontWeight.SemiBold)
                    Text(text = item.summary)
                }
            }
            TextButton(onClick = onToggleSummary) {
                Text(if (uiState.summaryExpanded) "收起" else "展开")
            }
        }
    }
}

@Composable
private fun PaperCard(
    paper: PaperItem,
    onTranslate: () -> Unit,
    onFavorite: () -> Unit,
    onSyncToZotero: () -> Unit,
) {
    Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface)) {
        Column(modifier = Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Text(text = paper.title, fontWeight = FontWeight.SemiBold)
            Text(text = paper.authors.joinToString(", "))
            Text(text = "${paper.primaryCategory} · ${paper.publishedAt.take(10)} · Zotero: ${paper.zoteroSyncState}")
            Text(text = paper.translatedSummary ?: paper.summary, style = MaterialTheme.typography.bodyMedium)
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                Button(onClick = onTranslate) { Text("翻译") }
                Button(onClick = onFavorite) { Text(if (paper.favoriteState) "取消收藏" else "收藏") }
                Button(onClick = onSyncToZotero) { Text("同步 Zotero") }
            }
        }
    }
}
