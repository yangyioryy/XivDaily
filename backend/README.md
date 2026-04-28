# Backend 占位说明

本目录现已升级为最小可运行的 Python 后端骨架。

## 当前已落地能力

- FastAPI 应用入口
- 环境变量配置读取
- 统一日志与异常返回
- `GET /health` 健康检查
- SQLite 会话工厂
- Alembic 初始化迁移脚本
- 基础测试 `tests/test_health.py`

## 运行方式

1. 在 `xivdaily` conda 环境安装依赖：
   `conda run -n xivdaily pip install -r backend/requirements.txt`
2. 在 `backend/` 目录执行迁移：
   `conda run -n xivdaily alembic upgrade head`
3. 启动服务：
   `conda run -n xivdaily uvicorn app.main:app --host 127.0.0.1 --port 8000`

## 开发约束

- 运行时敏感信息必须从环境变量注入。
- 关键配置、异常封装、数据库会话和迁移流程代码必须写中文注释。
