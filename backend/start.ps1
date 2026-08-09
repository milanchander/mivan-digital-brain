# Mivan Digital Brain - chat backend launcher (Windows PowerShell)
# Creates a local venv, installs deps, and starts the WebSocket server.

$ErrorActionPreference = "Stop"
Set-Location -Path $PSScriptRoot

if (-not (Test-Path ".venv")) {
    Write-Host "Creating virtual environment..." -ForegroundColor Cyan
    python -m venv .venv
}

# Activate venv
& ".\.venv\Scripts\Activate.ps1"

Write-Host "Installing dependencies..." -ForegroundColor Cyan
python -m pip install --quiet --upgrade pip
python -m pip install --quiet -r requirements.txt

Write-Host "Starting Digital Brain chat backend on http://127.0.0.1:8000 ..." -ForegroundColor Green
Write-Host "(No API key needed - auth comes from your Claude Code login.)" -ForegroundColor DarkGray
python app.py
