# ⚙️ Backend API

> 基于 `backend/app/main.py`、`backend/app/api/*` 和 `backend/app/core/config.py`
> 整理的最小后端说明。

## ✨ 后端概览

| 项目 | 当前值 |
| --- | --- |
| 框架 | FastAPI |
| 入口 | `backend/app/main.py` |
| 默认主机 | `127.0.0.1` |
| 默认端口 | `8000` |
| 版本返回值 | `0.1.0` |
| 默认数据库 | `sqlite:///./data/xivdaily.db` |
| 运行时覆盖文件 | `data/runtime_config.json` |

## 🧭 路由组成

`create_app()` 当前挂载了 5 组路由：

| 路由组 | 前缀 | 作用 |
| --- | --- | --- |
| ❤️ Health | `/health` | 服务健康检查 |
| 📄 Papers | `/papers` | 查询论文列表与分页结果 |
| 🧠 AI | `/ai/config/status`、`/summaries/*`、`/translations`、`/paper-chat/*` | AI 配置状态、趋势摘要、摘要翻译、论文对话 |
| 🔐 Config | `/config/*` | 读取与保存 Zotero / LLM 运行时配置 |
| 📚 Zotero | `/zotero/*` | 查询配置状态、同步单篇论文、导出 BibTeX |

## 📡 接口清单

| 方法 | 路径 | 说明 |
| --- | --- | --- |
| `GET` | `/health` | 返回 `status`、`environment`、`version` |
| `GET` | `/papers` | 按分类、关键词、时间窗口、分页查询论文 |
| `GET` | `/ai/config/status` | 返回当前是否已配置 LLM Key |
| `GET` | `/summaries/trends` | 生成趋势摘要 |
| `POST` | `/translations` | 翻译单篇论文摘要 |
| `POST` | `/paper-chat/messages` | 基于多篇论文上下文发起对话 |
| `GET` | `/config/integrations` | 读取当前 LLM / Zotero 配置展示态 |
| `PUT` | `/config/zotero` | 保存 Zotero 运行时配置 |
| `POST` | `/config/zotero/test` | 测试当前 Zotero 配置是否可用 |
| `PUT` | `/config/llm` | 保存 LLM 运行时配置 |
| `POST` | `/config/llm/test` | 测试当前 LLM 配置是否可用 |
| `GET` | `/zotero/config/status` | 查询 Zotero 目标集合状态 |
| `POST` | `/zotero/sync/{paper_id}` | 同步单篇论文到 Zotero |
| `POST` | `/zotero/exports/bibtex` | 导出选中论文的 BibTeX |

## 🔎 关键请求约束

### `/papers`

| 参数 | 类型 | 约束 | 说明 |
| --- | --- | --- | --- |
| `keyword` | `string?` | 可空 | 关键词搜索 |
| `category` | `string?` | 可空 | arXiv 分类 |
| `days` | `int?` | `1..30` | 时间窗口；未传且无关键词时默认使用 `7` |
| `page` | `int` | `>= 1` | 页码 |
| `pageSize` | `int` | `1..50` | 分页大小，后端内部字段名为 `page_size` |

### `/summaries/trends`

| 参数 | 类型 | 约束 | 说明 |
| --- | --- | --- | --- |
| `category` | `string?` | 可空 | 分类筛选 |
| `days` | `int` | `1..30` | 趋势摘要窗口 |

### 配置保存接口

| 接口 | 特点 |
| --- | --- |
| `PUT /config/zotero` | `api_key` 允许传空或 `null`，用于保留已有密钥 |
| `PUT /config/llm` | `api_key` 允许传空或 `null`，用于保留已有密钥 |
| `GET /config/integrations` | 对敏感字段只返回 `configured / masked`，不回显完整 key |

## 🔐 配置项

后端配置通过 `.env` 读取，再叠加 `runtime_config.json` 中的运行时覆盖项。

