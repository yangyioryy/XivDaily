# 🧰 XivDaily Scripts

<div align="center">
  <p>
    <strong>面向本地联调、Android 打包与 Linux 部署的脚本集合</strong>
  </p>

  <p>
    PowerShell · Bash · Smoke Test · APK Build · Backend Deploy
  </p>
</div>

## ✨ 目录概览

`scripts/` 用来收敛项目里的辅助脚本，目标是把「本地验证 → 产物构建 → 服务部署」这条工程链路固定成可重复执行的命令。

当前仓库里已经落地 3 个真实脚本，分别覆盖：

- `local/`：本地后端冒烟验证
- `release/`：Android APK 打包
- `deploy/`：Linux 后端部署

## 📦 脚本清单

| 脚本 | 平台 | 主要职责 | 关键输出 |
| --- | --- | --- | --- |
| `local/smoke-backend.ps1` | Windows PowerShell | 运行后端测试并对 `/health` 做本地冒烟验证 | 控制台 JSON 健康检查结果 |
| `release/build-android-apk.ps1` | Windows PowerShell | 注入后端地址并构建 Android Debug / Release APK | `dist/` 下带时间戳的 APK |
| `deploy/deploy-backend-linux.sh` | Linux Bash | 初始化后端虚拟环境、安装依赖、迁移数据库并可选安装 systemd 服务 | 可运行的后端环境或 systemd 服务 |

## 🗂️ 目录结构

```text
scripts/
├── deploy/
│   └── deploy-backend-linux.sh
├── local/
│   └── smoke-backend.ps1
├── release/
│   └── build-android-apk.ps1
└── README.md
```

## 🚀 使用说明

### 1. `local/smoke-backend.ps1`

用于 Windows 环境下的后端快速自检。脚本会先执行 `pytest`，再启动 `uvicorn`，随后请求 `/health`，最后自动回收启动的后端进程。

**参数说明**

| 参数 | 类型 | 默认值 | 说明 |
| --- | --- | --- | --- |
| `BackendRoot` | `string` | `..\..\backend` 解析后的绝对路径 | 后端项目根目录 |
| `Port` | `int` | `8000` | 本地启动的后端端口 |

**执行示例**

```powershell
pwsh ./scripts/local/smoke-backend.ps1
pwsh ./scripts/local/smoke-backend.ps1 -Port 18000
pwsh ./scripts/local/smoke-backend.ps1 -BackendRoot "E:\Grade3-2\HomenyOS\XivDaily\backend"
```

**脚本行为**

| 步骤 | 说明 |
| --- | --- |
| 1 | 切换到 `backend/`，设置 `PYTHONPATH` |
| 2 | 调用 `D:\miniconda3\envs\xivdaily\python.exe -m pytest -q -p no:cacheprovider` |
| 3 | 用同一 Python 环境启动 `uvicorn app.main:app` |
| 4 | 请求 `http://127.0.0.1:<Port>/health` |
| 5 | 输出健康检查结果并清理后端进程 |

**注意事项**

- 该脚本当前依赖固定解释器：`D:\miniconda3\envs\xivdaily\python.exe`。
- 如果本机 Conda 环境路径不同，需要先同步调整脚本内容。
- `/health` 返回失败时，脚本会直接以错误状态结束，适合接入本地回归前置检查。

### 2. `release/build-android-apk.ps1`

用于在打包阶段动态注入后端地址，并输出一个带时间戳的 APK 到仓库根目录 `dist/`。

**参数说明**

| 参数 | 类型 | 默认值 | 说明 |
| --- | --- | --- | --- |
| `BackendBaseUrl` | `string` | 必填 | 目标后端地址，必须以 `http://` 或 `https://` 开头 |
| `Variant` | `debug \| release` | `debug` | 构建变体 |
| `ProjectRoot` | `string` | `..\..` 解析后的绝对路径 | 项目根目录 |

**执行示例**

```powershell
pwsh ./scripts/release/build-android-apk.ps1 -BackendBaseUrl "http://10.0.2.2:8000/"
pwsh ./scripts/release/build-android-apk.ps1 -BackendBaseUrl "https://beginnerforever.eu.cc/" -Variant release
```

**脚本行为**

| 步骤 | 说明 |
| --- | --- |
| 1 | 规范化 `BackendBaseUrl`，确保协议和尾部 `/` 存在 |
| 2 | 根据 `Variant` 选择 `:app:assembleDebug` 或 `:app:assembleRelease` |
| 3 | 通过 Gradle 属性注入 `xivdaily.debugBaseUrl` 或 `xivdaily.releaseBaseUrl` |
| 4 | 在 `android/app/build/outputs/apk/<variant>/` 中查找产物 |
| 5 | 复制 APK 到 `dist/xivdaily-<variant>-<timestamp>.apk` |

**注意事项**

