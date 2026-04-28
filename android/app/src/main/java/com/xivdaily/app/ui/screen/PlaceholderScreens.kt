package com.xivdaily.app.ui.screen

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp

@Composable
fun HomeScreen() {
    ScreenShell(title = "首页", description = "这里后续承载筛选、趋势摘要和论文流。")
}

@Composable
fun LibraryScreen() {
    ScreenShell(title = "收藏库", description = "这里后续承载离线收藏、同步状态和批量导出。")
}

@Composable
fun SettingsScreen() {
    ScreenShell(title = "设置", description = "这里后续承载默认领域、时间窗口和集成配置。")
}

@Composable
private fun ScreenShell(title: String, description: String) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(24.dp),
        verticalArrangement = Arrangement.Center,
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface)) {
            Column(modifier = Modifier.padding(24.dp)) {
                Text(text = title, style = MaterialTheme.typography.headlineMedium)
                Text(text = description, style = MaterialTheme.typography.bodyMedium)
            }
        }
    }
}

