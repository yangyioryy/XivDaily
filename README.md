# XivDaily

XivDaily 是一个面向科研人员和 AI 开发者的论文快筛工具。首版采用原生 Android 客户端加 Python 后端的双端结构，围绕 arXiv 论文追踪、AI 导读、收藏管理和 Zotero 集成展开。

## 当前仓库状态

- `backend/` 已包含可运行的 FastAPI、迁移脚本和测试。
- `android/` 已包含可构建的 Gradle 工程，当前可产出 debug APK。
- `docs/` 记录真实接口、运行说明和回归信息。
- `issues/` 中的当前 CSV 是执行闭环时的唯一状态源。

## 目录说明

- `android/`：Android 客户端工程与 UI、数据层代码。
- `backend/`：Python 后端工程、配置、迁移与测试代码。
- `docs/`：架构、接口、运行说明和回归文档。
- `issues/`：任务状态 CSV。
- `plan/`：阶段计划和范围冻结文档。
- `scripts/`：联调、检查、构建等辅助脚本。

## 本地开发约定

- 后端开发环境使用 `xivdaily` conda 环境。
- Android 构建统一使用 `android/gradlew.bat`。
- 敏感信息只能从环境变量或忽略文件读取，不能提交到仓库。
