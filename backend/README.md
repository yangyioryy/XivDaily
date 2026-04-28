# Backend 占位说明

本目录预留给 Python 后端工程。

## 计划技术栈

- FastAPI
- SQLAlchemy 2
- Alembic
- Pydantic Settings
- httpx
- SQLite

## 目录职责

后续正式搭建时，本目录将至少包含以下内容：

- `app/`：应用入口、路由、配置、数据库、客户端与业务模块。
- `migrations/`：Alembic 迁移脚本。
- `tests/`：后端单元测试与接口测试。
- `.env.example`：环境变量样例，不放真实密钥。
- `requirements.txt` 或等价依赖清单。

## 开发约束

- 运行时敏感信息必须从环境变量注入。
- 关键配置、异常封装、数据库会话和迁移流程代码必须写中文注释。
