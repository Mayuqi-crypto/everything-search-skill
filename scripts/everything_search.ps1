<#
.SYNOPSIS
    Search files and folders using Everything (es.exe) with structured output.
.DESCRIPTION
    Wraps es.exe to provide fast searching with automatic binary detection,
    sensible default limits, directory scoping, and JSON/Table output formats.
.PARAMETER Query
    The Everything search query (e.g. "config *.json", "ext:py size:>1MB").
.PARAMETER Path
    Limit search to subfolders and files in this path.
.PARAMETER Limit
    Maximum results to return. Default is 25.
.PARAMETER Type
    Filter results by type: 'file', 'dir' / 'folder', or 'all'. Default is 'all'.
.PARAMETER Sort
    Sort criteria: 'default', 'dm' (date modified desc), 'size' (size desc), 'name'.
.PARAMETER AsJson
    Output results as JSON string instead of text lines.
.EXAMPLE
    .\everything_search.ps1 -Query "package.json" -Limit 10
    .\everything_search.ps1 -Query "*.log" -Path "C:\MyApp" -Sort dm -Limit 5
    .\everything_search.ps1 -Query "ext:png" -Type file -AsJson
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$Query,

    [Parameter(Position = 1)]
    [string]$Path = "",

    [int]$Limit = 25,

    [ValidateSet("all", "file", "dir", "folder")]
    [string]$Type = "all",

    [ValidateSet("default", "dm", "size", "name")]
    [string]$Sort = "default",

    [switch]$AsJson
)

# 1. Locate es.exe
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$possibleEsPaths = @(
    "es.exe",
    (Join-Path $scriptDir "..\bin\es.exe"),
    (Join-Path $env:USERPROFILE ".local\bin\es.exe"),
    "C:\Program Files\Everything\es.exe",
    "C:\Program Files (x86)\Everything\es.exe"
)

$esBinary = $null
foreach ($candidate in $possibleEsPaths) {
    if (Get-Command $candidate -ErrorAction SilentlyContinue) {
        $esBinary = (Get-Command $candidate).Source
        break
    } elseif (Test-Path $candidate) {
        $esBinary = (Resolve-Path $candidate).Path
        break
    }
}

if (-not $esBinary) {
    Write-Error "es.exe not found! Please ensure Everything is installed and es.exe is in PATH or ~/.local/bin/."
    exit 1
}

# 2. Check if Everything service/process is running
$evProc = Get-Process -Name Everything -ErrorAction SilentlyContinue
if (-not $evProc) {
    Write-Warning "Everything.exe process is not currently running. Attempting to start it..."
    $evExePaths = @(
        "C:\Program Files\Everything\Everything.exe",
        "C:\Program Files (x86)\Everything\Everything.exe",
        (Join-Path $env:LOCALAPPDATA "Programs\Everything\Everything.exe")
    )
    foreach ($p in $evExePaths) {
        if (Test-Path $p) {
            Start-Process -FilePath $p -WindowStyle Minimized
            Start-Sleep -Milliseconds 600
            break
        }
    }
}

# 3. Build arguments for es.exe
$argsList = @()

if ($Limit -gt 0) {
    $argsList += "-n"
    $argsList += "$Limit"
}

if ($Path -and (Test-Path $Path)) {
    $resolvedPath = (Resolve-Path $Path).Path
    $argsList += "-path"
    $argsList += "`"$resolvedPath`""
}

if ($Type -eq "dir" -or $Type -eq "folder") {
    $argsList += "/ad"
} elseif ($Type -eq "file") {
    $argsList += "/a-d"
}

switch ($Sort) {
    "dm" {
        $argsList += "-sort-date-modified-descending"
    }
    "size" {
        $argsList += "-sort-size-descending"
    }
    "name" {
        $argsList += "-sort-name-ascending"
    }
}

if ($AsJson) {
    $argsList += "-csv"
    $argsList += "-size"
    $argsList += "-date-modified"
}

$argsList += $Query

# 4. Execute search
$argString = $argsList -join " "
$pinfo = New-Object System.Diagnostics.ProcessStartInfo
$pinfo.FileName = $esBinary
$pinfo.Arguments = $argString
$pinfo.RedirectStandardOutput = $true
$pinfo.RedirectStandardError = $true
$pinfo.UseShellExecute = $false
$pinfo.StandardOutputEncoding = [System.Text.Encoding]::UTF8

$process = New-Object System.Diagnostics.Process
$process.StartInfo = $pinfo
$process.Start() | Out-Null
$stdout = $process.StandardOutput.ReadToEnd()
$stderr = $process.StandardError.ReadToEnd()
$process.WaitForExit()

if ($process.ExitCode -ne 0 -and $stderr) {
    Write-Error "es.exe error: $stderr"
    exit $process.ExitCode
}

# 5. Output
if ($AsJson) {
    if (-not $stdout.Trim()) {
        Write-Output "[]"
        return
    }
    $csvData = $stdout | ConvertFrom-Csv
    $results = @()
    foreach ($row in $csvData) {
        $results += [PSCustomObject]@{
            Filename = $row.Filename
            Size = $row.Size
            DateModified = $row."Date Modified"
        }
    }
    $results | ConvertTo-Json -Depth 3
} else {
    $stdout.Trim()
}
