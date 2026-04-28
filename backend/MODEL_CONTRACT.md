# 后端模型合同说明

本文件约束后端后续实现时的数据模型命名和职责，避免实现阶段偏离
`docs/openapi-draft.yaml`。

## 推荐模块划分

- `app/schemas/paper.py`
  - `PaperSchema`
  - `PaperQuerySchema`
  - `PaperListResponseSchema`
- `app/schemas/summary.py`
  - `TrendSummarySchema`
  - `TrendSummaryItemSchema`
- `app/schemas/favorite.py`
  - `FavoritePaperSchema`
  - `SyncRecordSchema`
  - `BibtexExportRequestSchema`
  - `BibtexExportResponseSchema`
- `app/schemas/preference.py`
  - `UserPreferenceSchema`
- `app/schemas/translation.py`
  - `TranslationRequestSchema`
  - `TranslationTaskSchema`

## 数据库建模原则

- `Paper` 首版不强制服务端入库，优先作为聚合查询结果对象。
- `SyncRecord`、`TranslationTask`、`UserPreference` 可优先进入 SQLite。
- 与外部上游相关的原始响应不要直接透传数据库表结构，先收敛为领域模型。

## 中文注释要求

- 字段语义不明显、状态流转复杂、枚举值和降级逻辑必须补中文注释。
- 请求 DTO 与响应 DTO 的字段名保持英文，但说明和代码注释使用中文。

