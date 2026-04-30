# API 合同说明

本文件以当前真实后端实现为准，用于冻结前后端协作边界。
Android 与后端联调时，若文档与代码冲突，应优先修正文档而不是继续沿用过期路径。

## 当前真实接口

- `GET /health`：健康检查。
- `GET /papers`：论文列表查询，支持 `keyword`、`category`、`days`、`page`、`pageSize`。
- `GET /summaries/trends`：生成首页趋势摘要。
- `POST /translations`：翻译单篇论文摘要。
- `GET /ai/config/status`：兼容状态接口，仅返回大模型是否配置。
- `GET /zotero/config/status`：兼容状态接口，返回 Zotero 可用性与目标集合状态。
- `GET /config/integrations`：读取设置页 Zotero 与大模型配置，敏感字段只返回脱敏状态。
- `PUT /config/zotero`：保存 Zotero 配置。
- `POST /config/zotero/test`：检查 Zotero 必填配置是否已填写。
- `PUT /config/llm`：保存大模型配置。
- `POST /config/llm/test`：检查大模型必填配置是否已填写。
- `POST /zotero/sync/{paper_id}`：同步单篇论文到 Zotero。
- `POST /zotero/exports/bibtex`：批量导出 BibTeX。

## `/papers` 查询语义

- `page` 默认 `1`，`pageSize` 默认 `10`，后端仍保留 `pageSize` 查询别名。
- `days` 是可选参数，范围为 `1..30`。
- 无关键词时，如果客户端没有传 `days`，后端默认使用 `7` 天时间窗。
- 有关键词时，如果客户端没有传 `days`，后端执行全 arXiv 关键词搜索，不再强制套用 `3/7/30` 天窗口。
- `category` 可与关键词同时传入；服务层会先召回关键词结果，再在本地按分类过滤、去重和分页。
- 响应除 `items/page/page_size/total/has_more` 外，还包含：
  - `query.days`：实际生效的时间窗；全库关键词搜索时为 `null`。
  - `status`：`ok | empty | stale | unavailable`。
  - `warning`：需要给客户端展示的补充提示，可为空。
  - `empty_reason`：`time_window_filtered | no_results | null`。

## AI 与翻译语义

- `GET /summaries/trends` 接口保留 `days` 查询参数兼容旧调用，但后端固定按最近 `3` 天生成趋势。
- 趋势摘要最多取 `8` 篇论文作为输入，每篇摘要截断约 `100` 个字符。
- 趋势结果固定返回最多 `3` 条 `items`，失败时返回 `status=degraded` 与 `warning`，客户端只在趋势卡片内展示该失败。
- `POST /translations` 返回 `TranslationTask`：
  - `status`：`success | degraded | failed`。
  - `translated_summary`：成功时为中文摘要，降级时可能为可读 fallback。
  - `warning`：降级或失败原因，可为空。
- Android 端按论文 ID 维护翻译中与翻译失败状态，不把这些瞬态字段写进 Room。

## 配置与脱敏规则

- 设置页主入口使用 `/config/integrations` 以及 `/config/zotero`、`/config/llm` 保存/测试接口。
- `/ai/config/status` 与 `/zotero/config/status` 保留为兼容状态接口，不承担完整配置编辑职责。
- 后端运行时配置写入 `data/runtime_config.json`，服务启动时会通过 `Settings.apply_runtime_overrides()` 覆盖环境变量默认值。
- 所有敏感字段响应统一为对象：

```json
{
  "configured": true,
  "masked": "***1234"
}
```

- 完整 `api_key` 不允许出现在响应体、日志、Toast 或普通错误提示里。
- 保存配置时，空白 `api_key` 表示保留已有密钥；只有传入非空字符串才会覆盖旧密钥。
- 当前测试接口只校验必填配置是否已填写，不会向生产 Zotero 或大模型服务发送真实探测请求。

## Android DTO 边界

- DTO 字段保持后端 snake_case，Android 通过 Moshi `@Json` 映射到 camelCase。
- `PaperQueryDto.days` 为 `Int?`，用于表达关键词全库搜索。
- `IntegrationConfigDto` 包含 `zotero` 与 `llm` 两段配置读模型。
- `ZoteroConfigSaveRequestDto` 与 `LlmConfigSaveRequestDto` 允许 `apiKey=null`，表示保留已有密钥。

## 当前不在合同内的能力

- `preferences/bootstrap` 尚未落地，当前默认配置由 Android 本地 DataStore 承担。
- 论文翻译缓存表尚未落地，当前翻译结果保存在首页内存 UI 状态中。
- 文档中不再保留 `/favorites/{paperId}/sync-zotero`、`/exports/bibtex` 等旧路径。

## 兼容约束

- 响应字段当前由后端真实 Pydantic 模型决定；如需统一到 camelCase，必须同步修改后端与 Android DTO。
- AI 与 Zotero 相关接口必须保留失败降级或状态字段，客户端不能把失败视为成功。
- 后端新增字段时 Android DTO 可以先忽略，但删除或重命名字段必须同步更新 `docs/openapi-draft.yaml` 与客户端 DTO。
