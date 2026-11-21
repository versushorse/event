# 商用公開用Web版（おでかけナビ）のビルド＆Firebase Hostingデプロイスクリプト
# ※ プライベート用GitHub Pages（gh-pages / web_app）とは完全に分離されており、そちらは上書きしません。
$ErrorActionPreference = "Stop"

$webRoot = $PSScriptRoot
$repoRoot = Split-Path $webRoot -Parent

Push-Location $webRoot
try {
    Write-Host ">>> [商用Web 1/2] Building Flutter Web release bundle (web_commercial/)..." -ForegroundColor Cyan
    flutter build web --release
} finally {
    Pop-Location
}

Push-Location $repoRoot
try {
    Write-Host ">>> [商用Web 2/2] Deploying web_commercial/build/web to Firebase Hosting..." -ForegroundColor Cyan
    if (Get-Command firebase -ErrorAction SilentlyContinue) {
        firebase deploy --only hosting
    } else {
        npx firebase-tools@latest deploy --only hosting
    }
    Write-Host ">>> Successfully deployed commercial Web app to Firebase Hosting!" -ForegroundColor Green
} finally {
    Pop-Location
}
