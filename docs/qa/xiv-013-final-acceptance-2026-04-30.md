# XIV-013 最终验收记录

记录时间：2026-04-30 17:28:22 +08:00

## 1. 自动化验收结果

### 后端全量测试

命令：

```powershell
python -m pytest -q
```

工作目录：`backend`

结果：

```text
36 passed in 2.02s
```

覆盖点：

- 论文列表默认时间窗与关键词全库搜索。
- 分类过滤、缓存复用、并发请求合并和 stale 降级。
- 趋势摘要固定 3 天、输入截断、降级 warning。
- 配置读写、空 key 保留、敏感字段脱敏。
- Zotero 状态、同步和 BibTeX 导出基础链路。

### Android 编译

命令：

```powershell
.\gradlew.bat :app:compileDebugKotlin --no-daemon --console=plain
```

工作目录：`android`

结果：

```text
BUILD SUCCESSFUL in 32s
```

### Android JVM 单测

命令：

```powershell
.\gradlew.bat :app:testDebugUnitTest --no-daemon --console=plain
```

工作目录：`android`

结果：

```text
3 tests completed, 3 failed
SettingsViewModelTest > initializationError FAILED
HomeViewModelTest > initializationError FAILED
LibraryViewModelTest > initializationError FAILED
java.lang.ClassNotFoundException at BuiltinClassLoader.java:641
BUILD FAILED in 42s
```

报告文件：

- `android/app/build/test-results/testDebugUnitTest/TEST-com.xivdaily.app.ui.viewmodel.HomeViewModelTest.xml`
- `android/app/build/test-results/testDebugUnitTest/TEST-com.xivdaily.app.ui.viewmodel.LibraryViewModelTest.xml`
- `android/app/build/test-results/testDebugUnitTest/TEST-com.xivdaily.app.ui.viewmodel.SettingsViewModelTest.xml`
- `android/app/build/reports/tests/testDebugUnitTest/index.html`

结论：

- 失败发生在测试类加载阶段，三份 XML 均记录 `ClassNotFoundException`。
- 当前失败与业务断言无关，和 `XIV-001` 记录的 Android JVM 测试环境基线一致。
- 本轮未把该问题伪装为通过，后续需要单独排查 Gradle/JUnit 测试 classpath。

## 2. UI 与设备验收

执行：

```powershell
D:\AndroidSdk\platform-tools\adb.exe devices -l
```

结果：

```text
emulator-5554 device product:sdk_gphone64_x86_64 model:sdk_gphone64_x86_64 device:emu64xa
```

补测时间：2026-04-30 17:49:32 +08:00

### 设备环境

- ADB 路径：`D:\AndroidSdk\platform-tools\adb.exe`
- 设备：`emulator-5554`
- Android 版本：`14`
- 分辨率：`1080x2400`
- 密度：`420`

### 安装与启动

命令：

```powershell
.\gradlew.bat :app:assembleDebug --no-daemon --console=plain
D:\AndroidSdk\platform-tools\adb.exe install -r android/app/build/outputs/apk/debug/app-debug.apk
D:\AndroidSdk\platform-tools\adb.exe shell am start -n com.xivdaily.app/.MainActivity
```

结果：

```text
BUILD SUCCESSFUL in 52s
Performing Streamed Install
Success
Starting: Intent { cmp=com.xivdaily.app/.MainActivity }
```

### 截图证据

截图目录：`docs/qa/xiv-013-device-screenshots/`

- `home.png`：首页，包含搜索区、领域/时间筛选、AI 趋势简报和底部导航。
- `library.png`：收藏库，包含同步状态筛选、黄色星标、同步 Zotero 和删除按钮。
- `settings.png`：设置页，包含本地头像、默认偏好、Zotero 配置和大模型配置入口。
- `zotero-dialog.png`：Zotero 配置弹窗，包含 User ID、个人库/群组库、API Key、目标集合、测试/取消/保存按钮。
- `llm-dialog.png`：大模型 API 配置弹窗，包含 Base URL、Model、API Key、测试/取消/保存按钮。

### 后端联通

临时启动后端：

```powershell
python -m uvicorn app.main:app --host 127.0.0.1 --port 8000
```

后端日志确认模拟器访问过：

```text
GET /config/integrations HTTP/1.1 200 OK
GET /summaries/trends?category=cs.CV&days=3 HTTP/1.1 200 OK
GET /papers?category=cs.CV&days=3&page=1&pageSize=20 HTTP/1.1 200 OK
GET /zotero/config/status HTTP/1.1 200 OK
```

### 稳定性检查

- `pidof com.xivdaily.app` 返回进程号 `10878`。
- `dumpsys window` 显示当前焦点为 `com.xivdaily.app/com.xivdaily.app.MainActivity`。
- 最近 300 行 `logcat` 未出现 `FATAL EXCEPTION`。

结论：

- 三页主界面已在模拟器真实启动并截图。
- 设置页 Zotero 和大模型配置表单均可打开，表单字段和测试/保存按钮可见。
- 本轮仍未验证外部图片选择器的头像 URI 重启恢复，因为该流程需要人工选择本地图片并重启应用观察权限持久化。
- 本轮未执行破坏性真实配置覆盖；表单保存/测试接口已由后端自动化测试覆盖。

## 3. 代码与文档一致性

已完成的同步点：

- `PaperQuery.days` 已同步为可空，关键词搜索不再强制时间窗。
- 首页趋势摘要已记录为固定最近 3 天，并和论文列表时间窗解耦。
- `PaperItem` 支持 `translatedSummary`。
- `HomeUiState` 支持 `translatingPaperIds`、`translationErrors` 和底部动作反馈。
- `ApiService` 已包含 `/config/integrations`、配置保存和配置测试 DTO。
- Repository 契约已拆分为首页论文、收藏库、配置三类接口。
- 本地偏好由 `UserPreferencesRepositoryContract` 独立承担。
- `docs/api-contract.md`、`docs/android-model-mapping.md`、`docs/domain-models.md`、`docs/openapi-draft.yaml` 已同步真实接口和脱敏规则。

## 4. 最终风险

- Android JVM 单测仍受 `ClassNotFoundException` 基线阻塞，无法给出 ViewModel 单测通过结论。
- ADB 模拟器截图已补充；头像 URI 重启恢复仍需要人工选择本地图片后复测。
- 后端配置测试接口当前只校验字段填写状态，不向外部 Zotero/LLM 发送真实连通性探测。
