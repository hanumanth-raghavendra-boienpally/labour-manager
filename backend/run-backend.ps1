# Starts the backend. Database settings come from backend\.env (see .env.example) - nothing to set per window.
Set-Location $PSScriptRoot
if (-not (Test-Path .env)) {
    Copy-Item .env.example .env
    Write-Host "Created .env from .env.example." -ForegroundColor Yellow
    Write-Host "Open backend\.env, fill in DB1_URL and DB2_URL, save, then run this again." -ForegroundColor Yellow
    notepad .env
    exit 1
}
mvn spring-boot:run
