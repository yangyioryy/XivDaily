# ⚙️ XivDaily Backend

<div align="center">
  <p>
    <strong>为 Android 与 HarmonyOS 客户端提供 arXiv、AI 和 Zotero 能力的 FastAPI 后端</strong>
  </p>
</div>

## ✨ 模块概览

| 项目 | 说明 |
| --- | --- |
| 框架 | FastAPI |
| 语言 | Python 3 |
| 配置 | Pydantic Settings + `.env` |
| 存储 | SQLite + SQLAlchemy + Alembic |
| 外部服务 | arXiv API、OpenAI 兼容 LLM、Zotero Web API |
| 运行入口 | `app/main.py` |
| 默认地址 | `http://127.0.0.1:8000/` |
| 默认数据库 | `sqlite:///./data/xivdaily.db` |
| 本地论文库 | `paper_records` |
| 运行时覆盖文件 | `data/runtime_config.json` |

## 🚀 当前能力

| 能力 | 说明 | 关键位置 |
| --- | --- | --- |
| ❤️ 健康检查 | 提供服务存活与基础信息检查 | `app/api/health.py` |
| 📄 论文检索 | 优先读取本地论文库，支持分类、关键词、天数与分页；关键词全局搜索可实时请求 arXiv | `app/api/papers.py`、`app/services/paper_service.py` |
| 🔁 后台同步 | 启动后按分类同步 arXiv 元数据到本地论文库，并清理过期或超限记录 | `app/services/paper_sync_service.py`、`app/models/paper_record.py` |
| 🧠 趋势摘要 | 对近期论文流生成趋势摘要，未配置模型时自动降级 | `app/api/ai.py`、`app/services/ai_service.py` |
| 🌐 摘要翻译 | 单篇论文摘要翻译为中文 | `app/api/ai.py` |
| 💬 论文对话 | 基于多篇论文元数据与 PDF 文本进行问答 | `app/api/ai.py`、`app/services/paper_text_service.py` |
| ⚙️ 集成配置 | 读写 LLM / Zotero 运行时配置，并支持测试配置是否可用 | `app/api/config.py`、`app/services/config_service.py` |
| 🔄 Zotero 同步 | 目标集合校验、单篇同步、集合修复与 BibTeX 导出 | `app/api/zotero.py`、`app/services/zotero_service.py` |

## 🗺️ 接口清单

| 方法 | 路径 | 说明 |
| --- | --- | --- |
| `GET` | `/health` | 健康检查 |
| `GET` | `/papers` | 获取论文列表 |
| `GET` | `/summaries/trends` | 获取趋势摘要 |
| `POST` | `/translations` | 翻译单篇论文摘要 |
| `POST` | `/paper-chat/messages` | 多论文对话 |
| `GET` | `/ai/config/status` | LLM 是否已配置 |
| `GET` | `/config/integrations` | 读取运行时集成配置 |
| `PUT` | `/config/zotero` | 保存 Zotero 配置 |
| `POST` | `/config/zotero/test` | 测试 Zotero 配置 |
| `PUT` | `/config/llm` | 保存 LLM 配置 |
| `POST` | `/config/llm/test` | 测试 LLM 配置 |
| `GET` | `/zotero/config/status` | 查询 Zotero 集合状态 |
| `POST` | `/zotero/sync/{paper_id}` | 同步单篇论文到 Zotero |
| `POST` | `/zotero/exports/bibtex` | 导出 BibTeX |

## 🧱 目录结构

```text
backend/
├── app/
│   ├── api/               # 路由层
│   ├── ai/                # 提示词与 LLM 网关
│   ├── clients/           # arXiv / Zotero 外部客户端
│   ├── core/              # 配置、日志、异常
│   ├── db/                # 会话与基础数据库封装
│   ├── models/            # SQLAlchemy 论文、同步记录与缓存模型
│   ├── schemas/           # 请求 / 响应模型
│   └── services/          # 论文、后台同步、AI、配置、Zotero 业务逻辑
├── data/                  # SQLite 数据与运行时覆盖配置
├── fixtures/              # 示例论文数据
├── migrations/            # Alembic 迁移
├── tests/                 # API / service / client 自动化测试
├── .env.example           # 本地配置示例
├── alembic.ini
├── MODEL_CONTRACT.md
├── requirements.txt
└── README.md
```

## ⚡ 本地运行

### 1. 安装依赖

```powershell
cd backend
python -m pip install -r requirements.txt
```

如需自定义 LLM、Zotero 或数据库配置，可参考 `.env.example` 创建 `.env`。

如果你在 Conda 环境里运行：

```powershell
conda run -n xivdaily pip install -r requirements.txt
```

