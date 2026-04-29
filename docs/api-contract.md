# API 合同说明

本文件以当前真实后端实现为准，用于冻结前后端协作边界。
Android 与后端联调时，若文档与代码冲突，应优先修正文档而不是继续沿用过期路径。

## 当前真实接口

- `GET /health`：健康检查。
- `GET /papers`：论文列表查询，支持 `keyword`、`category`、`days`、`page`、`pageSize`。
- `GET /summaries/trends`：按当前筛选条件生成趋势摘要。
- `POST /translations`：翻译单篇论文摘要。
- `GET /zotero/config/status`：检查 Zotero 配置状态。
- `POST /zotero/sync/{paper_id}`：同步单篇论文到 Zotero。
- `POST /zotero/exports/bibtex`：批量导出 BibTeX。

## 当前不在合同内的能力

- `preferences/bootstrap` 尚未落地，当前客户端默认配置由本地状态和后续 DataStore 持久化承担。
- 文档中不再保留 `/favorites/{paperId}/sync-zotero`、`/exports/bibtex` 等旧路径。

## 合同约束

- 请求参数保留 `pageSize` 这类现有别名，避免 Android 查询参数回退。
- `GET /papers` 当前除 `items/page/page_size/total/has_more` 外，还返回：
  - `status`: `ok | empty | stale | unavailable`
  - `warning`: 需要直接展示给客户端的补充提示
  - `empty_reason`: `time_window_filtered | no_results | null`
- `POST /zotero/sync/{paper_id}` 当前除 `paper_id/status/zotero_item_key/message/synced_at` 外，还返回：
  - `library_type`
  - `user_id`
  - `target_collection_name`
  - `target_collection_key`
  - `target_collection_status`
  - `visibility_status`
  - `visibility_message`
- 响应字段当前由后端真实模型决定；如需统一到 camelCase，必须同步修改后端与 Android DTO。
- AI 与 Zotero 相关接口必须保留失败降级或状态字段，客户端不能把失败视为成功。
