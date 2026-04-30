package com.xivdaily.app.ui.screen

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.animation.animateContentSize
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.AutoAwesome
import androidx.compose.material.icons.rounded.ChevronRight
import androidx.compose.material.icons.rounded.DarkMode
import androidx.compose.material.icons.rounded.DeleteSweep
import androidx.compose.material.icons.rounded.Edit
import androidx.compose.material.icons.rounded.Info
import androidx.compose.material.icons.rounded.Language
import androidx.compose.material.icons.rounded.Palette
import androidx.compose.material.icons.rounded.Schedule
import androidx.compose.material.icons.rounded.Science
import androidx.compose.material.icons.rounded.Sync
import androidx.compose.material.icons.rounded.Update
import androidx.compose.material.icons.rounded.Widgets
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.FilterChip
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.xivdaily.app.BuildConfig
import com.xivdaily.app.ui.theme.XivDailyDanger
import com.xivdaily.app.ui.theme.XivDailySuccess
import com.xivdaily.app.ui.theme.XivDailyWarning
import com.xivdaily.app.ui.theme.xivSpacing
import com.xivdaily.app.ui.viewmodel.SettingsUiState

@Composable
fun SettingsScreen(
    uiState: SettingsUiState,
    onShowThemePicker: () -> Unit,
    onHideThemePicker: () -> Unit,
    onSelectThemeMode: (String) -> Unit,
    onShowLanguagePicker: () -> Unit,
    onHideLanguagePicker: () -> Unit,
    onSelectLanguage: (String) -> Unit,
    onShowZoteroDetailDialog: () -> Unit,
    onHideZoteroDetailDialog: () -> Unit,
    onUpdateZoteroUserId: (String) -> Unit,
    onUpdateZoteroLibraryType: (String) -> Unit,
    onUpdateZoteroApiKey: (String) -> Unit,
    onUpdateZoteroCollection: (String) -> Unit,
    onSaveZoteroConfig: () -> Unit,
    onTestZoteroConfig: () -> Unit,
    onShowLlmDetailDialog: () -> Unit,
    onHideLlmDetailDialog: () -> Unit,
    onUpdateLlmBaseUrl: (String) -> Unit,
    onUpdateLlmApiKey: (String) -> Unit,
    onUpdateLlmModel: (String) -> Unit,
    onSaveLlmConfig: () -> Unit,
    onTestLlmConfig: () -> Unit,
    onUpdateDefaultCategory: (String) -> Unit,
    onUpdateDefaultDays: (Int) -> Unit,
    onShowUpdateDialog: () -> Unit,
    onHideUpdateDialog: () -> Unit,
    onShowAboutDialog: () -> Unit,
    onHideAboutDialog: () -> Unit,
    onShowProfileDialog: () -> Unit,
    onHideProfileDialog: () -> Unit,
    onUpdateProfile: (String, String) -> Unit,
    onShowClearCacheDialog: () -> Unit,
    onHideClearCacheDialog: () -> Unit,
    onConfirmClearCache: () -> Unit,
    onRefreshConfigStatus: () -> Unit,
) {
    val spacing = MaterialTheme.xivSpacing
    SettingsDialogs(
        uiState = uiState,
        onHideThemePicker = onHideThemePicker,
        onSelectThemeMode = onSelectThemeMode,
        onHideLanguagePicker = onHideLanguagePicker,
        onSelectLanguage = onSelectLanguage,
        onHideZoteroDetailDialog = onHideZoteroDetailDialog,
        onUpdateZoteroUserId = onUpdateZoteroUserId,
        onUpdateZoteroLibraryType = onUpdateZoteroLibraryType,
        onUpdateZoteroApiKey = onUpdateZoteroApiKey,
        onUpdateZoteroCollection = onUpdateZoteroCollection,
        onSaveZoteroConfig = onSaveZoteroConfig,
        onTestZoteroConfig = onTestZoteroConfig,
        onHideLlmDetailDialog = onHideLlmDetailDialog,
        onUpdateLlmBaseUrl = onUpdateLlmBaseUrl,
        onUpdateLlmApiKey = onUpdateLlmApiKey,
        onUpdateLlmModel = onUpdateLlmModel,
        onSaveLlmConfig = onSaveLlmConfig,
        onTestLlmConfig = onTestLlmConfig,
        onHideUpdateDialog = onHideUpdateDialog,
        onHideAboutDialog = onHideAboutDialog,
        onHideProfileDialog = onHideProfileDialog,
        onUpdateProfile = onUpdateProfile,
        onHideClearCacheDialog = onHideClearCacheDialog,
        onConfirmClearCache = onConfirmClearCache,
    )
    LazyColumn(
        modifier = Modifier
            .fillMaxSize()
            .background(MaterialTheme.colorScheme.background)
            .padding(horizontal = spacing.md),
        verticalArrangement = Arrangement.spacedBy(spacing.lg),
    ) {
        item {
            Spacer(modifier = Modifier.height(spacing.xs))
            SettingsHeroSection()
        }
        item {
            ProfileCard(
                displayName = uiState.displayName,
                avatarPreset = uiState.avatarPreset,
                onClick = onShowProfileDialog,
            )
        }
        item {
            SettingsSection(
                title = "偏好设置",
                rows = listOf(
                    {
                        PreferenceChipsRow(
                            icon = Icons.Rounded.Widgets,
                            title = "默认关注领域",
                            summary = uiState.defaultCategory,
                            values = listOf("cs.CV", "cs.LG", "cs.AI", "cs.CL"),
                            selectedValue = uiState.defaultCategory,
                            labelMapper = { it },
                            onValueClick = onUpdateDefaultCategory,
                        )
                    },
                    {
                        PreferenceChipsRow(
                            icon = Icons.Rounded.Schedule,
                            title = "默认时间窗口",
                            summary = formatDays(uiState.defaultDays),
                            values = listOf(1, 3, 7, 30),
                            selectedValue = uiState.defaultDays,
                            labelMapper = { formatDays(it) },
                            onValueClick = onUpdateDefaultDays,
                        )
                    },
                    {
                        SettingsActionRow(
                            icon = Icons.Rounded.Language,
                            title = "语言",
                            subtitle = "文章摘要与界面默认语言",
                            value = languageLabel(uiState.language),
                            onClick = onShowLanguagePicker,
                        )
                    },
                ),
            )
        }
        item {
            SettingsSection(
                title = "集成配置",
                rows = listOf(
                    {
                        IntegrationStatusRow(
                            icon = Icons.Rounded.Science,
                            title = "Zotero 配置",
                            subtitle = zoteroSubtitle(uiState),
                            value = zoteroCollectionBadge(uiState),
                            configured = uiState.zoteroConfigured,
                            failed = uiState.integrationStatusFailed,
                            onClick = onShowZoteroDetailDialog,
                        )
                    },
                    {
                        IntegrationStatusRow(
                            icon = Icons.Rounded.AutoAwesome,
                            title = "大模型配置",
                            subtitle = integrationSubtitle(
                                configured = uiState.llmConfigured,
                                failed = uiState.integrationStatusFailed,
                                successText = "摘要翻译与趋势总结可用",
                                idleText = "摘要翻译和总结暂不可用",
                            ),
                            value = if (uiState.llmConfigured) "已启用" else "未启用",
                            configured = uiState.llmConfigured,
                            failed = uiState.integrationStatusFailed,
                            onClick = onShowLlmDetailDialog,
                        )
                    },
                ),
            )
        }
        item {
            SettingsSection(
                title = "外观",
                rows = listOf(
                    {
                        SettingsActionRow(
                            icon = Icons.Rounded.DarkMode,
                            title = "主题模式",
                            subtitle = "支持浅色、深色与跟随系统",
                            value = themeModeLabel(uiState.themeMode),
                            highlighted = true,
                            onClick = onShowThemePicker,
                        )
                    },
                    {
                        SettingsActionRow(
                            icon = Icons.Rounded.Palette,
                            title = "字体大小",
                            subtitle = "当前版本采用统一阅读字号体系",
                            value = "标准",
                            enabled = false,
                        )
                    },
                ),
            )
        }
        item {
            SettingsSection(
                title = "其他",
                rows = listOf(
                    {
                        SettingsActionRow(
                            icon = Icons.Rounded.DeleteSweep,
                            title = "清除缓存",
                            subtitle = "清理本地缓存的列表与摘要内容",
                            value = uiState.cacheStatusText,
                            onClick = onShowClearCacheDialog,
                        )
                    },
                    {
                        SettingsActionRow(
                            icon = Icons.Rounded.Update,
                            title = "检查更新",
                            subtitle = "查看当前版本与后续更新说明",
                            value = "v${BuildConfig.VERSION_NAME}",
                            onClick = onShowUpdateDialog,
                        )
                    },
                    {
                        SettingsActionRow(
                            icon = Icons.Rounded.Info,
                            title = "关于我们",
                            subtitle = "了解 XivDaily 的定位与版本信息",
                            onClick = onShowAboutDialog,
                        )
                    },
                ),
            )
        }
        uiState.actionMessage?.let { message ->
            item {
                FeedbackBanner(
                    message = message,
                    background = MaterialTheme.colorScheme.primaryContainer,
                    foreground = MaterialTheme.colorScheme.onPrimaryContainer,
                )
            }
        }
        uiState.errorMessage?.let { message ->
            item {
                FeedbackBanner(
                    message = message,
                    background = MaterialTheme.colorScheme.tertiaryContainer,
                    foreground = MaterialTheme.colorScheme.onTertiaryContainer,
                )
            }
        }
        item {
            Button(
                onClick = onRefreshConfigStatus,
                modifier = Modifier.fillMaxWidth(),
                shape = MaterialTheme.shapes.medium,
                colors = ButtonDefaults.buttonColors(
                    containerColor = MaterialTheme.colorScheme.surface,
                    contentColor = MaterialTheme.colorScheme.primary,
                ),
            ) {
                Icon(
                    imageVector = Icons.Rounded.Sync,
                    contentDescription = "刷新配置状态",
                    modifier = Modifier.size(18.dp),
                )
                Spacer(modifier = Modifier.size(spacing.xs))
                Text(text = "刷新配置状态", style = MaterialTheme.typography.labelLarge)
            }
        }
        item {
            Button(
                onClick = {},
                enabled = false,
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(bottom = spacing.xl),
                shape = MaterialTheme.shapes.medium,
                colors = ButtonDefaults.outlinedButtonColors(
                    containerColor = MaterialTheme.colorScheme.background,
                    contentColor = XivDailyDanger,
                ),
                border = ButtonDefaults.outlinedButtonBorder.copy(
                    brush = androidx.compose.ui.graphics.SolidColor(XivDailyDanger.copy(alpha = 0.4f)),
                ),
            ) {
                Text(
                    text = "退出登录（即将开放）",
                    style = MaterialTheme.typography.labelLarge,
                    color = XivDailyDanger,
                )
            }
        }
    }
}

