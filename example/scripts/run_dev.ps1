# Run Flutter app in Chrome with CORS disabled for web development
# Usage:
#   .\scripts\run_dev.ps1

Write-Host "Launching AI Grid in Chrome with web security disabled for local development..." -ForegroundColor Green
Write-Host "This bypasses browser CORS restrictions when making direct calls to api.mistral.ai, api.openai.com, etc." -ForegroundColor Cyan
Write-Host ""

flutter run -d chrome --web-browser-flag "--disable-web-security" --web-browser-flag "--user-data-dir=C:\temp\chrome_dev_ai_grid"
