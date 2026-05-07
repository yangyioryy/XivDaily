package com.xivdaily.app.ui.screen

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.expandVertically
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
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
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.Send
import androidx.compose.material.icons.rounded.ArrowDropDown
import androidx.compose.material.icons.rounded.AutoAwesome
import androidx.compose.material.icons.rounded.Check
import androidx.compose.material.icons.rounded.Close
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.Checkbox
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.FilterChip
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.TextRange
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.TextFieldValue
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.xivdaily.app.data.model.FavoritePaperItem
import com.xivdaily.app.data.model.PaperChatMessage
import com.xivdaily.app.data.model.PaperChatUsedPaper
import com.xivdaily.app.ui.theme.XivDailyInfo
import com.xivdaily.app.ui.theme.XivDailySuccess
import com.xivdaily.app.ui.theme.XivDailyWarning
import com.xivdaily.app.ui.theme.xivSpacing
import com.xivdaily.app.ui.viewmodel.PaperChatUiState

@OptIn(ExperimentalLayoutApi::class)
@Composable
fun PaperChatScreen(
    uiState: PaperChatUiState,
    onTogglePaperSelection: (String) -> Unit,
    onInputChange: (String) -> Unit,
    onSendMessage: () -> Unit,
    onClearConversation: () -> Unit,
) {
    val spacing = MaterialTheme.xivSpacing
    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(MaterialTheme.colorScheme.background)
            .padding(horizontal = spacing.md),
        verticalArrangement = Arrangement.spacedBy(spacing.md),
    ) {
        Spacer(modifier = Modifier.height(spacing.xs))
        PaperChatHero(selectedCount = uiState.selectedPaperIds.size, onClearConversation = onClearConversation)
        PaperPicker(
            favorites = uiState.favorites,
            selectedIds = uiState.selectedPaperIds,
            onTogglePaperSelection = onTogglePaperSelection,
        )
        uiState.errorMessage?.let {
            FeedbackStrip(
                message = it,
                background = MaterialTheme.colorScheme.tertiaryContainer,
                foreground = MaterialTheme.colorScheme.onTertiaryContainer,
            )
        }
        uiState.warningMessage?.let {
            FeedbackStrip(
                message = it,
                background = MaterialTheme.colorScheme.secondaryContainer,
                foreground = MaterialTheme.colorScheme.onSecondaryContainer,
            )
        }
        UsedPaperStrip(usedPapers = uiState.usedPapers)
        LazyColumn(
            modifier = Modifier
                .weight(1f)
                .fillMaxWidth(),
            verticalArrangement = Arrangement.spacedBy(spacing.sm),
        ) {
            if (uiState.messages.isEmpty()) {
                item {
                    EmptyChatState()
                }
            } else {
                items(uiState.messages) { message ->
                    ChatBubble(message = message)
                }
            }
        }
        ChatInputBar(
            value = uiState.inputDraft,
            sending = uiState.isSending,
            onValueChange = onInputChange,
            onSend = onSendMessage,
        )
        Spacer(modifier = Modifier.height(spacing.xs))
    }
}

