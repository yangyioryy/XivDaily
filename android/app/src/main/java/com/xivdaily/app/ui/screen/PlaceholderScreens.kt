package com.xivdaily.app.ui.screen

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.FilterChip
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.getValue
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp

@OptIn(ExperimentalLayoutApi::class)
@Composable
fun HomeScreen() {
    var keyword by remember { mutableStateOf("") }
    var selectedCategory by remember { mutableStateOf("cs.CV") }
    var selectedDays by remember { mutableStateOf(3) }
    val categories = listOf("cs.CV", "cs.LG", "cs.AI", "cs.CL")
    val dayOptions = listOf(1, 3, 7, 30)
    val papers = remember {
        listOf(
            "VideoCrafter2: Data Limitations for High-Quality Video Diffusion Models",
            "InternVL 2.5: A Unified Multi-modal Model with Enhanced Performance",
            "Consistency Models are Fast, Stable and Data-efficient",
        )
    }

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
                value = keyword,
                onValueChange = { keyword = it },
                modifier = Modifier.fillMaxWidth(),
                label = { Text("搜索论文、作者、关键词") },
            )
        }
        item {
            FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                categories.forEach { category ->
                    FilterChip(
                        selected = category == selectedCategory,
                        onClick = { selectedCategory = category },
                        label = { Text(category) },
                    )
                }
            }
        }
        item {
            FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                dayOptions.forEach { day ->
                    FilterChip(
                        selected = day == selectedDays,
                        onClick = { selectedDays = day },
                        label = { Text(if (day == 1) "24h" else "${day} Days") },
                    )
                }
            }
        }
        item {
            Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface)) {
                Column(modifier = Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text(text = "AI 趋势简报（最近 $selectedDays 天）", fontWeight = FontWeight.Bold)
                    Text(text = "基于当前筛选条件生成的 AI 总结。")
                    Text(text = "1. 视觉生成模型持续突破")
                    Text(text = "2. 多模态大模型统一理解与生成能力提升")
                    Text(text = "3. 开放模型高效化与可控化成为新焦点")
                }
            }
        }
        item {
            Text(text = "论文列表", style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold)
        }
        items(papers.filter { it.contains(keyword, ignoreCase = true) || keyword.isBlank() }) { title ->
            Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface)) {
                Column(modifier = Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text(text = title, fontWeight = FontWeight.SemiBold)
                    Text(text = "$selectedCategory · 最近 $selectedDays 天")
                    Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                        Text(text = "翻译", modifier = Modifier.clickable { })
                        Text(text = "收藏", modifier = Modifier.clickable { })
                        Text(text = "同步至 Zotero", modifier = Modifier.clickable { })
                    }
                }
            }
        }
    }
}

@Composable
fun LibraryScreen() {
    val selectedIds = remember { mutableStateListOf<String>() }
    val items = remember {
        listOf(
            "2401.00001|已同步|Segment Anything Model",
            "2401.00002|未同步|DINOv2: Learning Robust Visual Features",
            "2401.00003|同步失败|ControlNet: Adding Conditional Control",
        )
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
                Text(text = "已选 ${selectedIds.size} 项")
                Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                    Text(text = "导出 BibTeX", modifier = Modifier.clickable { })
                    Text(text = "删除", modifier = Modifier.clickable { })
                }
            }
        }
        items(items) { raw ->
            val parts = raw.split("|")
            val paperId = parts[0]
            val status = parts[1]
            val title = parts[2]
            val selected = selectedIds.contains(paperId)
            Card(
                colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
                modifier = Modifier.clickable {
                    if (selected) selectedIds.remove(paperId) else selectedIds.add(paperId)
                },
            ) {
                Column(modifier = Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text(text = title, fontWeight = FontWeight.SemiBold)
                    Text(text = "状态：$status")
                    Text(text = if (selected) "已加入批量选择" else "点击加入批量选择")
                }
            }
        }
    }
}

@Composable
fun SettingsScreen() {
    var useDarkMode by remember { mutableStateOf(false) }
    var defaultCategory by remember { mutableStateOf("cs.CV") }
    var defaultDays by remember { mutableStateOf("3 Days") }
    var zoteroConfigured by remember { mutableStateOf(true) }
    var llmConfigured by remember { mutableStateOf(false) }

    LazyColumn(
        modifier = Modifier
            .fillMaxSize()
            .background(MaterialTheme.colorScheme.background)
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        item {
            Text(text = "设置", style = MaterialTheme.typography.headlineMedium, fontWeight = FontWeight.Bold)
        }
        item {
            SettingsGroup(title = "偏好设置") {
                SettingRow("默认关注领域", defaultCategory)
                Spacer(modifier = Modifier.height(8.dp))
                SettingRow("默认时间窗口", defaultDays)
            }
        }
        item {
            SettingsGroup(title = "集成配置") {
                SettingRow("Zotero 配置", if (zoteroConfigured) "已配置" else "未配置")
                Spacer(modifier = Modifier.height(8.dp))
                SettingRow("大模型 API 配置", if (llmConfigured) "已配置" else "未配置")
            }
        }
        item {
            SettingsGroup(title = "外观") {
                Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                    Text(text = "深色模式")
                    Switch(checked = useDarkMode, onCheckedChange = { useDarkMode = it })
                }
            }
        }
        item {
            Button(onClick = { zoteroConfigured = !zoteroConfigured; llmConfigured = !llmConfigured }) {
                Text("切换配置状态")
            }
        }
    }
}

@Composable
private fun SettingsGroup(title: String, content: @Composable () -> Unit) {
    Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface)) {
        Column(modifier = Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Text(text = title, fontWeight = FontWeight.Bold)
            content()
        }
    }
}

@Composable
private fun SettingRow(label: String, value: String) {
    Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
        Text(text = label)
        Text(text = value)
    }
}
