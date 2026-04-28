# Android DTO 与 Room 映射说明

本文件描述接口实体如何落到 Android 端的数据模型，确保 DTO、领域模型和
Room 表结构闭环。

## DTO 映射

- `PaperDto`
  - 对应后端 `Paper`
  - 用于首页、收藏详情、导出前展示
- `TrendSummaryDto`
  - 对应后端 `TrendSummary`
  - 用于首页 AI 趋势卡片
- `UserPreferenceDto`
  - 对应后端 `UserPreference`
  - 用于设置页启动时的默认值填充
- `TranslationTaskDto`
  - 对应后端 `TranslationTask`
  - 用于单篇翻译结果显示
- `SyncRecordDto`
  - 对应后端 `SyncRecord`
  - 用于收藏页和首页同步状态提示

## Room 表结构建议

### favorite_papers

- `paper_id` TEXT PRIMARY KEY
- `title` TEXT NOT NULL
- `authors_json` TEXT NOT NULL
- `summary` TEXT NOT NULL
- `translated_summary` TEXT NULL
- `published_at` TEXT NOT NULL
- `updated_at` TEXT NOT NULL
- `primary_category` TEXT NOT NULL
- `categories_json` TEXT NOT NULL
- `source_url` TEXT NOT NULL
- `pdf_url` TEXT NOT NULL
- `saved_at` TEXT NOT NULL
- `zotero_sync_state` TEXT NOT NULL
- `zotero_message` TEXT NULL

说明：
- Room 实体首版直接冗余必要展示字段，避免离线场景还依赖远端接口。
- `authors_json` 与 `categories_json` 首版可通过 TypeConverter 或 JSON 字符串保存。

### translation_cache

- `paper_id` TEXT PRIMARY KEY
- `translated_summary` TEXT NOT NULL
- `status` TEXT NOT NULL
- `requested_at` TEXT NOT NULL
- `warning` TEXT NULL

说明：
- 用于避免同一论文重复点翻译时频繁请求后端。

## Android 领域模型建议

- `PaperCardModel`
  - 面向 UI，聚合展示字段、收藏态、同步态和翻译态
- `LibrarySelectionState`
  - 只服务收藏页批量选择，不直接参与网络 DTO
- `SettingsUiState`
  - 由 `UserPreferenceDto` 与本地 DataStore 合成

## 一致性要求

- DTO 字段命名保持与 OpenAPI 草案一致。
- Room 枚举值必须与后端 `ZoteroSyncState` 完全一致。
- 新增字段时先改 OpenAPI 草案，再同步 DTO 与 Room 设计。