| 配置项 | 默认值 | 用途 |
| --- | --- | --- |
| `APP_NAME` | `XivDaily Backend` | 服务标题 |
| `APP_ENV` | `development` | 环境标识 |
| `APP_HOST` | `127.0.0.1` | 监听地址 |
| `APP_PORT` | `8000` | 监听端口 |
| `APP_LOG_LEVEL` | `INFO` | 日志级别 |
| `DATABASE_URL` | `sqlite:///./data/xivdaily.db` | 数据库连接 |
| `ARXIV_BASE_URL` | `https://export.arxiv.org/api/query` | arXiv API 地址 |
| `ARXIV_REQUEST_TIMEOUT_SECONDS` | `45` | arXiv 请求超时 |
| `ARXIV_MIN_REQUEST_INTERVAL_SECONDS` | `3.5` | arXiv 最小请求间隔 |
| `ARXIV_CACHE_TTL_SECONDS` | `900` | 论文列表缓存时间 |
| `ARXIV_SYNC_ENABLED` | `true` | 是否启用后台同步任务 |
| `ARXIV_SYNC_CATEGORIES` | `["cs.CV","cs.AI","cs.CL"]` | 后台同步分类 |
| `ARXIV_SYNC_WINDOW_DAYS` | `7` | 后台同步时间窗口 |
| `ARXIV_SYNC_INTERVAL_SECONDS` | `7200` | 后台同步周期 |
| `ARXIV_SYNC_MAX_RESULTS` | `50` | 单轮同步最大条数 |
| `PAPER_LIBRARY_STALE_AFTER_SECONDS` | `3600` | 本地论文库过期阈值 |
| `PAPER_LIBRARY_RETENTION_DAYS` | `14` | 论文库保留天数 |
| `PAPER_LIBRARY_MAX_PAPERS_PER_CATEGORY` | `200` | 每分类保留上限 |
| `LLM_BASE_URL` | `https://example.com/v1` | OpenAI 兼容模型服务地址 |
| `LLM_API_KEY` | `None` | LLM 密钥 |
| `LLM_MODEL` | `grok-4.20-0309-non-reasoning-console` | 模型名 |
| `LLM_REQUEST_TIMEOUT_SECONDS` | `60` | LLM 请求超时 |
| `PAPER_PDF_TIMEOUT_SECONDS` | `20` | PDF 抽取超时 |
| `PAPER_PDF_MAX_BYTES` | `15728640` | PDF 下载大小上限 |
| `PAPER_CHAT_CONTEXT_CHARS_PER_PAPER` | `12000` | 单篇论文注入对话上下文的字符上限 |
| `ZOTERO_BASE_URL` | `https://api.zotero.org` | Zotero Web API 地址 |
| `ZOTERO_USER_ID` | `None` | Zotero 用户或群组 ID |
| `ZOTERO_LIBRARY_TYPE` | `user` | Zotero 库类型 |
| `ZOTERO_API_KEY` | `None` | Zotero 密钥 |
| `ZOTERO_TARGET_COLLECTION_NAME` | `XivDaily` | 默认目标集合名 |

## 🚀 本地运行

### 1. 安装依赖

```powershell
cd backend
python -m pip install -r requirements.txt
```

### 2. 初始化数据库

```powershell
python -m alembic upgrade head
```

### 3. 启动服务

```powershell
python -m uvicorn app.main:app --host 127.0.0.1 --port 8000
```

### 4. 快速验证

```text
GET  http://127.0.0.1:8000/health
GET  http://127.0.0.1:8000/papers?category=cs.CV&days=3&page=1&pageSize=10
GET  http://127.0.0.1:8000/summaries/trends?category=cs.CV&days=3
GET  http://127.0.0.1:8000/config/integrations
GET  http://127.0.0.1:8000/zotero/config/status
```

## 🧪 验证入口

| 类型 | 命令 |
| --- | --- |
| 后端测试 | `cd backend && python -m pytest -q` |
| 健康检查 | `GET /health` |
| 客户端联调 | Android 走 `10.0.2.2`，Harmony 走候选地址重试策略 |
