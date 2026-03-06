# Auto-start the rolling context proxy if it's not already running (Windows)
# Also ensures ANTHROPIC_BASE_URL is set for future sessions.

$ErrorActionPreference = "SilentlyContinue"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProxyDir = Join-Path $ScriptDir "..\proxy"
$ClaudeDir = Join-Path $env:USERPROFILE ".claude"
$PidFile = Join-Path $ClaudeDir "rolling-context-proxy.pid"
$LogFile = Join-Path $ClaudeDir "rolling-context-proxy.log"
$Port = if ($env:ROLLING_CONTEXT_PORT) { $env:ROLLING_CONTEXT_PORT } else { "5588" }
$ProxyUrl = "http://127.0.0.1:$Port"

# Ensure ANTHROPIC_BASE_URL is set for future sessions
$currentUrl = [Environment]::GetEnvironmentVariable("ANTHROPIC_BASE_URL", "User")
if (-not $currentUrl) {
    [Environment]::SetEnvironmentVariable("ANTHROPIC_BASE_URL", $ProxyUrl, "User")
    Write-Host "Rolling context: set ANTHROPIC_BASE_URL=$ProxyUrl (restart terminal to activate)"
}

# Check if proxy is already running via PID
if (Test-Path $PidFile) {
    $savedPid = Get-Content $PidFile -ErrorAction SilentlyContinue
    if ($savedPid) {
        $proc = Get-Process -Id $savedPid -ErrorAction SilentlyContinue
        if ($proc) { exit 0 }
    }
    Remove-Item $PidFile -Force -ErrorAction SilentlyContinue
}

# Check if something is already listening on the port
try {
    $response = Invoke-WebRequest -Uri "$ProxyUrl/health" -UseBasicParsing -TimeoutSec 2 -ErrorAction Stop
    if ($response.StatusCode -eq 200) { exit 0 }
} catch {}

# Set up venv if needed
Push-Location $ProxyDir
if (-not (Test-Path "venv\Scripts\python.exe")) {
    try {
        python -m venv venv 2>&1 | Out-Null
        & .\venv\Scripts\pip.exe install -q -r requirements.txt 2>&1 | Out-Null
    } catch {
        Write-Host "Rolling context: failed to create venv"
        Pop-Location
        exit 1
    }
}

# Start the proxy in the background
try {
    $proc = Start-Process -FilePath ".\venv\Scripts\python.exe" -ArgumentList "server.py" `
        -RedirectStandardOutput $LogFile -RedirectStandardError "$LogFile.err" `
        -WindowStyle Hidden -PassThru
    $proc.Id | Out-File -FilePath $PidFile -NoNewline
} catch {
    Write-Host "Rolling context: failed to start proxy"
    Pop-Location
    exit 1
}
Pop-Location

# Wait and verify
Start-Sleep -Seconds 2
try {
    $response = Invoke-WebRequest -Uri "$ProxyUrl/health" -UseBasicParsing -TimeoutSec 2 -ErrorAction Stop
    if ($response.StatusCode -eq 200) {
        Write-Host "Rolling context proxy started on port $Port"
    }
} catch {
    Write-Host "Warning: Rolling context proxy may not have started correctly. Check $LogFile"
}

exit 0
