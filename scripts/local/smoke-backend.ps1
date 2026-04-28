param(
    [string]$BackendRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\backend')).Path
)

# 这份脚本用于本机快速冒烟验证，先跑测试，再做健康检查。
Set-Location $BackendRoot

$python = "D:\miniconda3\envs\xivdaily\python.exe"
& $python -m pytest tests -q
& $python -m uvicorn app.main:app --host 127.0.0.1 --port 8000

