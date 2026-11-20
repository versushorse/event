$ErrorActionPreference = "Stop"

Push-Location $PSScriptRoot
try {
    Write-Host ">>> [Web 1/2] Building Flutter Web release bundle..." -ForegroundColor Cyan
    flutter build web --base-href "/event/" --release

    Write-Host ">>> [Web 2/2] Deploying to GitHub Pages (gh-pages)..." -ForegroundColor Cyan
    Push-Location build\web
    try {
        if (-not (Test-Path .git)) {
            git init
            git checkout -b gh-pages
            git remote add origin https://github.com/versushorse/event.git
            git fetch origin gh-pages
            git reset --soft origin/gh-pages
        }
        git add .
        $status = git status --porcelain
        if ($status) {
            git commit -m "Deploy standalone Web app from web_app/"
            git push origin gh-pages
            Write-Host ">>> Successfully deployed Web app to GitHub Pages!" -ForegroundColor Green
        } else {
            Write-Host ">>> No changes detected in Web build." -ForegroundColor Yellow
        }
    } finally {
        Pop-Location
    }
} finally {
    Pop-Location
}
