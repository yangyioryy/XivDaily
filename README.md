# 📚 XivDaily

<div align="center">
  <img src="./android/logo.png" alt="XivDaily Logo" width="140" />

  <p>
    <strong>面向科研阅读场景的每日 arXiv 论文工作台</strong>
  </p>

  <p>
    AI 导读 · 收藏管理 · 多论文对话 · Zotero 同步
  </p>
</div>

## ✨ 项目简介

`XivDaily` 把"发现论文 → 快速判断价值 → 收藏整理 → 后续阅读"的科研日常搬到移动端完成。

- **Android 原生客户端**：负责论文流、收藏库、设置页与论文对话体验
- **FastAPI 后端**：负责 arXiv 数据接入、AI 能力、配置存储、PDF 文本抽取与 Zotero Web API 同步
- **AI 加持**：趋势简报、摘要中文翻译、多论文对话一站完成

适合以下使用者：

- 每天需要刷 arXiv 跟踪领域进展的研究生 / 研究员
- 想把论文流、收藏与 Zotero 文献库打通的人
- 想用大模型加速论文筛选和阅读的人

## 🚀 核心特性

**论文流**

- 按 `cs.CV` / `cs.AI` / `cs.CL` 等分类拉取最新论文
- 支持时间窗口过滤与跨 arXiv 关键词搜索
- 列表项支持快速预览摘要、跳转 PDF、一键收藏

**AI 辅助阅读**

- 趋势简报：基于近期论文流生成中文趋势摘要
- 摘要翻译：单篇论文摘要一键中文翻译
- 多论文对话：选择多篇收藏论文，结合元数据与 PDF 文本与大模型对话
- 降级提示：LLM 不可用时返回明确降级文案，不阻塞阅读流

**收藏库**

- 本地 Room 数据库持久化，离线可见
- 同步状态筛选（已同步 / 未同步 / 失败）、单条 / 批量删除
- 一键导出 BibTeX
- 直接跳转到论文对话页继续提问

**论文对话**

- 选择收藏中的多篇论文进入对话
- 中文 IME 组合输入安全（仅按钮触发发送）
- 等待响应时显示"正在思考中"气泡
- 上下文按字符长度自动裁剪每篇论文的 PDF 正文

**Zotero 同步**

- 通过 Zotero Web API 创建或复用目标集合（默认 `XivDaily`）
- 单篇 / 批量同步，并校验条目是否落入目标集合
- 缺失时自动 repair，避免悬空条目
- 桌面 Zotero 同步刷新后即可看到新条目

**配置中心**

- Android 设置页直接维护偏好、Zotero、LLM 配置
- 后端 `/config/*` 接口读写并覆盖运行时配置
- 敏感配置不入仓库

## 🏗️ 架构概览

```text
Android App (Kotlin + Jetpack Compose)
    │
    ├── Home      论文流 / 趋势 / 翻译 / 收藏 / 同步
    ├── Library   收藏管理 / 筛选 / BibTeX / 跳转对话
    ├── Chat      选择论文 / 中文输入 / 等待态 / 结果
    └── Settings  偏好 / Zotero 配置 / LLM 配置
        ├── Room (收藏持久化)
        ├── DataStore (用户偏好)
        └── Retrofit + OkHttp (后端 API)
    │
    ▼ HTTPS
FastAPI Backend
    │
    ├── /papers              arXiv 检索与缓存降级
    ├── /summaries/trends    AI 趋势摘要
    ├── /translations        摘要翻译
    ├── /paper-chat/messages 论文对话
    ├── /config/*            集成配置读写与测试
    └── /zotero/*            状态 / 同步 / BibTeX 导出
    │
    ▼
arXiv API · LLM API · Zotero Web API
```

## 🛠️ 技术栈

| 模块   | 技术选型                                                        |
| ------ | --------------------------------------------------------------- |
| 移动端 | Kotlin · Jetpack Compose · Material 3 · Navigation Compose      |
| 端上存储 | Room · DataStore                                                |
| 网络   | Retrofit · OkHttp · Moshi                                       |
| 后端框架 | Python · FastAPI · Pydantic Settings                           |
| 后端存储 | SQLAlchemy · Alembic · SQLite                                  |
| 外部集成 | arXiv API · Zotero Web API · OpenAI 兼容 LLM                   |
| 文本处理 | httpx · pypdf                                                   |
| 测试   | JUnit · kotlinx-coroutines-test · pytest · FastAPI TestClient   |

## 📦 目录结构

