# Android DTO 与 Room 映射说明

本文件描述接口实体如何落到 Android 端的数据模型，确保 DTO、领域模型、Room 表结构和 ViewModel 状态闭环。
内容以当前真实实现为准，不记录尚未落地的理想字段。

## DTO 映射

- `PaperDto`
  - 对应后端 `Paper`。
  - 用于首页论文流、收藏前展示和同步前数据准备。
  - `translated_summary` 映射为 `PaperItem.translatedSummary`，可为空。
- `PaperQueryDto`
  - 对应后端 `PaperQuery`。
  - `days` 为 `Int?`；关键词全库搜索时允许为 `null`。
- `TrendSummaryDto`
  - 对应后端 `TrendSummary`。
  - 客户端只使用 `intro/items/status/warning`，后端的 `days/generated_at/dismissible` 当前不进入 Android 领域模型。
- `TranslationTaskDto`
  - 对应后端 `TranslationTask`。
  - 用于把单篇翻译结果写回当前首页 `PaperItem`。
- `IntegrationConfigDto`
  - 对应 `/config/integrations`。
  - 包含 Zotero 与 LLM 两段配置读模型，敏感字段统一为 `SecretFieldStateDto`。
- `ZoteroConfigSaveRequestDto`、`LlmConfigSaveRequestDto`
  - 对应设置页保存表单。
  - `apiKey=null` 表示保留已有密钥。
- `ConfigTestResultDto`
  - 对应 `/config/zotero/test` 和 `/config/llm/test`。
  - 只承载配置填写状态，不代表真实外部服务调用一定成功。
- `ZoteroSyncDto`、`BibtexExportResponseDto`
  - 对应收藏同步与 BibTeX 导出结果。

## Android 领域模型

- `PaperItem`
  - 首页和收藏卡片共用的论文展示模型。
  - 包含 `translatedSummary`、`favoriteState`、`zoteroSyncState`。
  - 不包含翻译加载、翻译错误、收藏动画提示等瞬态 UI 字段。
- `HomeUiState`
  - 负责首页瞬态状态。
  - `translatingPaperIds` 表示正在翻译的论文 ID 集合。
  - `translationErrors` 按论文 ID 保存翻译失败提示。
  - `actionMessage` 承载收藏、忽视、同步等底部浮层反馈。
- `FavoritePaperItem`
  - 聚合 `PaperItem` 与本地 `savedAt`。
  - 服务收藏库列表、批量选择、同步和导出。
- `IntegrationConfigStatus`
  - 聚合 `/config/integrations` 与 `/zotero/config/status` 的结果。
  - 只保存脱敏密钥展示值，不保存完整密钥。
- `UserPreferences`
  - DataStore 本地偏好模型。
  - 当前字段为 `defaultCategory/defaultDays/themeMode/hasSeenOnboarding/displayName/avatarPreset/avatarImageUri`。

## Room 表结构

### `favorite_papers`

当前真实实体为 `FavoritePaperEntity`，字段如下：

- `paperId`：TEXT PRIMARY KEY。
- `title`：TEXT NOT NULL。
- `authorsJson`：TEXT NOT NULL，当前用 `;;` 拼接作者。
- `summary`：TEXT NOT NULL。
- `publishedAt`：TEXT NOT NULL。
- `primaryCategory`：TEXT NOT NULL。
- `sourceUrl`：TEXT NOT NULL。
- `pdfUrl`：TEXT NOT NULL。
- `savedAt`：TEXT NOT NULL。
- `zoteroSyncState`：TEXT NOT NULL。

当前 Room 表不保存 `translatedSummary`、`updatedAt`、`categoriesJson` 或 Zotero message。
翻译结果只在首页论文流内存态展示，离线翻译缓存后续需要单独设计迁移。

## Repository 职责边界

`PaperRepository` 仍是当前唯一实现类，但对外契约已经拆成三类小接口：

- `HomePaperRepositoryContract`
  - 首页论文流、趋势摘要、摘要翻译、首页收藏切换和首页 Zotero 同步。
- `FavoritePaperRepositoryContract`
  - 收藏库观察、删除、批量删除、收藏同步和 BibTeX 导出。
- `IntegrationConfigRepositoryContract`
  - 读取、保存和测试 Zotero/LLM 配置。

本地偏好不走 `PaperRepository`，由 `UserPreferencesRepositoryContract` 独立负责。
ViewModel 只依赖自己需要的接口，避免设置页拿到论文流能力、收藏页拿到配置能力。

## 一致性要求

- DTO 字段命名以 `docs/openapi-draft.yaml` 与真实 FastAPI 模型为准。
- Room 枚举值必须与后端同步状态一致，目前使用 `not_synced/synced/failed`。
- 敏感字段只允许通过 `SecretFieldStateDto.configured/masked` 展示，不允许在 UI 状态中保存完整 key。
- 新增持久化字段时必须同步 Room migration、实体、Repository 映射和本文件。