@Composable
private fun PaperChatHero(
    selectedCount: Int,
    onClearConversation: () -> Unit,
) {
    val spacing = MaterialTheme.xivSpacing
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(
                text = "论文对话",
                style = MaterialTheme.typography.titleLarge,
                color = MaterialTheme.colorScheme.onBackground,
            )
            Text(
                text = "已选 $selectedCount 篇 · 最多 3 篇",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
        Row(horizontalArrangement = Arrangement.spacedBy(spacing.xs), verticalAlignment = Alignment.CenterVertically) {
            TextButton(onClick = onClearConversation) {
                Icon(imageVector = Icons.Rounded.Close, contentDescription = "清空对话", modifier = Modifier.size(16.dp))
                Spacer(modifier = Modifier.size(spacing.xs))
                Text("清空")
            }
            LeadingPill()
        }
    }
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun PaperPicker(
    favorites: List<FavoritePaperItem>,
    selectedIds: Set<String>,
    onTogglePaperSelection: (String) -> Unit,
) {
    val spacing = MaterialTheme.xivSpacing
    var expanded by remember { mutableStateOf(false) }
    val selectedPapers = favorites.filter { it.paper.id in selectedIds }
    val selectedLabel = if (selectedPapers.isEmpty()) {
        "从 ${favorites.size} 篇收藏论文中选择"
    } else {
        "已选 ${selectedPapers.size} 篇：${selectedPapers.joinToString(" / ") { it.paper.title.take(12) }}"
    }
    Column(verticalArrangement = Arrangement.spacedBy(spacing.xs)) {
        Text(
            text = "收藏论文",
            style = MaterialTheme.typography.titleSmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        if (favorites.isEmpty()) {
            Text(
                text = "收藏库为空",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            return@Column
        }
        Box(modifier = Modifier.fillMaxWidth()) {
            OutlinedButton(
                onClick = { expanded = true },
                modifier = Modifier.fillMaxWidth(),
                shape = MaterialTheme.shapes.medium,
            ) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Text(
                        text = selectedLabel,
                        modifier = Modifier.weight(1f),
                        style = MaterialTheme.typography.labelLarge,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                    )
                    Icon(imageVector = Icons.Rounded.ArrowDropDown, contentDescription = "展开收藏论文")
                }
            }
            DropdownMenu(expanded = expanded, onDismissRequest = { expanded = false }) {
                favorites.forEach { favorite ->
                    val selected = favorite.paper.id in selectedIds
                    DropdownMenuItem(
                        leadingIcon = {
                            Checkbox(checked = selected, onCheckedChange = null)
                        },
                        text = {
                            Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
                                Text(
                                    text = favorite.paper.title,
                                    style = MaterialTheme.typography.bodyMedium,
                                    fontWeight = if (selected) FontWeight.Bold else FontWeight.Normal,
                                    maxLines = 2,
                                    overflow = TextOverflow.Ellipsis,
                                )
                                Text(
                                    text = "${favorite.paper.primaryCategory} · ${favorite.savedAt.take(10)}",
                                    style = MaterialTheme.typography.labelSmall,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                                )
                            }
                        },
                        onClick = { onTogglePaperSelection(favorite.paper.id) },
                    )
                }
            }
        }
        if (selectedPapers.isNotEmpty()) {
            FlowRow(
                horizontalArrangement = Arrangement.spacedBy(spacing.xs),
                verticalArrangement = Arrangement.spacedBy(spacing.xs),
            ) {
                selectedPapers.forEach { favorite ->
                    FilterChip(
                        selected = true,
                        onClick = { onTogglePaperSelection(favorite.paper.id) },
                        leadingIcon = {
                            Icon(
                                imageVector = Icons.Rounded.Check,
                                contentDescription = null,
                                modifier = Modifier.size(16.dp),
                            )
                        },
                        label = {
                            Text(
                                text = favorite.paper.title.take(18),
                                style = MaterialTheme.typography.labelMedium,
                                maxLines = 1,
                                overflow = TextOverflow.Ellipsis,
                            )
                        },
                    )
                }
            }
        }
    }
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun UsedPaperStrip(usedPapers: List<PaperChatUsedPaper>) {
    val spacing = MaterialTheme.xivSpacing
    AnimatedVisibility(visible = usedPapers.isNotEmpty(), enter = fadeIn() + expandVertically(), exit = fadeOut()) {
        FlowRow(
            horizontalArrangement = Arrangement.spacedBy(spacing.xs),
            verticalArrangement = Arrangement.spacedBy(spacing.xs),
        ) {
            usedPapers.forEach { paper ->
                StatusPill(label = contextStatusLabel(paper.status), status = paper.status)
            }
        }
    }
}

@Composable
private fun ChatBubble(message: PaperChatMessage) {
    val spacing = MaterialTheme.xivSpacing
    val isUser = message.role == "user"
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = if (isUser) Arrangement.End else Arrangement.Start,
    ) {
        Surface(
            modifier = Modifier.widthIn(max = 320.dp),
            shape = MaterialTheme.shapes.medium,
            color = if (isUser) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.surface,
            tonalElevation = if (isUser) 0.dp else 1.dp,
        ) {
            Text(
                text = message.content,
                modifier = Modifier.padding(horizontal = spacing.md, vertical = spacing.sm),
                style = MaterialTheme.typography.bodyMedium,
                color = if (isUser) MaterialTheme.colorScheme.onPrimary else MaterialTheme.colorScheme.onSurface,
            )
        }
    }
}

@Composable
private fun ChatInputBar(
    value: String,
    sending: Boolean,
    onValueChange: (String) -> Unit,
    onSend: () -> Unit,
) {
    var textFieldValue by remember { mutableStateOf(TextFieldValue(value)) }

    LaunchedEffect(value) {
        if (value != textFieldValue.text) {
            textFieldValue = TextFieldValue(
                text = value,
                selection = TextRange(value.length),
            )
        }
    }

    OutlinedTextField(
        value = textFieldValue,
        onValueChange = { next ->
            // TextFieldValue 会保留中文输入法的 composing 区间，避免重组时丢失候选态。
            textFieldValue = next
            if (next.text != value) {
                onValueChange(next.text)
            }
        },
        modifier = Modifier.fillMaxWidth(),
        label = { Text(if (sending) "正在整理论文材料..." else "向选中论文提问") },
        enabled = !sending,
        minLines = 1,
        maxLines = 4,
        keyboardOptions = KeyboardOptions(imeAction = ImeAction.Default),
        trailingIcon = {
            IconButton(onClick = onSend, enabled = !sending) {
                Icon(imageVector = Icons.AutoMirrored.Rounded.Send, contentDescription = "发送")
            }
        },
    )
}

@Composable
private fun EmptyChatState() {
    val spacing = MaterialTheme.xivSpacing
    Card(
        modifier = Modifier.fillMaxWidth(),
        shape = MaterialTheme.shapes.medium,
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
        elevation = CardDefaults.cardElevation(defaultElevation = 1.dp),
    ) {
        Text(
            text = "选择收藏论文后开始提问",
            modifier = Modifier.padding(horizontal = spacing.md, vertical = spacing.lg),
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
    }
}

@Composable
private fun FeedbackStrip(
    message: String,
    background: androidx.compose.ui.graphics.Color,
    foreground: androidx.compose.ui.graphics.Color,
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
private fun StatusPill(
    label: String,
    status: String,
) {
    val spacing = MaterialTheme.xivSpacing
    val color = when (status) {
        "full_text" -> XivDailySuccess
        "summary_fallback" -> XivDailyWarning
        else -> XivDailyInfo
    }
    Surface(shape = MaterialTheme.shapes.medium, color = MaterialTheme.colorScheme.surfaceVariant) {
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
            Text(text = label, style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
    }
}

@Composable
private fun LeadingPill() {
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
            imageVector = Icons.Rounded.AutoAwesome,
            contentDescription = null,
            tint = MaterialTheme.colorScheme.primary,
            modifier = Modifier.size(16.dp),
        )
    }
}

private fun contextStatusLabel(status: String): String {
    return when (status) {
        "full_text" -> "全文"
        "summary_fallback" -> "摘要降级"
        else -> "未读取"
    }
}
