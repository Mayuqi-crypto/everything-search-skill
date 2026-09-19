<#
.SYNOPSIS
    One-click configuration script to enable Everything's HTTP REST Server.
.DESCRIPTION
    Configures Everything to run its built-in HTTP server on port 8080 (or custom port).
    This allows sandboxed agents (Docker, WSL, DevContainers, Session 0 services)
    to access the Everything index via standard HTTP REST API without Win32 IPC issues.
.PARAMETER Port
    HTTP server port (default: 8080).
#>

[CmdletBinding()]
param(
    [int]$Port = 8080
)

$ErrorActionPreference = "Stop"

Write-Host "=== Enabling Everything HTTP REST Server (Port $Port) ===" -ForegroundColor Cyan

# 1. Check if Everything is installed
$evExePaths = @(
    "C:\Program Files\Everything\Everything.exe",
    "C:\Program Files (x86)\Everything\Everything.exe",
    (Join-Path $env:LOCALAPPDATA "Programs\Everything\Everything.exe")
)
$evExe = $null
foreach ($p in $evExePaths) {
    if (Test-Path $p) { $evExe = $p; break }
}

if (-not $evExe) {
    Write-Error "Everything.exe was not found. Please install Everything from https://www.voidtools.com/ first."
    exit 1
}

# 2. Exit running Everything to cleanly write ini
Write-Host "[1/4] Stopping active Everything instances..." -ForegroundColor Gray
& $evExe -exit 2>$null
Start-Sleep -Seconds 1

# 3. Locate and update Everything.ini
$iniPaths = @(
    "$env:APPDATA\Everything\Everything.ini",
    "C:\Program Files\Everything\Everything.ini"
)

$updatedAny = $false
foreach ($ini in $iniPaths) {
    if (Test-Path $ini) {
        try {
            $lines = Get-Content $ini
            $newLines = @()
            $hasAllow = $false
            $hasEnabled = $false
            $hasPort = $false

            foreach ($line in $lines) {
                if ($line -match "^allow_http_server=") {
                    $newLines += "allow_http_server=1"
                    $hasAllow = $true
                } elseif ($line -match "^http_server_enabled=") {
                    $newLines += "http_server_enabled=1"
                    $hasEnabled = $true
                } elseif ($line -match "^http_server_port=") {
                    $newLines += "http_server_port=$Port"
                    $hasPort = $true
                } else {
                    $newLines += $line
                    if ($line -eq "[Everything]" -and -not $hasAllow) {
                        $newLines += "allow_http_server=1"
                        $hasAllow = $true
                    }
                }
            }
            if (-not $hasEnabled) { $newLines += "http_server_enabled=1" }
            if (-not $hasPort) { $newLines += "http_server_port=$Port" }

            [System.IO.File]::WriteAllLines($ini, $newLines, [System.Text.Encoding]::UTF8)
            Write-Host "[2/4] Successfully configured: $ini" -ForegroundColor Green
            $updatedAny = $true
        } catch {
            Write-Warning "Could not write to $ini : $($_.Exception.Message)"
        }
    }
}

# 4. Restart Everything in background via official -startup flag
Write-Host "[3/4] Restarting Everything with -startup flag..." -ForegroundColor Gray
Start-Process -FilePath $evExe -ArgumentList "-startup"
Start-Sleep -Seconds 2

# 5. Verify HTTP connectivity
Write-Host "[4/4] Verifying HTTP connectivity on http://127.0.0.1:$Port ..." -ForegroundColor Gray
$connected = $false
for ($i = 0; $i -lt 5; $i++) {
    try {
        $resp = Invoke-RestMethod -Uri "http://127.0.0.1:$Port/?search=Everything.exe&json=1&count=1" -TimeoutSec 2 -UseBasicParsing -ErrorAction Stop
        if ($resp -and $resp.results) {
            $connected = $true
            break
        }
    } catch {
        Start-Sleep -Milliseconds 600
    }
}

if ($connected) {
    Write-Host "`n[SUCCESS] Everything HTTP Server is active and listening on port $Port!" -ForegroundColor Green
    Write-Host "Sandboxed Agents & Docker containers can now query host files via:" -ForegroundColor Cyan
    Write-Host "  - Windows Host: http://127.0.0.1:$Port" -ForegroundColor Yellow
    Write-Host "  - Docker Container: http://host.docker.internal:$Port" -ForegroundColor Yellow
    Write-Host "  - WSL2: http://`$(hostname).local:$Port or host gateway IP" -ForegroundColor Yellow
} else {
    Write-Warning "Everything restarted, but HTTP port $Port didn't respond immediately. Please verify in Everything -> Tools -> Options -> HTTP Server."
}
