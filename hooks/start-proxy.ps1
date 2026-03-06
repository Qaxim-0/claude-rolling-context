# Ensure rolling context proxy is running (Windows)
# Pure stdlib — no venv needed, just python

$ErrorActionPreference = "SilentlyContinue"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProxyDir = Join-Path $ScriptDir "..\proxy"
$ClaudeDir = Join-Path $env:USERPROFILE ".claude"
$PidFile = Join-Path $ClaudeDir "rolling-context-proxy.pid"
$HookLog = Join-Path $ClaudeDir "rolling-context-hook.log"
$ProxyLog = Join-Path $ClaudeDir "rolling-context-proxy.log"
$Port = if ($env:ROLLING_CONTEXT_PORT) { $env:ROLLING_CONTEXT_PORT } else { "5588" }
$ProxyUrl = "http://127.0.0.1:$Port"

function Log($msg) {
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content -Path $HookLog -Value "[$ts] $msg"
}

Log "Hook started. ProxyDir=$ProxyDir"

# Fast check: is proxy already running?
if (Test-Path $PidFile) {
    $savedPid = Get-Content $PidFile -ErrorAction SilentlyContinue
    if ($savedPid) {
        $proc = Get-Process -Id $savedPid -ErrorAction SilentlyContinue
        if ($proc) {
            Log "Proxy already running (PID $savedPid)"
            exit 0
        }
    }
    Remove-Item $PidFile -Force -ErrorAction SilentlyContinue
}

# Ensure ANTHROPIC_BASE_URL is set for future sessions
$currentUrl = [Environment]::GetEnvironmentVariable("ANTHROPIC_BASE_URL", "User")
if (-not $currentUrl) {
    [Environment]::SetEnvironmentVariable("ANTHROPIC_BASE_URL", $ProxyUrl, "User")
    Log "Set ANTHROPIC_BASE_URL=$ProxyUrl"
} elseif ($currentUrl -notmatch "127\.0\.0\.1.*$Port") {
    [Environment]::SetEnvironmentVariable("ROLLING_CONTEXT_UPSTREAM", $currentUrl, "User")
    [Environment]::SetEnvironmentVariable("ANTHROPIC_BASE_URL", $ProxyUrl, "User")
    Log "Chaining: upstream=$currentUrl"
} else {
    Log "ANTHROPIC_BASE_URL already set"
}

# Start proxy directly with system python — no venv needed
Log "Starting proxy..."
$proc = Start-Process -FilePath "python" -ArgumentList "server.py" `
    -WorkingDirectory $ProxyDir `
    -RedirectStandardOutput $ProxyLog -RedirectStandardError "$ProxyLog.err" `
    -WindowStyle Hidden -PassThru
$proc.Id | Out-File -FilePath $PidFile -NoNewline
Log "Proxy started with PID $($proc.Id)"

exit 0
