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

当前机器已经具备 Gradle wrapper 与 Android 编译链，可执行 `gradlew.bat`。
但在中文工作路径下，`testDebugUnitTest` 会出现 Gradle/JUnit 运行时
`ClassNotFoundException`；将仓库映射到 ASCII 路径后可正常通过。

建议验证方式：

1. 进入 `android/`。
2. 如需直接在当前目录构建，执行 `gradlew.bat assembleDebug`。
3. 如需跑单元测试，优先在 ASCII 路径映射下执行：
   `C:\Users\huawei\.codex\tmp\xivdaily-ascii\android\gradlew.bat testDebugUnitTest`
4. 在模拟器或真机上验证首页、收藏库和设置页。
