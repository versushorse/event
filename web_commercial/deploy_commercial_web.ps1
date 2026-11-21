# 商用公開用Web版（おでかけナビ）のビルド＆Firebase Hostingデプロイスクリプト
# ※ プライベート用GitHub Pages（gh-pages / web_app）とは完全に分離されており、そちらは上書きしません。
$ErrorActionPreference = "Stop"

$webRoot = $PSScriptRoot
$repoRoot = Split-Path $webRoot -Parent
$nodeDir = "C:\Program Files\nodejs"
if ((Test-Path $nodeDir) -and -not ($env:PATH -split ";" | Where-Object { $_ -eq $nodeDir })) {
    $env:PATH = "$nodeDir;$env:PATH"
}
$npxCmd = if (Get-Command npx.cmd -ErrorAction SilentlyContinue) {
    "npx.cmd"
} elseif (Test-Path "$nodeDir\npx.cmd") {
    "$nodeDir\npx.cmd"
} else {
    throw "npx.cmd が見つかりません。Node.js (LTS) をインストールしてください。"
}

Push-Location $webRoot
try {
    Write-Host ">>> [商用Web 1/2] Building Flutter Web release bundle (web_commercial/)..." -ForegroundColor Cyan
    flutter build web --release
    if ($LASTEXITCODE -ne 0) {
        throw "flutter build web --release failed with exit code $LASTEXITCODE"
    }
} finally {
    Pop-Location
}

Push-Location $repoRoot
try {
    Write-Host ">>> [商用Web 2/2] Deploying web_commercial/build/web to Firebase Hosting..." -ForegroundColor Cyan
    & $npxCmd -y firebase-tools@latest deploy --only hosting
    if ($LASTEXITCODE -ne 0) {
        throw "firebase deploy failed with exit code $LASTEXITCODE"
    }
    Write-Host ">>> Successfully deployed commercial Web app to Firebase Hosting!" -ForegroundColor Green
} finally {
    Pop-Location
}