@Composable
private fun ProfileCard(
    displayName: String,
    avatarPreset: String,
    onClick: () -> Unit,
) {
    val spacing = MaterialTheme.xivSpacing
    Card(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick),
        shape = MaterialTheme.shapes.large,
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
        elevation = CardDefaults.cardElevation(defaultElevation = 2.dp),
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .animateContentSize()
                .padding(horizontal = spacing.md, vertical = spacing.lg),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(spacing.md),
        ) {
            Box(
                modifier = Modifier
                    .size(64.dp)
                    .clip(CircleShape)
                    .background(MaterialTheme.colorScheme.primaryContainer)
                    .border(1.dp, MaterialTheme.colorScheme.outline.copy(alpha = 0.35f), CircleShape),
                contentAlignment = Alignment.Center,
            ) {
                Text(
                    text = avatarPresetToGlyph(avatarPreset),
                    style = MaterialTheme.typography.titleLarge,
                    color = MaterialTheme.colorScheme.onPrimaryContainer,
                )
            }
            Column(
                modifier = Modifier.weight(1f),
                verticalArrangement = Arrangement.spacedBy(2.dp),
            ) {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(spacing.xs),
                ) {
                    Text(
                        text = displayName,
                        style = MaterialTheme.typography.titleMedium,
                        color = MaterialTheme.colorScheme.onSurface,
                    )
                    Icon(
                        imageVector = Icons.Rounded.Edit,
                        contentDescription = "编辑资料",
                        tint = MaterialTheme.colorScheme.onSurfaceVariant,
                        modifier = Modifier.size(18.dp),
                    )
                }
                Text(
                    text = avatarPresetToSubtitle(avatarPreset),
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
            Icon(
                imageVector = Icons.Rounded.ChevronRight,
                contentDescription = "进入个人资料",
                tint = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
    }
}

@Composable
private fun SettingsSection(
    title: String,
    rows: List<@Composable () -> Unit>,
) {
    val spacing = MaterialTheme.xivSpacing
    Column(verticalArrangement = Arrangement.spacedBy(spacing.sm)) {
        Text(
            text = title,
            style = MaterialTheme.typography.titleSmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        Card(
            modifier = Modifier.fillMaxWidth(),
            shape = MaterialTheme.shapes.large,
            colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
            elevation = CardDefaults.cardElevation(defaultElevation = 2.dp),
        ) {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .animateContentSize()
            ) {
                rows.forEachIndexed { index, row ->
                    row()
                    if (index != rows.lastIndex) {
                        Box(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(start = 56.dp, end = 18.dp)
                                .height(1.dp)
                                .background(MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.9f)),
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun PreferenceChipsRow(
    icon: ImageVector,
    title: String,
    summary: String,
    values: List<String>,
    selectedValue: String,
    labelMapper: (String) -> String,
    onValueClick: (String) -> Unit,
) {
    val spacing = MaterialTheme.xivSpacing
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = spacing.md, vertical = spacing.md),
        verticalArrangement = Arrangement.spacedBy(spacing.sm),
    ) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(spacing.sm),
        ) {
            LeadingIcon(icon = icon)
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = title,
                    style = MaterialTheme.typography.titleSmall,
                    color = MaterialTheme.colorScheme.onSurface,
                )
                Text(
                    text = summary,
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
        }
        Row(horizontalArrangement = Arrangement.spacedBy(spacing.xs)) {
            values.forEach { value ->
                FilterChip(
                    selected = selectedValue == value,
                    onClick = { onValueClick(value) },
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
private fun PreferenceChipsRow(
    icon: ImageVector,
    title: String,
    summary: String,
    values: List<Int>,
    selectedValue: Int,
    labelMapper: (Int) -> String,
    onValueClick: (Int) -> Unit,
) {
    val spacing = MaterialTheme.xivSpacing
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = spacing.md, vertical = spacing.md),
        verticalArrangement = Arrangement.spacedBy(spacing.sm),
    ) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(spacing.sm),
        ) {
            LeadingIcon(icon = icon)
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = title,
                    style = MaterialTheme.typography.titleSmall,
                    color = MaterialTheme.colorScheme.onSurface,
                )
                Text(
                    text = summary,
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
        }
        Row(horizontalArrangement = Arrangement.spacedBy(spacing.xs)) {
            values.forEach { value ->
                FilterChip(
                    selected = selectedValue == value,
                    onClick = { onValueClick(value) },
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
private fun SettingsActionRow(
    icon: ImageVector,
    title: String,
    subtitle: String,
    value: String? = null,
    highlighted: Boolean = false,
    enabled: Boolean = true,
    onClick: (() -> Unit)? = null,
) {
    val spacing = MaterialTheme.xivSpacing
    val clickable = onClick != null && enabled
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .then(
                if (clickable) {
                    Modifier.clickable(onClick = onClick)
                } else {
                    Modifier
                }
            )
            .padding(horizontal = spacing.md, vertical = spacing.md),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(spacing.sm),
    ) {
        LeadingIcon(
            icon = icon,
            background = if (highlighted) MaterialTheme.colorScheme.primaryContainer else MaterialTheme.colorScheme.surfaceVariant,
            tint = if (highlighted) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurfaceVariant,
        )
        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = title,
                style = MaterialTheme.typography.titleSmall,
                color = if (enabled) MaterialTheme.colorScheme.onSurface else MaterialTheme.colorScheme.onSurfaceVariant,
            )
            Text(
                text = subtitle,
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
        value?.let {
            Text(
                text = it,
                style = MaterialTheme.typography.labelLarge,
                color = if (enabled) MaterialTheme.colorScheme.onSurfaceVariant else MaterialTheme.colorScheme.outline,
                textAlign = TextAlign.End,
            )
        }
        if (enabled) {
            Icon(
                imageVector = Icons.Rounded.ChevronRight,
                contentDescription = null,
                tint = if (clickable) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
    }
}

@Composable
private fun IntegrationStatusRow(
    icon: ImageVector,
    title: String,
    subtitle: String,
    value: String,
    configured: Boolean,
    failed: Boolean,
    onClick: () -> Unit,
) {
    val spacing = MaterialTheme.xivSpacing
    val statusColor = when {
        failed -> XivDailyDanger
        configured -> XivDailySuccess
        else -> XivDailyWarning
    }
    val statusText = when {
        failed -> "异常"
        configured -> "已配置"
        else -> "未配置"
    }
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick)
            .padding(horizontal = spacing.md, vertical = spacing.md),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(spacing.sm),
    ) {
        LeadingIcon(icon = icon)
        Column(modifier = Modifier.weight(1f)) {
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
        Text(
            text = value,
            style = MaterialTheme.typography.labelMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            textAlign = TextAlign.End,
        )
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(6.dp),
        ) {
            Text(
                text = statusText,
                style = MaterialTheme.typography.labelLarge,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            Box(
                modifier = Modifier
                    .size(8.dp)
                    .clip(CircleShape)
                    .background(statusColor),
            )
        }
        Icon(
            imageVector = Icons.Rounded.ChevronRight,
            contentDescription = null,
            tint = MaterialTheme.colorScheme.onSurfaceVariant,
        )
    }
}

@Composable
private fun FeedbackBanner(
    message: String,
    background: Color,
    foreground: Color,
) {
    val spacing = MaterialTheme.xivSpacing
    Surface(
        modifier = Modifier.fillMaxWidth(),
        shape = MaterialTheme.shapes.medium,
        color = background,
        tonalElevation = spacing.xxs,
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
private fun SettingsHeroSection() {
    val spacing = MaterialTheme.xivSpacing
    Column(
        modifier = Modifier.fillMaxWidth(),
        verticalArrangement = Arrangement.spacedBy(spacing.sm),
    ) {
        Text(
            text = "设置",
            style = MaterialTheme.typography.headlineLarge,
            color = MaterialTheme.colorScheme.onBackground,
        )
        Text(
            text = "把偏好、集成和资料卡收成更接近参考图的轻量设置页。",
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
    }
}

@Composable
private fun LeadingIcon(
    icon: ImageVector,
    background: Color = MaterialTheme.colorScheme.surfaceVariant,
    tint: Color = MaterialTheme.colorScheme.onSurfaceVariant,
) {
    Box(
        modifier = Modifier
            .size(36.dp)
            .clip(MaterialTheme.shapes.small)
            .background(background),
        contentAlignment = Alignment.Center,
    ) {
        Icon(
            imageVector = icon,
            contentDescription = null,
            tint = tint,
            modifier = Modifier.size(18.dp),
        )
    }
}

private fun formatDays(days: Int): String {
    return if (days == 1) "24h" else "$days 天"
}

private fun themeModeLabel(themeMode: String): String {
    return when (themeMode) {
        "dark" -> "深色"
        "light" -> "浅色"
        else -> "跟随系统"
    }
}

private fun languageLabel(language: String): String {
    return when (language) {
        "en-US" -> "English"
        else -> "简体中文"
    }
}

private fun integrationSubtitle(
    configured: Boolean,
    failed: Boolean,
    successText: String,
    idleText: String,
): String {
    return when {
        failed -> "状态刷新异常，请稍后重试"
        configured -> successText
        else -> idleText
    }
}

private fun zoteroCollectionBadge(uiState: SettingsUiState): String {
    return when (uiState.zoteroTargetCollectionStatus) {
        "created" -> "已创建"
        "ready" -> "已就绪"
        "error" -> "异常"
        "not_configured" -> "未配置"
        else -> "待确认"
    }
}

private fun zoteroSubtitle(uiState: SettingsUiState): String {
    return when {
        uiState.integrationStatusFailed -> "状态刷新异常，请稍后重试"
        uiState.zoteroConfigured -> "统一归档到 ${uiState.zoteroTargetCollectionName}"
        else -> "尚未连接参考文献库"
    }
}

private fun buildZoteroDetailMessage(uiState: SettingsUiState): String {
    return buildString {
        appendLine("配置状态：${if (uiState.zoteroConfigured) "已配置" else "未配置"}")
        appendLine("目标集合：${uiState.zoteroTargetCollectionName}")
        appendLine("集合状态：${zoteroCollectionBadge(uiState)}")
        appendLine("库类型：${uiState.zoteroLibraryType ?: "未知"}")
        append("用户 ID：${uiState.zoteroUserId ?: "未提供"}")
        uiState.zoteroTargetCollectionKey?.takeIf { it.isNotBlank() }?.let { key ->
            appendLine()
            append("集合 Key：$key")
        }
    }
}

@Composable
private fun SettingsDialogs(
    uiState: SettingsUiState,
    onHideThemePicker: () -> Unit,
    onSelectThemeMode: (String) -> Unit,
    onHideLanguagePicker: () -> Unit,
    onSelectLanguage: (String) -> Unit,
    onHideZoteroDetailDialog: () -> Unit,
    onUpdateZoteroUserId: (String) -> Unit,
    onUpdateZoteroLibraryType: (String) -> Unit,
    onUpdateZoteroApiKey: (String) -> Unit,
    onUpdateZoteroCollection: (String) -> Unit,
    onSaveZoteroConfig: () -> Unit,
    onTestZoteroConfig: () -> Unit,
    onHideLlmDetailDialog: () -> Unit,
    onUpdateLlmBaseUrl: (String) -> Unit,
    onUpdateLlmApiKey: (String) -> Unit,
    onUpdateLlmModel: (String) -> Unit,
    onSaveLlmConfig: () -> Unit,
    onTestLlmConfig: () -> Unit,
    onHideUpdateDialog: () -> Unit,
    onHideAboutDialog: () -> Unit,
    onHideProfileDialog: () -> Unit,
    onUpdateProfile: (String, String) -> Unit,
    onHideClearCacheDialog: () -> Unit,
    onConfirmClearCache: () -> Unit,
) {
    if (uiState.isThemePickerVisible) {
        OptionDialog(
            title = "选择主题模式",
            options = listOf("system" to "跟随系统", "light" to "浅色", "dark" to "深色"),
            selectedValue = uiState.themeMode,
            onDismiss = onHideThemePicker,
            onSelect = onSelectThemeMode,
        )
    }
    if (uiState.isLanguagePickerVisible) {
        OptionDialog(
            title = "选择语言",
            options = listOf("zh-CN" to "简体中文"),
            selectedValue = uiState.language,
            onDismiss = onHideLanguagePicker,
            onSelect = onSelectLanguage,
        )
    }
    if (uiState.isUpdateDialogVisible) {
        MessageDialog(
            title = "检查更新",
            message = "当前版本：v${BuildConfig.VERSION_NAME}\n最新版本：v${BuildConfig.VERSION_NAME}\n更新时间：今天\n当前已经是最新版本。",
            onDismiss = onHideUpdateDialog,
        )
    }
    if (uiState.isAboutDialogVisible) {
        MessageDialog(
            title = "关于 XivDaily",
            message = "XivDaily 是面向研究阅读场景的每日论文工作台。\n当前版本聚焦首页流、收藏同步和趋势摘要体验。",
            onDismiss = onHideAboutDialog,
        )
    }
    if (uiState.isProfileDialogVisible) {
        ProfileEditorDialog(
            displayName = uiState.displayName,
            avatarPreset = uiState.avatarPreset,
            onDismiss = onHideProfileDialog,
            onConfirm = onUpdateProfile,
        )
    }
    if (uiState.isClearCacheDialogVisible) {
        AlertDialog(
            onDismissRequest = onHideClearCacheDialog,
            title = { Text("确认清理缓存") },
            text = { Text("将清理首页列表与趋势提示缓存反馈，不影响收藏库与偏好设置。") },
            confirmButton = {
                TextButton(onClick = onConfirmClearCache) {
                    Text("开始清理")
                }
            },
            dismissButton = {
                TextButton(onClick = onHideClearCacheDialog) {
                    Text("取消")
                }
            },
        )
    }
    if (uiState.isZoteroDetailDialogVisible) {
        ZoteroConfigDialog(
            uiState = uiState,
            onDismiss = onHideZoteroDetailDialog,
            onUserIdChange = onUpdateZoteroUserId,
            onLibraryTypeChange = onUpdateZoteroLibraryType,
            onApiKeyChange = onUpdateZoteroApiKey,
            onCollectionChange = onUpdateZoteroCollection,
            onSave = onSaveZoteroConfig,
            onTest = onTestZoteroConfig,
        )
    }
    if (uiState.isLlmDetailDialogVisible) {
        LlmConfigDialog(
            uiState = uiState,
            onDismiss = onHideLlmDetailDialog,
            onBaseUrlChange = onUpdateLlmBaseUrl,
            onApiKeyChange = onUpdateLlmApiKey,
            onModelChange = onUpdateLlmModel,
            onSave = onSaveLlmConfig,
            onTest = onTestLlmConfig,
        )
    }
}

@Composable
private fun ZoteroConfigDialog(
    uiState: SettingsUiState,
    onDismiss: () -> Unit,
    onUserIdChange: (String) -> Unit,
    onLibraryTypeChange: (String) -> Unit,
    onApiKeyChange: (String) -> Unit,
    onCollectionChange: (String) -> Unit,
    onSave: () -> Unit,
    onTest: () -> Unit,
) {
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("Zotero 配置") },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                OutlinedTextField(
                    value = uiState.zoteroUserIdDraft,
                    onValueChange = onUserIdChange,
                    modifier = Modifier.fillMaxWidth(),
                    label = { Text("User ID / Group ID") },
                    singleLine = true,
                )
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    listOf("user" to "个人库", "group" to "群组库").forEach { (value, label) ->
                        FilterChip(
                            selected = uiState.zoteroLibraryTypeDraft == value,
                            onClick = { onLibraryTypeChange(value) },
                            label = { Text(label) },
                        )
                    }
                }
                OutlinedTextField(
                    value = uiState.zoteroApiKeyDraft,
                    onValueChange = onApiKeyChange,
                    modifier = Modifier.fillMaxWidth(),
                    label = { Text("API Key") },
                    placeholder = { Text(uiState.zoteroApiKeyMasked ?: "保存后仅脱敏显示") },
                    visualTransformation = PasswordVisualTransformation(),
                    singleLine = true,
                )
                OutlinedTextField(
                    value = uiState.zoteroTargetCollectionNameDraft,
                    onValueChange = onCollectionChange,
                    modifier = Modifier.fillMaxWidth(),
                    label = { Text("目标集合名称") },
                    singleLine = true,
                )
            }
        },
        confirmButton = {
            TextButton(enabled = !uiState.isConfigBusy, onClick = onSave) {
                Text(if (uiState.isConfigBusy) "保存中..." else "保存")
            }
        },
        dismissButton = {
            Row {
                TextButton(enabled = !uiState.isConfigBusy, onClick = onTest) {
                    Text("测试")
                }
                TextButton(onClick = onDismiss) {
                    Text("取消")
                }
            }
        },
    )
}

@Composable
private fun LlmConfigDialog(
    uiState: SettingsUiState,
    onDismiss: () -> Unit,
    onBaseUrlChange: (String) -> Unit,
    onApiKeyChange: (String) -> Unit,
    onModelChange: (String) -> Unit,
    onSave: () -> Unit,
    onTest: () -> Unit,
) {
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("大模型 API 配置") },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                OutlinedTextField(
                    value = uiState.llmBaseUrlDraft,
                    onValueChange = onBaseUrlChange,
                    modifier = Modifier.fillMaxWidth(),
                    label = { Text("Base URL") },
                    singleLine = true,
                )
                OutlinedTextField(
                    value = uiState.llmModelDraft,
                    onValueChange = onModelChange,
                    modifier = Modifier.fillMaxWidth(),
                    label = { Text("Model") },
                    singleLine = true,
                )
                OutlinedTextField(
                    value = uiState.llmApiKeyDraft,
                    onValueChange = onApiKeyChange,
                    modifier = Modifier.fillMaxWidth(),
                    label = { Text("API Key") },
                    placeholder = { Text(uiState.llmApiKeyMasked ?: "保存后仅脱敏显示") },
                    visualTransformation = PasswordVisualTransformation(),
                    singleLine = true,
                )
            }
        },
        confirmButton = {
            TextButton(enabled = !uiState.isConfigBusy, onClick = onSave) {
                Text(if (uiState.isConfigBusy) "保存中..." else "保存")
            }
        },
        dismissButton = {
            Row {
                TextButton(enabled = !uiState.isConfigBusy, onClick = onTest) {
                    Text("测试")
                }
                TextButton(onClick = onDismiss) {
                    Text("取消")
                }
            }
        },
    )
}

@Composable
private fun OptionDialog(
    title: String,
    options: List<Pair<String, String>>,
    selectedValue: String,
    onDismiss: () -> Unit,
    onSelect: (String) -> Unit,
) {
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(title) },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                options.forEach { (value, label) ->
                    SettingsActionRow(
                        icon = if (selectedValue == value) Icons.Rounded.AutoAwesome else Icons.Rounded.ChevronRight,
                        title = label,
                        subtitle = if (selectedValue == value) "当前已选中" else "点击切换到该选项",
                        enabled = true,
                        onClick = { onSelect(value) },
                    )
                }
            }
        },
        confirmButton = {
            TextButton(onClick = onDismiss) {
                Text("关闭")
            }
        },
    )
}