- 脚本要求 `android/gradlew.bat` 存在，否则会直接报错。
- `BackendBaseUrl` 会写入构建时属性，不会修改源码里的默认配置。
- `dist/` 目录不存在时会自动创建。

### 3. `deploy/deploy-backend-linux.sh`

用于 Linux 服务器上的 FastAPI 后端初始化与部署。脚本会创建虚拟环境、安装依赖、生成 `.env` 模板、执行 Alembic 迁移，并按需安装 systemd 服务。

**命令选项**

| 选项 | 默认值 | 说明 |
| --- | --- | --- |
| `--host <host>` | `0.0.0.0` | `uvicorn` 监听地址 |
| `--port <port>` | `8000` | `uvicorn` 监听端口 |
| `--install-systemd` | 关闭 | 写入并启用 systemd 服务，需要 `sudo` 或 `root` |
| `--start-foreground` | 关闭 | 在当前 shell 直接前台启动后端 |
| `-h`, `--help` | - | 打印帮助信息 |

**可选环境变量**

| 变量 | 默认值 | 说明 |
| --- | --- | --- |
| `BACKEND_ROOT` | `<project>/backend` | 后端根目录 |
| `VENV_DIR` | `<backend>/.venv` | Python 虚拟环境目录 |
| `APP_HOST` | `0.0.0.0` | 默认服务地址 |
| `APP_PORT` | `8000` | 默认服务端口 |
| `SERVICE_NAME` | `xivdaily-backend` | systemd 服务名称 |

**执行示例**

```bash
bash scripts/deploy/deploy-backend-linux.sh
bash scripts/deploy/deploy-backend-linux.sh --start-foreground --port 18000
sudo bash scripts/deploy/deploy-backend-linux.sh --install-systemd --host 0.0.0.0 --port 8000
```

**脚本行为**

| 步骤 | 说明 |
| --- | --- |
| 1 | 检查 `python3` / `python` 和 `curl` 是否可用 |
| 2 | 创建 `backend/.venv` 并安装 `requirements.txt` |
| 3 | 若 `backend/.env` 不存在，则生成生产模板 |
| 4 | 设置 `PYTHONPATH`，执行 `alembic upgrade head` |
| 5 | 根据选项安装 systemd 服务或前台启动 `uvicorn` |
| 6 | 安装 systemd 时自动请求本机 `/health` 做收尾检查 |

**注意事项**

- 首次生成的 `.env` 只提供模板，`LLM_API_KEY`、`ZOTERO_*` 等敏感配置仍需手工补齐。
- 传入 `--install-systemd` 时会写入 `/etc/systemd/system/<SERVICE_NAME>.service`。
- 如果不安装 systemd，脚本结束后只会输出推荐的手动启动命令。

## ⚡ 常见场景

| 场景 | 推荐脚本 | 典型命令 |
| --- | --- | --- |
| 提交前快速确认后端还能跑 | `local/smoke-backend.ps1` | `pwsh ./scripts/local/smoke-backend.ps1` |
| 打一个指向测试后端的 Debug 包 | `release/build-android-apk.ps1` | `pwsh ./scripts/release/build-android-apk.ps1 -BackendBaseUrl "http://10.0.2.2:8000/"` |
| 打一个指向线上后端的 Release 包 | `release/build-android-apk.ps1` | `pwsh ./scripts/release/build-android-apk.ps1 -BackendBaseUrl "https://beginnerforever.eu.cc/" -Variant release` |
| 在 Linux 服务器上完成后端初始化 | `deploy/deploy-backend-linux.sh` | `bash scripts/deploy/deploy-backend-linux.sh` |
| 以 systemd 托管后端服务 | `deploy/deploy-backend-linux.sh` | `sudo bash scripts/deploy/deploy-backend-linux.sh --install-systemd` |

## 🧩 维护约定

为了保持脚本目录可持续扩展，建议后续新增脚本继续遵循下面的约定：

| 约定 | 说明 |
| --- | --- |
| 分类明确 | 按 `local/`、`release/`、`deploy/` 这类职责目录组织 |
| 可重复执行 | 默认优先无副作用或副作用可预期的实现 |
| 输出清晰 | 至少打印关键路径、关键参数和最终结果 |
| 注释聚焦 | 复杂环境切换、端口处理、路径拼接要写中文注释 |
| 文档同步 | 新增脚本后同步更新本 README 的用途、参数和示例 |

## 📖 相关文档

| 文档 | 说明 |
| --- | --- |
| [`../README.md`](../README.md) | 项目总览、模块说明与快速开始 |
| [`../backend/README.md`](../backend/README.md) | FastAPI 后端结构、配置与验证说明 |
| [`../android/README.md`](../android/README.md) | Android 客户端构建与运行说明 |
| [`../docs/README.md`](../docs/README.md) | 最小化文档索引与补充入口 |