```text
XivDaily/
├── android/
│   ├── app/src/main/java/com/xivdaily/app/
│   │   ├── data/          # Retrofit / Room / DataStore / Repository
│   │   ├── ui/            # Compose 页面、导航、主题、ViewModel
│   │   └── di/            # 应用依赖容器
│   └── logo.png
│
├── backend/
│   ├── app/
│   │   ├── api/           # health / papers / ai / config / zotero
│   │   ├── clients/       # arXiv / Zotero 客户端
│   │   ├── services/      # 论文 / AI / 配置 / Zotero 业务逻辑
│   │   └── models/        # SQLAlchemy 模型
│   ├── migrations/        # Alembic 迁移
│   └── tests/             # 后端自动化测试
│
├── docs/                  # 架构、接口、部署说明
└── scripts/               # 本地 smoke、发布、部署脚本
```

## ⚡ 快速开始

### 1. 启动后端

```powershell
cd backend
python -m pip install -r requirements.txt
python -m alembic upgrade head
python -m uvicorn app.main:app --host 127.0.0.1 --port 8000
```

使用 Conda 环境时：

```powershell
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

Debug 构建默认访问宿主机本地后端：

```text
http://10.0.2.2:8000/
```

Release 构建后端地址通过 Gradle 属性 `xivdaily.releaseBaseUrl` 覆盖。

### 3. 安装到模拟器或真机

```powershell
D:\AndroidSdk\platform-tools\adb.exe devices
D:\AndroidSdk\platform-tools\adb.exe install -r android/app/build/outputs/apk/debug/app-debug.apk
D:\AndroidSdk\platform-tools\adb.exe shell am start -n com.xivdaily.app/.MainActivity
```

## 🔐 配置说明

后端读取 `.env` 与运行时配置，Android 设置页保存的 Zotero / LLM 配置会写入后端运行时配置并覆盖对应环境变量。`.env.example` 提供本地模板，**敏感值不要提交到仓库**。

| 变量名                                | 用途                                | 示例                            |
| ------------------------------------- | ----------------------------------- | ------------------------------- |
| `DATABASE_URL`                        | 后端数据库连接                      | `sqlite:///./data/xivdaily.db`  |
| `LLM_BASE_URL`                        | LLM 服务地址（OpenAI 兼容）         | `https://example.com`           |
| `LLM_API_KEY`                         | LLM API Key                         | `sk-...`                        |
| `LLM_MODEL`                           | LLM 模型名                          | `glm5`                          |
| `LLM_REQUEST_TIMEOUT_SECONDS`         | LLM 单次请求超时（秒）              | `60`                            |
| `PAPER_CHAT_CONTEXT_CHARS_PER_PAPER`  | 每篇论文进入对话的字符上限          | `12000`                         |
| `ZOTERO_BASE_URL`                     | Zotero Web API 地址                 | `https://api.zotero.org`        |
| `ZOTERO_USER_ID`                      | Zotero 用户 ID                      | `15884975`                      |
| `ZOTERO_LIBRARY_TYPE`                 | 库类型                              | `user` 或 `group`               |
| `ZOTERO_API_KEY`                      | Zotero API Key                      | —                               |
| `ZOTERO_TARGET_COLLECTION_NAME`       | 目标集合名                          | `XivDaily`                      |

Zotero 注意事项：

- 后端通过 Zotero Web API 创建或复用目标集合，**不会**直接写本机 Zotero 目录
- 桌面 Zotero 需要登录同一账号并完成同步，才会看到 Web 端新建或更新的集合
- `ZOTERO_LIBRARY_TYPE` 可为 `user`（个人库）或 `group`（群组库）

## 🧪 本地验证

```powershell
# 后端测试
cd backend
python -m pytest -q

# Android 单元测试
cd android
.\gradlew.bat :app:testDebugUnitTest --no-daemon --console=plain
```


## 📖 相关文档

- `docs/architecture-overview.md`：整体架构说明
- `docs/api-contract.md`：后端接口契约
- `docs/android-model-mapping.md`：Android 数据模型映射
- `docs/local-development.md`：本地开发说明
- `docs/deployment/local-run.md`：本地运行流程

## 🙏 鸣谢

- **Thank you to arXiv for use of its open access interoperability.** 感谢 [arXiv](https://arxiv.org/) 提供开放获取互操作性，本项目通过 [arXiv API](https://info.arxiv.org/help/api/index.html) 获取论文元数据与 PDF 链接。
- 感谢 [Zotero](https://www.zotero.org/) 提供 Web API，使移动端到文献库的同步成为可能。
- 感谢 Jetpack Compose、FastAPI 等开源项目让本项目可以专注于业务体验本身。

## 📄 License

本项目采用 **Apache License 2.0** 开源协议，详见 [LICENSE](./LICENSE)。
