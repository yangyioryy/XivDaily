param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$BackendBaseUrl,

    [ValidateSet('debug', 'release')]
    [string]$Variant = 'debug',

    [string]$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
)

$ErrorActionPreference = 'Stop'

function Normalize-BaseUrl {
    param([string]$Value)
    $trimmed = $Value.Trim()
    if ($trimmed -notmatch '^https?://') {
        throw "BackendBaseUrl must start with http:// or https://."
    }
    if ($trimmed.EndsWith('/')) {
        return $trimmed
    }
    return "$trimmed/"
}

$normalizedBaseUrl = Normalize-BaseUrl -Value $BackendBaseUrl
$androidRoot = Join-Path $ProjectRoot 'android'
$gradleWrapper = Join-Path $androidRoot 'gradlew.bat'
$distRoot = Join-Path $ProjectRoot 'dist'

if (-not (Test-Path -LiteralPath $gradleWrapper)) {
    throw "Gradle Wrapper was not found: $gradleWrapper"
}

New-Item -ItemType Directory -Force -Path $distRoot | Out-Null

$taskName = if ($Variant -eq 'release') { ':app:assembleRelease' } else { ':app:assembleDebug' }
$propertyName = if ($Variant -eq 'release') { 'xivdaily.releaseBaseUrl' } else { 'xivdaily.debugBaseUrl' }

Write-Host "Backend Base URL: $normalizedBaseUrl"
Write-Host "Gradle task: $taskName"

Push-Location -LiteralPath $androidRoot
try {
    & $gradleWrapper $taskName "-P$propertyName=$normalizedBaseUrl" --no-daemon --console=plain
    if ($LASTEXITCODE -ne 0) {
        exit $LASTEXITCODE
    }
}
finally {
    Pop-Location
}

$variantDir = if ($Variant -eq 'release') { 'release' } else { 'debug' }
$sourceApk = Join-Path $androidRoot "app\build\outputs\apk\$variantDir\app-$variantDir.apk"
if (-not (Test-Path -LiteralPath $sourceApk)) {
    throw "APK output was not found: $sourceApk"
}

$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$targetApk = Join-Path $distRoot "xivdaily-$Variant-$timestamp.apk"
Copy-Item -LiteralPath $sourceApk -Destination $targetApk -Force

Write-Host "APK output: $targetApk"
