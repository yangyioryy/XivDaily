# VPS 部署说明

## 部署原则

- 后端以环境变量驱动配置，避免硬编码本机路径。
- SQLite 仅作为首版单机轻量存储；后续如迁移数据库，只改配置层和迁移脚本。
- Android 客户端通过可配置 Base URL 访问后端，不把开发地址写死为唯一值。

## 部署步骤

1. 在 VPS 上创建 `xivdaily` 运行环境，安装后端依赖。
2. 配置数据库路径、`LLM_*`、`ZOTERO_*` 等环境变量。
3. 运行 Alembic 迁移。
4. 使用 `uvicorn` 或服务管理器启动后端。
5. 将 Android 客户端中的 Base URL 指向部署地址。

## 一键脚本

在 Linux 服务器上进入项目根目录后执行：

```bash
bash scripts/deploy/deploy-backend-linux.sh --host 0.0.0.0 --port 8000 --install-systemd
```

脚本会完成这些操作：

- 创建 `backend/.venv`。
- 安装 `backend/requirements.txt`。
- 创建 `backend/data/`。
- 如果 `backend/.env` 不存在，则生成一份生产环境模板。
- 执行 `alembic upgrade head`。
- 使用 systemd 注册并启动 `xivdaily-backend`。
- 请求 `http://127.0.0.1:8000/health` 做冒烟检查。

敏感配置不要写入仓库。首次部署后在服务器上编辑：

```bash
nano backend/.env
```

至少确认这些配置：

```env
APP_ENV=production
APP_HOST=0.0.0.0
APP_PORT=8000
LLM_API_KEY=
ZOTERO_USER_ID=
ZOTERO_API_KEY=
ZOTERO_TARGET_COLLECTION_NAME=XivDaily
```

## Android 真机测试包

后端公网地址确定后，在本机项目根目录执行：

```powershell
.\scripts\release\build-android-apk.ps1 -BackendBaseUrl "http://你的服务器IP:8000/" -Variant debug
```

脚本会调用 Gradle 构建 debug APK，并把产物复制到 `dist/` 目录。debug 包用于真机测试；正式分发前需要另行配置 release 签名。
