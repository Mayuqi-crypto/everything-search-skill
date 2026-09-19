<#
.SYNOPSIS
    One-click installer for Everything Search Agent Skill.
.DESCRIPTION
    1. Installs es.exe to ~/.local/bin (and ensures ~/.local/bin is in User PATH).
    2. Installs the skill into ~/.agents/skills/, ~/.cursor/skills/, and ~/.codex/skills/.
#>

$ErrorActionPreference = "Stop"

Write-Host "=== Installing Everything Search Skill ===" -ForegroundColor Cyan

$scriptRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$binSource = Join-Path $scriptRoot "bin\es.exe"
$localBin = Join-Path $env:USERPROFILE ".local\bin"

# 1. Install es.exe to ~/.local/bin
if (-not (Test-Path $localBin)) {
    New-Item -ItemType Directory -Path $localBin -Force | Out-Null
}

if (Test-Path $binSource) {
    Copy-Item -Path $binSource -Destination (Join-Path $localBin "es.exe") -Force
    Write-Host "[OK] es.exe copied to $localBin\es.exe" -ForegroundColor Green
} else {
    Write-Warning "bin/es.exe not found in repo. Downloading from voidtools.com..."
    $zipTemp = "$env:TEMP\es.zip"
    Invoke-WebRequest -Uri "https://www.voidtools.com/es.zip" -OutFile $zipTemp -UseBasicParsing
    Expand-Archive -Path $zipTemp -DestinationPath "$env:TEMP\es_temp" -Force
    Copy-Item -Path "$env:TEMP\es_temp\es.exe" -Destination (Join-Path $localBin "es.exe") -Force
    Remove-Item -Recurse -Force "$env:TEMP\es_temp", $zipTemp
    Write-Host "[OK] Downloaded and installed es.exe to $localBin\es.exe" -ForegroundColor Green
}

# 2. Check User PATH
$userPath = [Environment]::GetEnvironmentVariable("Path", "User")
if ($userPath -notlike "*$localBin*") {
    $newUserPath = "$userPath;$localBin"
    [Environment]::SetEnvironmentVariable("Path", $newUserPath, "User")
    $env:Path += ";$localBin"
    Write-Host "[OK] Added $localBin to User PATH environment variable." -ForegroundColor Green
} else {
    Write-Host "[OK] $localBin is already in User PATH." -ForegroundColor Gray
}

# 3. Target skill locations
$targetDirs = @(
    (Join-Path $env:USERPROFILE ".agents\skills\everything-search"),
    (Join-Path $env:USERPROFILE ".cursor\skills\everything-search"),
    (Join-Path $env:USERPROFILE ".codex\skills\everything-search")
)

foreach ($target in $targetDirs) {
    if (-not (Test-Path $target)) {
        New-Item -ItemType Directory -Path $target -Force | Out-Null
    }
    Copy-Item -Path (Join-Path $scriptRoot "SKILL.md") -Destination (Join-Path $target "SKILL.md") -Force
    
    $targetBin = Join-Path $target "bin"
    if (-not (Test-Path $targetBin)) { New-Item -ItemType Directory -Path $targetBin -Force | Out-Null }
    Copy-Item -Path $binSource -Destination (Join-Path $targetBin "es.exe") -Force

    $targetScripts = Join-Path $target "scripts"
    if (-not (Test-Path $targetScripts)) { New-Item -ItemType Directory -Path $targetScripts -Force | Out-Null }
    Copy-Item -Path (Join-Path $scriptRoot "scripts\*") -Destination $targetScripts -Recurse -Force

    Write-Host "[OK] Installed skill to: $target" -ForegroundColor Green
}

Write-Host "`nEverything Search Skill has been installed successfully!" -ForegroundColor Cyan
Write-Host "Test with: es.exe -n 5 Everything.exe" -ForegroundColor Yellow