@Composable
private fun MessageDialog(
    title: String,
    message: String,
    onDismiss: () -> Unit,
) {
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(title) },
        text = { Text(message) },
        confirmButton = {
            TextButton(onClick = onDismiss) {
                Text("知道了")
            }
        },
    )
}

@Composable
private fun ProfileEditorDialog(
    displayName: String,
    avatarPreset: String,
    onDismiss: () -> Unit,
    onConfirm: (String, String) -> Unit,
) {
    var draftName by remember(displayName) { mutableStateOf(displayName) }
    var draftAvatar by remember(avatarPreset) { mutableStateOf(avatarPreset) }
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("编辑个人资料") },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                OutlinedTextField(
                    value = draftName,
                    onValueChange = { draftName = it },
                    modifier = Modifier.fillMaxWidth(),
                    label = { Text("用户名") },
                    singleLine = true,
                )
                Text(
                    text = "头像预设",
                    style = MaterialTheme.typography.titleSmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    listOf(
                        "study" to "学者",
                        "spark" to "灵感",
                        "orbit" to "探索",
                    ).forEach { (value, label) ->
                        FilterChip(
                            selected = draftAvatar == value,
                            onClick = { draftAvatar = value },
                            label = { Text(label) },
                        )
                    }
                }
            }
        },
        confirmButton = {
            TextButton(onClick = { onConfirm(draftName, draftAvatar) }) {
                Text("保存")
            }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) {
                Text("取消")
            }
        },
    )
}

private fun avatarPresetToGlyph(avatarPreset: String): String {
    return when (avatarPreset) {
        "spark" -> "灵"
        "orbit" -> "研"
        else -> "学"
    }
}

private fun avatarPresetToSubtitle(avatarPreset: String): String {
    return when (avatarPreset) {
        "spark" -> "保持研究灵感在线"
        "orbit" -> "围绕主题持续追踪"
        else -> "保持每日研究敏感度"
    }
}
