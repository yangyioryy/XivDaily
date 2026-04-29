# 本地开发说明

## 后端环境

- Python 后端统一使用 `xivdaily` conda 环境。
- 当前仓库已经包含可运行的 FastAPI 工程、Alembic 迁移与测试集。
- 本机敏感配置只允许通过 `backend/.env` 或运行时环境变量注入，不得把密钥写入代码、CSV、README 或日志。

## Android 环境

- 当前仓库已经包含可构建的 Android Gradle 工程。
- Windows 中文路径构建依赖 `android.overridePathCheck=true`，这是当前仓库的已知本机兼容设置。
- 本机当前通过 `android/gradlew.bat --no-daemon :app:assembleDebug` 可产出 debug APK。

## 运行边界

- 开发阶段后端默认运行在本机，客户端通过可配置 Base URL 访问。
- 迁移到 VPS 时只允许替换环境配置和部署脚本，不应改动业务契约。

## 协作要求

- `issues/2026-04-29_10-30-25-xivdaily-business-flow-validation.csv` 是当前执行轮次的唯一状态源。
- 能跑测试就跑测试；如果受限，必须在对应 issue 的 `notes` 中写明原因、替代验证和手动步骤。
