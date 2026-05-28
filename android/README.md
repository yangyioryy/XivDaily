# 🤖 XivDaily Android

<div align="center">
  <img src="./logo.png" alt="XivDaily Android Logo" width="120" />

  <p>
    <strong>基于 Jetpack Compose 的 arXiv 科研阅读客户端</strong>
  </p>
</div>

## ✨ 模块概览

| 项目 | 说明 |
| --- | --- |
| 包名 | `com.xivdaily.app` |
| 语言 | Kotlin |
| UI 框架 | Jetpack Compose + Material 3 |
| 架构 | `ViewModel` + `UiState` + Repository |
| 本地存储 | Room + DataStore |
| 网络层 | Retrofit + OkHttp + Moshi |
| 最低版本 | `minSdk = 26` |
| 目标版本 | `targetSdk = 36` |
| 当前版本 | `0.1.0` |
| Debug 后端 | `http://10.0.2.2:8000/` |
| Release 后端 | Gradle 属性 `xivdaily.releaseBaseUrl` 覆盖 |

## 🧭 页面能力

| 页面 | 入口文件 | 主要能力 |
| --- | --- | --- |
| 🏠 首页 | `ui/screen/HomeScreen.kt` | 分类、关键词、时间窗口筛选，论文流浏览，趋势摘要、摘要翻译、收藏与同步入口 |
| 📚 收藏库 | `ui/screen/LibraryScreen.kt` | 本地收藏列表、同步状态过滤、批量删除、BibTeX 导出、跳转对话 |
| 💬 论文对话 | `ui/screen/PaperChatScreen.kt` | 多篇收藏论文上下文问答，中文 IME 安全发送，等待态反馈 |
| ⚙️ 设置页 | `ui/screen/SettingsScreen.kt` | 偏好设置、Zotero 配置、LLM 配置与运行状态维护 |

## 🧱 关键实现

| 方向 | 位置 | 说明 |
| --- | --- | --- |
| 应用入口 | `MainActivity.kt`、`XivDailyApplication.kt` | 启动 Compose 根节点与应用级容器 |
| 导航 | `ui/navigation/AppNavGraph.kt` | 首页、收藏、对话、设置四页导航 |
| 依赖注入 | `di/AppContainer.kt` | 组装 API 服务、Room、DataStore 与仓储 |
| 数据仓储 | `data/repository/PaperRepository.kt` | 串联论文查询、收藏、同步、导出等客户端数据动作 |
| 收藏持久化 | `data/local/*` | Room 实体、DAO 与数据库定义 |
| 用户偏好 | `data/datastore/UserPreferencesRepository.kt` | 默认分类、时间窗口等本地偏好 |
| 主题系统 | `ui/theme/*` | 配色、间距、字体与形状定义 |

## 🖼️ 界面预览

<table>
  <tr>
    <td align="center">
      <img src="../asset/android/首页1.png" alt="Android 首页 1" width="220" /><br />
      <sub>首页 · 论文列表</sub>
    </td>
    <td align="center">
      <img src="../asset/android/首页2.png" alt="Android 首页 2" width="220" /><br />
      <sub>首页 · 趋势摘要与动作区</sub>
    </td>
    <td align="center">
      <img src="../asset/android/收藏页.png" alt="Android 收藏页" width="220" /><br />
      <sub>收藏库 · 同步状态与操作</sub>
    </td>
  </tr>
  <tr>
    <td align="center">
      <img src="../asset/android/对话页.png" alt="Android 对话页" width="220" /><br />
      <sub>论文对话 · 多论文上下文</sub>
    </td>
    <td align="center">
      <img src="../asset/android/设置页1.png" alt="Android 设置页 1" width="220" /><br />
      <sub>设置 · 偏好与账号信息</sub>
    </td>
    <td align="center">
      <img src="../asset/android/设置页2.png" alt="Android 设置页 2" width="220" /><br />
      <sub>设置 · Zotero 与 LLM 配置</sub>
    </td>
  </tr>
</table>

## 📁 目录速览

```text
android/
├── app/src/main/java/com/xivdaily/app/
│   ├── data/
│   │   ├── datastore/      # 用户偏好
│   │   ├── local/          # Room 实体与 DAO
│   │   ├── model/          # 客户端数据模型
│   │   ├── remote/         # Retrofit API
│   │   └── repository/     # 业务仓储
│   ├── di/                 # 应用容器
│   └── ui/
│       ├── navigation/     # 路由与导航
│       ├── screen/         # 四个主页面
│       ├── theme/          # Material 主题定义
│       └── viewmodel/      # 各页状态与动作
└── app/build.gradle.kts
```

## ⚡ 构建与运行

### 1. 构建 Debug 包

```powershell
cd android
.\gradlew.bat :app:assembleDebug --no-daemon --console=plain
```

### 2. 安装到模拟器或真机

```powershell
D:\AndroidSdk\platform-tools\adb.exe devices
D:\AndroidSdk\platform-tools\adb.exe install -r app\build\outputs\apk\debug\app-debug.apk
D:\AndroidSdk\platform-tools\adb.exe shell am start -n com.xivdaily.app/.MainActivity
```

### 3. 运行单元测试

```powershell
.\gradlew.bat :app:testDebugUnitTest --no-daemon --console=plain
```

## 🔐 构建参数

| 参数 | 作用 | 说明 |
| --- | --- | --- |
| `xivdaily.debugBaseUrl` | Debug 包后端地址 | 默认 `http://10.0.2.2:8000/` |
| `xivdaily.releaseBaseUrl` | Release 包后端地址 | 默认 `https://beginnerforever.eu.cc/` |
| `xivdaily.releaseStoreFile` | Release keystore 路径 | 仅在正式签名时提供 |
| `xivdaily.releaseStorePassword` | keystore 密码 | 建议放 `local.properties` 或 `-P` |
| `xivdaily.releaseKeyAlias` | 签名别名 | 与 keystore 配套 |
| `xivdaily.releaseKeyPassword` | 别名密码 | 与 keystore 配套 |

当前 `release` 构建在缺失正式签名参数时会回退到 `debug` 签名，仅用于本地安装验证，不适合作为正式发版包。

## 📝 开发说明

- `PaperRepository.kt` 负责论文列表、收藏、同步与导出等核心数据流，是 Android 端业务的主汇聚点。
- `UserPreferencesRepository.kt` 维护默认分类、天数等偏好，与首页筛选和设置页联动。
- `AppNavGraph.kt` 中已经接入首页、收藏、对话、设置四条主路径，新增页面建议优先沿用现有导航模式。
