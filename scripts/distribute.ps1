param(
    [switch]$SkipBuild
)

$ErrorActionPreference = "Stop"

if (-not $SkipBuild) {
    # pubspec.yaml のビルド番号を自動インクリメント
    dart run tool/bump_version.dart

    Write-Host ">>> [1/4] Building Flutter Release APK..." -ForegroundColor Cyan
    flutter build apk --release
} else {
    Write-Host ">>> [1/4] Skipping build (using existing APK)..." -ForegroundColor Yellow
}

Write-Host ">>> [2/4] Setting Java environment and uploading to Firebase..." -ForegroundColor Cyan
$env:JAVA_HOME = "C:\Program Files\Android\Android Studio\jbr"
$env:Path = "$env:JAVA_HOME\bin;" + $env:Path

Push-Location android
try {
    .\gradlew.bat appDistributionUploadRelease --no-daemon
} finally {
    Pop-Location
}

Write-Host ">>> [3/4] Successfully distributed APK to Android testers!" -ForegroundColor Green

if (-not $SkipBuild) {
    Write-Host ">>> [4/4] Building and deploying Web version (for iPhone) to GitHub Pages..." -ForegroundColor Cyan
    flutter build web --base-href "/event/" --release
    Push-Location build\web
    if (-not (Test-Path .git)) {
        git init
        git checkout -b gh-pages
        git remote add origin https://github.com/versushorse/event.git
    }
    git add .
    git commit -m "Deploy Web app to GitHub Pages"
    git push -f origin gh-pages
    Pop-Location
    Write-Host ">>> Successfully deployed to GitHub Pages for iPhone!" -ForegroundColor Green
}
