# XivDaily

<div align="center">
  <img src="./android/logo.png" alt="XivDaily Logo" width="140" />

  <p>
    <strong>面向科研阅读场景的每日 arXiv 论文工作台</strong>
  </p>

  <p>
    原生 Android 客户端 + FastAPI 后端，聚焦论文快筛、AI 导读、收藏管理、论文对话与 Zotero 同步。
  </p>
</div>

## 项目简介

`XivDaily` 用来把“发现论文 -> 快速判断价值 -> 收藏整理 -> 后续阅读”的日常流程放到移动端完成。Android 端负责论文流、收藏库、设置页和论文对话体验；后端负责 arXiv 数据、AI 能力、配置保存、PDF 文本抽取和 Zotero Web API 同步。

当前代码已经覆盖以下核心流程：

- 从 arXiv 拉取论文流，支持领域筛选、时间窗口和关键词搜索。
- 首页展示 AI 趋势简报，并支持单篇摘要中文翻译。
- 收藏论文到本地 Room 数据库，在收藏库筛选同步状态、批量选择、删除和导出 BibTeX。
- 从首页或收藏库同步论文到 Zotero 目标集合；后端会创建或复用 Zotero Web 集合，并校验 collection membership。
- 在论文对话页选择收藏论文，向后端提交论文元数据和对话历史；等待时显示“正在思考中”反馈。
- 在设置页维护默认偏好、Zotero 配置和大模型配置；敏感配置不提交到仓库。

## 核心特性

- **论文流**：按 `cs.CV`、`cs.AI`、`cs.CL` 等分类查看最近论文，关键词搜索可跨 arXiv 查询。
- **AI 辅助阅读**：支持趋势摘要、摘要翻译和多论文对话；后端在 LLM 不可用时会给出降级提示。
- **收藏库**：本地收藏持久化，支持同步状态筛选、单条删除、批量删除、BibTeX 导出和跳转论文对话。
- **论文对话**：中文输入框保留 IME composing 状态，发送只由按钮触发；发送后展示临时思考中气泡。
- **Zotero 同步**：目标集合默认 `XivDaily`，可通过配置修改；同步后校验条目是否出现在目标集合，缺失时尝试 repair。
- **配置管理**：后端读取 `.env` 和运行时配置，Android 设置页通过 `/config/*` 接口读写 Zotero 与 LLM 配置。

## 架构概览

```text
Android App (Kotlin + Jetpack Compose)
├── Home：论文流 / 趋势摘要 / 摘要翻译 / 收藏 / Zotero 同步
├── Library：收藏管理 / 同步筛选 / BibTeX 导出 / 跳转论文对话
├── Chat：收藏论文选择 / 中文输入 / 发送等待态 / 对话结果
└── Settings：偏好设置 / Zotero 配置 / LLM 配置
    ├── Room：收藏论文本地持久化
    ├── DataStore：用户偏好持久化
    └── Retrofit + OkHttp：访问后端 API

FastAPI Backend
├── /papers：arXiv 论文检索与缓存降级
├── /summaries/trends：AI 趋势摘要
├── /translations：摘要翻译
├── /paper-chat/messages：论文对话
├── /config/*：集成配置读写与测试
└── /zotero/*：配置状态、单篇同步、BibTeX 导出
```

## 技术栈

- Android：Kotlin、Jetpack Compose、Material 3、Navigation Compose、Room、DataStore、Retrofit、Moshi、OkHttp。
- Backend：Python、FastAPI、SQLAlchemy、Alembic、Pydantic Settings、httpx、pypdf。
- Testing：JUnit、kotlinx-coroutines-test、pytest、FastAPI TestClient、httpx MockTransport。

## 目录结构

```text
android/
├── app/src/main/java/com/xivdaily/app/
│   ├── data/          # Retrofit、Room、DataStore、Repository
│   ├── ui/            # Compose 页面、导航、主题、ViewModel
│   └── di/            # 应用依赖容器
└── logo.png           # README 与应用使用的 Logo

backend/
├── app/
│   ├── api/           # health、papers、ai、config、zotero 路由
│   ├── clients/       # arXiv / Zotero 客户端
│   ├── services/      # 论文、AI、配置、Zotero 业务逻辑
│   └── models/        # SQLAlchemy 模型
├── migrations/        # Alembic 迁移
└── tests/             # 后端自动化测试

docs/                  # 架构、接口、部署和历史 QA 记录
scripts/               # 本地 smoke、发布和部署脚本
```

## 快速开始

### 1. 准备后端环境

