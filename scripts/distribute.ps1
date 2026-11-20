param(
    [switch]$SkipBuild
)

$ErrorActionPreference = "Stop"

if (-not $SkipBuild) {
    # pubspec.yaml のビルド番号を自動インクリメント
    dart run tool/bump_version.dart

    Write-Host ">>> [1/3] Building Flutter Release APK (Android)..." -ForegroundColor Cyan
    flutter build apk --release
} else {
    Write-Host ">>> [1/3] Skipping build (using existing APK)..." -ForegroundColor Yellow
}

Write-Host ">>> [2/3] Setting Java environment and uploading to Firebase App Distribution (App Tester)..." -ForegroundColor Cyan
$env:JAVA_HOME = "C:\Program Files\Android\Android Studio\jbr"
$env:Path = "$env:JAVA_HOME\bin;" + $env:Path

Push-Location android
try {
    .\gradlew.bat appDistributionUploadRelease --no-daemon
} finally {
    Pop-Location
}

Write-Host ">>> [3/3] Successfully distributed Android APK to App Tester!" -ForegroundColor Green
