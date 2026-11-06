param(
    [switch]$SkipBuild
)

$ErrorActionPreference = "Stop"

if (-not $SkipBuild) {
    Write-Host ">>> [1/3] Building Flutter Release APK..." -ForegroundColor Cyan
    flutter build apk --release
} else {
    Write-Host ">>> [1/3] Skipping build (using existing APK)..." -ForegroundColor Yellow
}

Write-Host ">>> [2/3] Setting Java environment and uploading to Firebase..." -ForegroundColor Cyan
$env:JAVA_HOME = "C:\Program Files\Android\Android Studio\jbr"
$env:Path = "$env:JAVA_HOME\bin;" + $env:Path

Push-Location android
try {
    .\gradlew.bat appDistributionUploadRelease --no-daemon
} finally {
    Pop-Location
}

Write-Host ">>> [3/3] Successfully distributed to testers!" -ForegroundColor Green