### 2. 执行数据库迁移

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

> 当前趋势摘要服务内部固定使用 3 天论文窗口生成摘要。

## 🔐 配置项

| 配置项 | 说明 | 默认值 |
| --- | --- | --- |
| `APP_NAME` | FastAPI 标题 | `XivDaily Backend` |
| `APP_ENV` | 应用环境标识 | `development` |
| `APP_HOST` | 监听地址 | `127.0.0.1` |
| `APP_PORT` | 监听端口 | `8000` |
| `APP_LOG_LEVEL` | 日志级别 | `INFO` |
| `DATABASE_URL` | 数据库地址 | `sqlite:///./data/xivdaily.db` |
| `ARXIV_BASE_URL` | arXiv API 地址 | `https://export.arxiv.org/api/query` |
| `ARXIV_REQUEST_TIMEOUT_SECONDS` | arXiv 请求超时 | `45` |
| `ARXIV_MIN_REQUEST_INTERVAL_SECONDS` | arXiv 最小请求间隔 | `3.5` |
| `ARXIV_CACHE_TTL_SECONDS` | 论文列表缓存秒数 | `900` |
| `ARXIV_SYNC_ENABLED` | 是否启用后台同步任务 | `true` |
| `ARXIV_SYNC_CATEGORIES` | 后台同步分类 | `["cs.CV","cs.AI","cs.CL"]` |
| `ARXIV_SYNC_WINDOW_DAYS` | 同步时保留的近期论文窗口 | `7` |
| `ARXIV_SYNC_INTERVAL_SECONDS` | 后台同步周期 | `7200` |
| `ARXIV_SYNC_MAX_RESULTS` | 单轮同步最大条数 | `50` |
| `PAPER_LIBRARY_STALE_AFTER_SECONDS` | 本地论文库过期提示阈值 | `3600` |
| `PAPER_LIBRARY_RETENTION_DAYS` | 本地论文库保留天数 | `14` |
| `PAPER_LIBRARY_MAX_PAPERS_PER_CATEGORY` | 单分类最多保留论文数 | `200` |
| `LLM_BASE_URL` | OpenAI 兼容 LLM 地址 | `https://example.com/v1` |
| `LLM_API_KEY` | LLM Key | 无 |
| `LLM_MODEL` | 模型名 | `grok-4.20-0309-non-reasoning-console` |
| `LLM_REQUEST_TIMEOUT_SECONDS` | LLM 请求超时 | `60` |
| `PAPER_PDF_TIMEOUT_SECONDS` | PDF 抽取超时 | `20` |
| `PAPER_PDF_MAX_BYTES` | PDF 下载大小上限 | `15728640` |
| `PAPER_CHAT_CONTEXT_CHARS_PER_PAPER` | 单篇论文进入聊天上下文的字符上限 | `12000` |
| `ZOTERO_BASE_URL` | Zotero Web API 地址 | `https://api.zotero.org` |
| `ZOTERO_USER_ID` | Zotero 用户 / 群组 ID | 无 |
| `ZOTERO_LIBRARY_TYPE` | 库类型 | `user` |
| `ZOTERO_API_KEY` | Zotero API Key | 无 |
| `ZOTERO_TARGET_COLLECTION_NAME` | 目标集合名 | `XivDaily` |

> 说明：启动时会先读取 `.env`，随后再读取 `data/runtime_config.json` 中的 `llm` / `zotero` 覆盖项。

## 🧪 测试说明

当前 `backend/tests/` 已覆盖以下方向：

| 测试范围 | 文件示例 |
| --- | --- |
| API 接口 | `test_papers_api.py`、`test_ai_api.py`、`test_config_api.py`、`test_zotero_api.py` |
| 业务服务 | `test_paper_service.py`、`test_paper_sync_service.py`、`test_ai_service.py`、`test_zotero_service.py` |
| 外部客户端 / 网关 | `test_arxiv_client.py`、`test_llm_gateway.py`、`test_zotero_client.py` |
| 文本处理 | `test_paper_text_service.py` |

运行测试：

```powershell
cd backend
python -m pytest -q
```

## 📝 开发说明

- `app/main.py` 统一挂载 `health`、`papers`、`ai`、`config`、`zotero` 五组路由。
- `PaperSyncService` 会在非测试环境启动后按配置周期同步 arXiv 论文元数据，`PaperService` 再从本地论文库提供常规列表查询。
- `ConfigService` 会把设置页写回的 LLM / Zotero 配置持久化到运行时覆盖文件，避免直接改仓库中的 `.env`。
- `ZoteroService` 除了新建条目，也负责检查目标集合是否存在，并在条目未正确挂入集合时执行 repair。
