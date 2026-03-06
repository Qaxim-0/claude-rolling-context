# Install the Rolling Context plugin for Claude Code (Windows)
#
# Run: powershell -ExecutionPolicy Bypass -File install.ps1

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProxyDir = Join-Path $ScriptDir "proxy"
$Port = if ($env:ROLLING_CONTEXT_PORT) { $env:ROLLING_CONTEXT_PORT } else { "5588" }
$ClaudeDir = Join-Path $env:USERPROFILE ".claude"

Write-Host "=== Rolling Context Proxy Installer (Windows) ==="
Write-Host ""

# 1. Check Python is available
Write-Host "[1/3] Checking Python..."
try {
    $pyVersion = python --version 2>&1
    Write-Host "  Found $pyVersion (pure stdlib — no pip install needed)"
} catch {
    Write-Host "  ERROR: Python not found. Install Python 3.7+ and try again."
    exit 1
}

# 2. Configure ANTHROPIC_BASE_URL as user environment variable
Write-Host "[2/3] Configuring ANTHROPIC_BASE_URL..."
$ProxyUrl = "http://127.0.0.1:$Port"
$current = [Environment]::GetEnvironmentVariable("ANTHROPIC_BASE_URL", "User")
if (-not $current) {
    [Environment]::SetEnvironmentVariable("ANTHROPIC_BASE_URL", $ProxyUrl, "User")
    Write-Host "  Set ANTHROPIC_BASE_URL=$ProxyUrl"
} elseif ($current -notmatch "127\.0\.0\.1.*$Port") {
    # Chain through existing proxy
    [Environment]::SetEnvironmentVariable("ROLLING_CONTEXT_UPSTREAM", $current, "User")
    [Environment]::SetEnvironmentVariable("ANTHROPIC_BASE_URL", $ProxyUrl, "User")
    Write-Host "  Chaining: ANTHROPIC_BASE_URL=$ProxyUrl -> upstream=$current"
} else {
    Write-Host "  ANTHROPIC_BASE_URL already set to: $current"
}
$env:ANTHROPIC_BASE_URL = $ProxyUrl

# 3. Register plugin
Write-Host "[3/3] Registering Claude Code plugin..."
$PluginsDir = Join-Path $ClaudeDir "plugins"
$PluginLink = Join-Path $PluginsDir "rolling-context"
if (-not (Test-Path $PluginsDir)) {
    New-Item -ItemType Directory -Path $PluginsDir -Force | Out-Null
}
if (Test-Path $PluginLink) {
    Remove-Item $PluginLink -Recurse -Force
}
cmd /c mklink /J "$PluginLink" "$ScriptDir" | Out-Null
Write-Host "  Plugin linked at $PluginLink"

Write-Host ""
Write-Host "=== Installation Complete ==="
Write-Host ""
Write-Host "The proxy will auto-start when you launch Claude Code."
Write-Host "To start it manually: cd $ProxyDir && python server.py"
Write-Host ""
Write-Host "Configuration (via environment variables):"
Write-Host "  ROLLING_CONTEXT_PORT    = $Port"
$trigger = if ($env:ROLLING_CONTEXT_TRIGGER) { $env:ROLLING_CONTEXT_TRIGGER } else { "80000" }
$target = if ($env:ROLLING_CONTEXT_TARGET) { $env:ROLLING_CONTEXT_TARGET } else { "40000" }
Write-Host "  ROLLING_CONTEXT_TRIGGER = $trigger tokens"
Write-Host "  ROLLING_CONTEXT_TARGET  = $target tokens"
Write-Host ""
Write-Host "Restart your terminal to apply the environment variable."
