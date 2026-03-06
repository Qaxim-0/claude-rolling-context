# Auto-start the rolling context proxy if it's not already running (Windows)

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProxyDir = Join-Path $ScriptDir "..\proxy"
$ClaudeDir = Join-Path $env:USERPROFILE ".claude"
$PidFile = Join-Path $ClaudeDir "rolling-context-proxy.pid"
$LogFile = Join-Path $ClaudeDir "rolling-context-proxy.log"
$Port = if ($env:ROLLING_CONTEXT_PORT) { $env:ROLLING_CONTEXT_PORT } else { "5588" }

# Check if proxy is already running
if (Test-Path $PidFile) {
    $pid = Get-Content $PidFile
    try {
        $proc = Get-Process -Id $pid -ErrorAction SilentlyContinue
        if ($proc) { exit 0 }
    } catch {}
    Remove-Item $PidFile -Force
}

# Check if something is already listening
try {
    $response = Invoke-WebRequest -Uri "http://127.0.0.1:$Port/health" -UseBasicParsing -TimeoutSec 2 -ErrorAction SilentlyContinue
    if ($response.StatusCode -eq 200) { exit 0 }
} catch {}

# Set up venv if needed
Push-Location $ProxyDir
if (-not (Test-Path "venv")) {
    python -m venv venv
    & .\venv\Scripts\pip.exe install -q -r requirements.txt
}

# Start the proxy in the background
$proc = Start-Process -FilePath ".\venv\Scripts\python.exe" -ArgumentList "server.py" `
    -RedirectStandardOutput $LogFile -RedirectStandardError $LogFile `
    -WindowStyle Hidden -PassThru
$proc.Id | Out-File -FilePath $PidFile -NoNewline
Pop-Location

# Wait and verify
Start-Sleep -Seconds 2
try {
    $response = Invoke-WebRequest -Uri "http://127.0.0.1:$Port/health" -UseBasicParsing -TimeoutSec 2 -ErrorAction SilentlyContinue
    if ($response.StatusCode -eq 200) {
        Write-Host "Rolling context proxy started on port $Port"
    }
} catch {
    Write-Host "Warning: Rolling context proxy may not have started correctly. Check $LogFile" -ForegroundColor Yellow
}

exit 0