```powershell
cd backend
python -m pip install -r requirements.txt
python -m alembic upgrade head
python -m uvicorn app.main:app --host 127.0.0.1 --port 8000
```

如果使用 Conda，可以把上面的 `python -m ...` 换成：

```powershell
conda run -n xivdaily python -m pytest -q
conda run -n xivdaily uvicorn app.main:app --host 127.0.0.1 --port 8000
```

常用本地接口：

```text
GET http://127.0.0.1:8000/health
GET http://127.0.0.1:8000/papers?category=cs.CV&days=3&page=1&pageSize=20
GET http://127.0.0.1:8000/summaries/trends?category=cs.CV&days=3
GET http://127.0.0.1:8000/config/integrations
GET http://127.0.0.1:8000/zotero/config/status
```

### 2. 构建 Android Debug 包

```powershell
cd android
.\gradlew.bat :app:assembleDebug --no-daemon --console=plain
```

Debug 构建默认访问：

```text
http://10.0.2.2:8000/
```

这个地址用于 Android 模拟器访问宿主机本地后端。Release 后端地址通过 Gradle 属性 `xivdaily.releaseBaseUrl` 覆盖。

### 3. 安装到模拟器或真机

```powershell
D:\AndroidSdk\platform-tools\adb.exe devices
D:\AndroidSdk\platform-tools\adb.exe install -r android/app/build/outputs/apk/debug/app-debug.apk
D:\AndroidSdk\platform-tools\adb.exe shell am start -n com.xivdaily.app/.MainActivity
```

如果 `adb devices` 为空，需要先启动模拟器或连接真机。

## 配置说明

后端 `.env.example` 提供本地模板。敏感值不要提交到仓库；Android 设置页保存的 Zotero 和 LLM 配置会写入后端运行时配置，并覆盖对应环境变量。

常用配置项：

```env
DATABASE_URL=sqlite:///./data/xivdaily.db
LLM_BASE_URL=https://example.com
LLM_API_KEY=
LLM_MODEL=glm5
LLM_REQUEST_TIMEOUT_SECONDS=60
PAPER_CHAT_CONTEXT_CHARS_PER_PAPER=12000
ZOTERO_BASE_URL=https://api.zotero.org
ZOTERO_USER_ID=
ZOTERO_LIBRARY_TYPE=user
ZOTERO_API_KEY=
ZOTERO_TARGET_COLLECTION_NAME=XivDaily
```

Zotero 说明：

- 后端通过 Zotero Web API 创建或复用目标集合，不会直接创建 Windows 本机目录。
- 桌面 Zotero 需要登录同一账号并完成同步刷新，才会看到 Web 端新建或更新的集合。
- `ZOTERO_LIBRARY_TYPE` 可为 `user` 或 `group`，对应个人库或群组库。

## 验证命令

当前已验证的自动化命令：

```powershell
cd android
.\gradlew.bat :app:testDebugUnitTest --no-daemon --console=plain
```

结果：`BUILD SUCCESSFUL in 11s`，测试报告包含 5 个测试类、26 个用例、0 failures、0 errors。

```powershell
cd backend
python -m pytest -q
```

结果：`52 passed in 1.16s`。

```powershell
cd android
.\gradlew.bat :app:assembleDebug --no-daemon --console=plain
```

结果：`BUILD SUCCESSFUL in 17s`，产物为 `android/app/build/outputs/apk/debug/app-debug.apk`。

## 验收边界

本地后端启动检查已经覆盖：

- `/health` 返回 `ok`。
- `/config/integrations` 返回 200。
- `/zotero/config/status` 返回 200，目标集合状态为 `ready`。

当前仍需设备级人工确认：

- `library -> chat/{paperId} -> 点击收藏库 tab` 是否稳定回到收藏库。
- 真机或模拟器中文 IME 组合输入是否正常上屏。
- 真实 LLM 慢响应时思考中气泡是否按预期出现和消失。
- 真实 Zotero Web 集合同步后，桌面 Zotero 是否刷新可见。

这部分受限原因是当前 `adb devices` 没有连接设备或模拟器。连接设备后按“安装到模拟器或真机”步骤继续验收。

## 参考文档

- `docs/architecture-overview.md`：整体架构说明。
- `docs/api-contract.md`：后端接口契约。
- `docs/android-model-mapping.md`：Android 数据模型映射。
- `docs/local-development.md`：本地开发说明。
- `docs/deployment/local-run.md`：本地运行流程。
- `docs/qa/`：历史验收记录和截图材料。

## License

本项目采用 Apache License 2.0 开源协议，详见 [LICENSE](./LICENSE)。
