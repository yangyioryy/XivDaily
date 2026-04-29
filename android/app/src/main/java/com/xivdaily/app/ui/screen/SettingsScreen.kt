package com.xivdaily.app.ui.screen

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.xivdaily.app.ui.viewmodel.SettingsUiState

@Composable
fun SettingsScreen(
    uiState: SettingsUiState,
    onToggleTheme: () -> Unit,
    onToggleZoteroConfigured: () -> Unit,
    onToggleLlmConfigured: () -> Unit,
) {
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
                SettingRow("默认关注领域", uiState.defaultCategory)
                Spacer(modifier = Modifier.height(8.dp))
                SettingRow("默认时间窗口", "${uiState.defaultDays} Days")
            }
        }
        item {
            SettingsGroup(title = "集成配置") {
                SettingRow("Zotero 配置", if (uiState.zoteroConfigured) "已配置" else "未配置")
                Spacer(modifier = Modifier.height(8.dp))
                SettingRow("大模型 API 配置", if (uiState.llmConfigured) "已配置" else "未配置")
            }
        }
        item {
            SettingsGroup(title = "外观") {
                Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                    Text(text = "深色模式")
                    Switch(checked = uiState.themeMode == "dark", onCheckedChange = { onToggleTheme() })
                }
            }
        }
        item {
            Button(onClick = {
                onToggleZoteroConfigured()
                onToggleLlmConfigured()
            }) {
                Text("刷新配置状态")
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
