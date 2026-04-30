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
adb devices
```

结果：

```text
adb : The term 'adb' is not recognized as the name of a cmdlet, function, script file,
or operable program.
```

结论：

- 当前环境没有可用 `adb` 命令，无法自动安装 APK、拉起模拟器或采集三页 UI 截图。
- 因此“模拟器截图逐页对比参考图”“手势/头像 URI/配置表单端到端操作”本轮标记为受限验收，未声明已通过。
- 可验证的静态与编译闭环已经完成：三页 Compose 代码参与 `compileDebugKotlin`，配置 DTO 与 Repository 契约参与编译。

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
- 当前环境缺少 `adb`，无法给出模拟器截图、滑动手势、头像 URI 重启恢复和设置表单真实设备操作结论。
- 后端配置测试接口当前只校验字段填写状态，不向外部 Zotero/LLM 发送真实连通性探测。
