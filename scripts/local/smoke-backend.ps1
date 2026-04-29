param(
    [string]$BackendRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\backend')).Path,
    [int]$Port = 8000
)

# 这份脚本用于本机快速冒烟验证：先跑测试，再启动后端并请求 /health，最后清理进程。
Push-Location -LiteralPath $BackendRoot
try {
    $previousPythonPath = $env:PYTHONPATH
    $env:PYTHONPATH = $BackendRoot
    & 'D:\miniconda3\envs\xivdaily\python.exe' -m pytest -q -p no:cacheprovider
    if ($LASTEXITCODE -ne 0) {
        exit $LASTEXITCODE
    }

    $process = Start-Process -FilePath 'D:\miniconda3\envs\xivdaily\python.exe' -ArgumentList @('-m', 'uvicorn', 'app.main:app', '--host', '127.0.0.1', '--port', $Port) -WorkingDirectory $BackendRoot -PassThru -WindowStyle Hidden
    try {
        Start-Sleep -Seconds 2
        $response = Invoke-RestMethod -Uri "http://127.0.0.1:$Port/health"
        $response | ConvertTo-Json -Compress
    }
    finally {
        if ($process -and -not $process.HasExited) {
            Stop-Process -Id $process.Id -Force
        }
        $env:PYTHONPATH = $previousPythonPath
    }
}
finally {
    Pop-Location
}
