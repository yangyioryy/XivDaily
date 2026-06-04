# 📚 Docs Index

> 面向当前仓库真实实现的最小文档目录。
> 这里只保留「快速对齐项目现状」需要的说明，不再维护历史 QA、截图验收和过度展开的设计文档。

## ✨ 文档范围

| 文档 | 作用 | 适用对象 |
| --- | --- | --- |
| [`backend-api.md`](./backend-api.md) | 后端接口、配置项与本地联调入口 | 后端开发、前后端联调 |
| [`client-apps.md`](./client-apps.md) | Android / Harmony 当前能力、运行方式与后端连接策略 | 客户端开发、演示验证 |

## 🧭 当前项目结构

| 模块 | 目录 | 当前职责 |
| --- | --- | --- |
| 🤖 Android | `android/` | Jetpack Compose 客户端，包含首页、收藏库、论文对话、设置四页主流程 |
| 🌈 HarmonyOS | `harmony/` | ArkUI / ArkTS 客户端，提供与 Android 对齐的四页阅读流程 |
| ⚙️ Backend | `backend/` | FastAPI 后端，负责 arXiv 检索、AI 能力、配置读写与 Zotero 同步 |
| 🖼️ Assets | `asset/` | 展示用截图和视觉素材，不作为文档事实来源 |

## 🚀 最小使用路径

### 1. 启动后端

```powershell
cd backend
python -m pip install -r requirements.txt
python -m alembic upgrade head
python -m uvicorn app.main:app --host 127.0.0.1 --port 8000
```

### 2. 构建 Android 调试包

```powershell
cd android
.\gradlew.bat :app:assembleDebug -Pxivdaily.debugBaseUrl=http://10.0.2.2:8000/ --no-daemon --console=plain
```

上面的 Debug 构建会通过 `http://10.0.2.2:8000/` 连接本机后端。

### 3. 运行 HarmonyOS 客户端

```powershell
cd harmony
ohpm install
```

Harmony 工程当前建议直接用 DevEco Studio 打开 `harmony/` 并运行 `entry` 模块。

## 📌 维护原则

| 原则 | 说明 |
| --- | --- |
| ✅ 以代码为准 | 文档只记录当前仓库中已经存在的实现，不记录计划态功能 |
| ✅ 最小必要 | 避免重复 README、测试记录、部署手册和历史验收材料 |
| ✅ 对外安全 | 不在 `docs/` 中保留真实账号、密钥、个人截图和内部 QA 证据 |
| ✅ 易于更新 | 文档优先描述入口、接口、配置和运行方式，减少易过时叙述 |

## 🔗 对齐入口

- 根项目介绍与截图：[`README.md`](../README.md)
- 后端补充说明：[`backend/README.md`](../backend/README.md)
- Android 补充说明：[`android/README.md`](../android/README.md)
- HarmonyOS 补充说明：[`harmony/README.md`](../harmony/README.md)
