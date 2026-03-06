# Uninstall the Rolling Context plugin (Windows)
#
# Run: powershell -ExecutionPolicy Bypass -File uninstall.ps1

$ErrorActionPreference = "Stop"

$ClaudeDir = Join-Path $env:USERPROFILE ".claude"
$PidFile = Join-Path $ClaudeDir "rolling-context-proxy.pid"
$PluginLink = Join-Path $ClaudeDir "plugins\rolling-context"

Write-Host "=== Uninstalling Rolling Context ==="

# Stop proxy if running
if (Test-Path $PidFile) {
    $pid = Get-Content $PidFile
    try {
        $proc = Get-Process -Id $pid -ErrorAction SilentlyContinue
        if ($proc) {
            Stop-Process -Id $pid -Force
            Write-Host "Stopped proxy (PID $pid)"
        }
    } catch {}
    Remove-Item $PidFile -Force
}

# Remove plugin link
if (Test-Path $PluginLink) {
    Remove-Item $PluginLink -Recurse -Force
    Write-Host "Removed plugin link"
}

# Remove ANTHROPIC_BASE_URL if it points to our proxy
$current = [Environment]::GetEnvironmentVariable("ANTHROPIC_BASE_URL", "User")
if ($current -and $current -match "127\.0\.0\.1.*5588") {
    [Environment]::SetEnvironmentVariable("ANTHROPIC_BASE_URL", $null, "User")
    Write-Host "Removed ANTHROPIC_BASE_URL environment variable"
}

Write-Host ""
Write-Host "Uninstalled. Restart your terminal to complete."
