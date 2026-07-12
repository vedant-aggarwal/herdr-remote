#Requires -Version 7
<#
  herdr-remote relay — Windows launcher.

  The relay binds loopback only. `tailscale serve` is the single door in, so the
  UI is reachable from any device on the tailnet and from nowhere else.

  Usage:  .\relay\start.ps1            # live-reload on (edit web/index.html, clients refresh)
          .\relay\start.ps1 -NoDev     # live-reload off
#>
param(
    [int]$Port = 8375,
    [int]$HttpsPort = 8443,
    [switch]$NoDev,
    [switch]$NoServe   # skip the tailscale serve rule (relay stays localhost-only)
)

$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent

# Free the port if a previous relay is still holding it.
$stale = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue
foreach ($c in $stale) {
    Write-Host "killing stale listener on :$Port (PID $($c.OwningProcess))"
    Stop-Process -Id $c.OwningProcess -Force -ErrorAction SilentlyContinue
}

$env:HERDR_RELAY_HOST = '127.0.0.1'
$env:HERDR_RELAY_PORT = "$Port"
$env:HERDR_WEB_DIR    = Join-Path $root 'web'
if (-not $NoDev) { $env:HERDR_DEV = '1' } else { Remove-Item Env:HERDR_DEV -ErrorAction SilentlyContinue }

if (-not $NoServe) {
    # Idempotent: re-running just overwrites the same rule. Leaves other serve rules alone.
    tailscale serve --bg --https=$HttpsPort "http://127.0.0.1:$Port" | Out-Null
    $host_ = (tailscale status --json | ConvertFrom-Json).Self.DNSName.TrimEnd('.')
    Write-Host ""
    Write-Host "  https://${host_}:$HttpsPort" -ForegroundColor Green
    Write-Host "  (tailnet only — open it on your phone with Tailscale on)"
    Write-Host ""
}

# The script carries its own deps (PEP 723 header), so uv builds the env from it.
uv run "$PSScriptRoot\herdr_relay.py"
