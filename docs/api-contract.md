# API 合同占位说明

本文件用于冻结前后端接口协作边界，详细 OpenAPI 草案将在 `XIV-003`
阶段补齐。当前先记录首版必须存在的接口类别，避免 Android 和后端并行时
各自假设不一致。

## 首版接口类别

- `GET /health`：健康检查。
- `GET /papers`：论文列表查询，支持关键词、分类、时间窗口和分页。
- `GET /summaries/trends`：当前时间窗口的趋势摘要。
- `POST /translations`：单篇摘要翻译。
- `POST /favorites/{paperId}/sync-zotero`：同步单篇论文到 Zotero。
- `POST /exports/bibtex`：批量导出 BibTeX。
- `GET /preferences/bootstrap`：客户端启动时获取默认配置占位。

## 合同约束

- 字段命名、实体定义和 DTO 映射将在后续 issue 中统一冻结。
- 所有失败返回必须可区分用户可恢复错误与系统异常。
- AI 与 Zotero 相关接口必须预留超时、失败降级和状态说明字段。

