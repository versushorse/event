param(
    [switch]$SkipBuild,
    [string]$Version
)

$ErrorActionPreference = "Stop"

if (-not $SkipBuild) {
    # pubspec.yaml のバージョンとビルド番号を自動インクリメント
    $pubspecPath = "pubspec.yaml"
    if (Test-Path $pubspecPath) {
        $content = Get-Content $pubspecPath -Raw
        if ($content -match 'version:\s*([0-9]+\.[0-9]+\.[0-9]+)\+([0-9]+)') {
            $verName = $matches[1]
            $buildNum = [int]$matches[2]

            if ($Version) {
                $verName = $Version
            }
            # ビルド番号を自動でインクリメント
            $newBuildNum = $buildNum + 1
            $newVersionStr = "version: $verName+$newBuildNum"
            $content = $content -replace 'version:\s*[0-9]+\.[0-9]+\.[0-9]+\+[0-9]+', $newVersionStr
            Set-Content -Path $pubspecPath -Value $content -NoNewline
            Write-Host ">>> [Version] Auto-incremented to: $verName (build $newBuildNum)" -ForegroundColor Green
        }
    }

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
