# 📱 Client Apps

> 只描述当前仓库内 Android / HarmonyOS 两个客户端的真实状态与运行方式。

## ✨ 双端概览

| 项目 | Android | HarmonyOS |
| --- | --- | --- |
| 技术栈 | Kotlin + Jetpack Compose | ArkTS + ArkUI |
| 包名 / Bundle | `com.xivdaily.app` | `com.xivdaily.harmony` |
| 版本 | `0.1.0` | `0.1.0` |
| 主导航 | 底部四页导航 | Tabs 四页结构 |
| 本地存储 | Room + DataStore | 本地收藏服务 + 偏好服务 |
| 网络入口 | `ApiService.kt` | `PaperService.ets` |

## 🧭 当前页面结构

| 页面 | Android | HarmonyOS | 当前能力 |
| --- | --- | --- | --- |
| 🏠 首页 | `HomeScreen.kt` | `HomePage.ets` | 分类、关键词、时间窗口、论文流、趋势摘要、摘要翻译 |
| ⭐ 收藏库 | `LibraryScreen.kt` | `LibraryPage.ets` | 收藏列表、同步状态筛选、删除、BibTeX 导出、跳转对话 |
| 💬 对话 | `PaperChatScreen.kt` | `ChatPage.ets` | 基于收藏论文的多论文问答 |
| ⚙️ 设置 | `SettingsScreen.kt` | `SettingsPage.ets` | 偏好设置、Zotero 配置、LLM 配置、状态刷新 |

## 🤖 Android

### 核心实现

| 方向 | 文件 | 说明 |
| --- | --- | --- |
| 应用入口 | `android/app/src/main/java/com/xivdaily/app/MainActivity.kt` | 启动 Compose 根界面 |
| 导航结构 | `android/app/src/main/java/com/xivdaily/app/ui/navigation/AppNavGraph.kt` | `home / library / chat / settings` 四条主路由 |
| 数据入口 | `android/app/src/main/java/com/xivdaily/app/data/remote/ApiService.kt` | 对接后端全部核心接口 |
| 仓储层 | `android/app/src/main/java/com/xivdaily/app/data/repository/PaperRepository.kt` | 论文流、收藏、同步、导出、对话的数据汇总点 |
| 本地持久化 | `android/app/src/main/java/com/xivdaily/app/data/local/*` | Room 实体、DAO 与数据库 |
| 偏好存储 | `android/app/src/main/java/com/xivdaily/app/data/datastore/UserPreferencesRepository.kt` | 默认分类、时间窗口等偏好 |

### 构建参数

| 参数 | 默认值 | 说明 |
| --- | --- | --- |
| `namespace` | `com.xivdaily.app` | Android 命名空间 |
| `applicationId` | `com.xivdaily.app` | 应用 ID |
| `minSdk` | `26` | 最低版本 |
| `targetSdk` | `36` | 目标版本 |
| `xivdaily.debugBaseUrl` | `http://10.0.2.2:8000/` | 调试包后端地址 |
| `xivdaily.releaseBaseUrl` | `https://beginnerforever.eu.cc/` | Release 默认后端地址 |

### 本地运行

```powershell
cd android
.\gradlew.bat :app:assembleDebug --no-daemon --console=plain
```

如需安装到设备：

```powershell
D:\AndroidSdk\platform-tools\adb.exe install -r app\build\outputs\apk\debug\app-debug.apk
D:\AndroidSdk\platform-tools\adb.exe shell am start -n com.xivdaily.app/.MainActivity
```

## 🌈 HarmonyOS

### 核心实现

| 方向 | 文件 | 说明 |
| --- | --- | --- |
| Bundle 信息 | `harmony/AppScope/app.json5` | `bundleName = com.xivdaily.harmony` |
| 根页面 | `harmony/entry/src/main/ets/pages/XivDailyPage.ets` | 四页 Tabs 根容器 |
| 全局状态 | `harmony/entry/src/main/ets/viewmodel/AppViewModel.ets` | 统筹首页、收藏、对话、设置状态 |
| 网络服务 | `harmony/entry/src/main/ets/service/PaperService.ets` | 访问论文流、趋势、翻译、对话、配置和 Zotero 接口 |
| 收藏服务 | `harmony/entry/src/main/ets/service/FavoriteStoreService.ets` | 本地收藏与同步状态 |
| 偏好服务 | `harmony/entry/src/main/ets/service/PreferenceService.ets` | 主题、分类、时间窗口等偏好 |

### 后端连接策略

`PaperService.ets` 当前按顺序尝试这些候选后端地址：

```text
http://10.0.2.2:8000/
https://beginnerforever.eu.cc/
http://127.0.0.1:8000/
```

适用场景：

| 地址 | 适用场景 |
| --- | --- |
| `http://10.0.2.2:8000/` | 模拟器联调本机后端 |
| `https://beginnerforever.eu.cc/` | 连接已部署的公网后端 |
| `http://127.0.0.1:8000/` | 设备与服务位于同一上下文时的本地地址 |

### 本地运行

```powershell
cd harmony
ohpm install
```

当前仓库没有额外封装 `hvigorw`，建议直接使用 DevEco Studio：

1. 打开 `harmony/`
2. 等待 `ohpm` 与 `hvigor` 同步完成
3. 运行 `entry` 模块到模拟器或真机

## 🔗 双端共用的后端能力

| 能力 | Android | HarmonyOS |
| --- | --- | --- |
| 论文列表 | ✅ | ✅ |
| 趋势摘要 | ✅ | ✅ |
| 摘要翻译 | ✅ | ✅ |
| 论文对话 | ✅ | ✅ |
| Zotero 配置读写与测试 | ✅ | ✅ |
| BibTeX 导出 | ✅ | ✅ |

## 🧪 验证入口

| 类型 | 命令 |
| --- | --- |
| Android 单元测试 | `cd android && .\gradlew.bat :app:testDebugUnitTest --no-daemon --console=plain` |
| 后端联调 | 先启动 `backend`，再运行 Android 或 Harmony 客户端 |
