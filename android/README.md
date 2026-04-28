# Android 占位说明

本目录预留给原生 Android 客户端工程。

## 计划技术栈

- Kotlin
- Jetpack Compose
- Material 3
- MVVM + Repository
- Room
- DataStore
- Retrofit + Coroutines + Flow

## 首版页面范围

- 首页：关键词检索、领域筛选、时间窗口、AI 趋势摘要、论文流卡片动作。
- 收藏库：离线收藏、同步状态、删除、批量导出 BibTeX。
- 设置页：默认领域、默认时间窗口、Zotero 配置、大模型配置、主题与个人信息。

## 开发约束

- 页面信息层级以 `设计图.png` 为主参考。
- 关键状态流转、复杂 UI 状态和本地持久化逻辑必须补中文注释。
- 当前先冻结目录职责，后续再落正式 Gradle 脚手架。

