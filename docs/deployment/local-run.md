# 本地运行说明

## 后端

1. 进入 `backend/`。
2. 使用 `xivdaily` 环境安装依赖：
   `conda run -n xivdaily pip install -r requirements.txt`
3. 执行迁移：
   `D:\miniconda3\envs\xivdaily\Scripts\alembic.exe upgrade head`
4. 启动服务：
   `D:\miniconda3\envs\xivdaily\python.exe -m uvicorn app.main:app --host 127.0.0.1 --port 8000`

## Android

当前机器已经完成 Android 骨架落地，但没有可用 Gradle CLI 和 Android SDK
验证链路。后续请在具备 SDK 的环境中：

1. 进入 `android/`。
2. 补齐 `gradle/wrapper` 和本机 SDK 配置。
3. 执行 `gradlew.bat assembleDebug`。
4. 在模拟器或真机上验证首页、收藏库和设置页。

