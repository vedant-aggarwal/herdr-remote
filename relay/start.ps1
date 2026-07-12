<#
  herdr-remote relay - Windows launcher. Runs on Windows PowerShell 5.1 and pwsh 7+.

  The relay binds loopback only. `tailscale serve` is the single door in, so the
  UI is reachable from any device on the tailnet and from nowhere else.

  Usage:  .\relay\start.ps1            # live-reload on (edit web/index.html, clients refresh)
          .\relay\start.ps1 -NoDev     # live-reload off
          .\relay\start.ps1 -NoServe   # don't touch tailscale; relay stays localhost-only

  Keep this file pure ASCII. Windows PowerShell 5.1 reads .ps1 as ANSI (cp1252) unless
  the file has a BOM, so a stray non-ASCII character here becomes a parser error.
#>
param(
    [int]$Port = 8375,
    [int]$HttpsPort = 8443,
    [switch]$NoDev,
    [switch]$NoServe
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
$env:PYTHONUNBUFFERED = '1'
$env:PYTHONIOENCODING = 'utf-8'   # relay prints pane glyphs; console default is cp1252
if ($NoDev) { Remove-Item Env:HERDR_DEV -ErrorAction SilentlyContinue } else { $env:HERDR_DEV = '1' }

if (-not $NoServe) {
    # Idempotent: re-running overwrites this same rule and leaves other serve rules alone.
    tailscale serve --bg --https=$HttpsPort "http://127.0.0.1:$Port" | Out-Null

    # PS 5.1's ConvertFrom-Json handles one pipeline item at a time, so multi-line JSON
    # must be joined into a single string first. pwsh 7 tolerates the pipe; 5.1 does not.
    $raw = (tailscale status --json) -join "`n"
    $dns = (ConvertFrom-Json $raw).Self.DNSName.TrimEnd('.')

    Write-Host ""
    Write-Host "  https://${dns}:$HttpsPort" -ForegroundColor Green
    Write-Host "  (tailnet only - open it on your phone with Tailscale on)"
    Write-Host ""
}

# The relay carries its own deps in a PEP 723 header, so uv builds the env from the script.
uv run "$PSScriptRoot\herdr_relay.py"
