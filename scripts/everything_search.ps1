<#
.SYNOPSIS
    Dual-mode Everything Search (HTTP REST API + CLI IPC Fallback).
.DESCRIPTION
    Works inside restricted sandboxes, containers, WSL, or native desktop.
    Automatically detects HTTP server on localhost:8080 (or $env:EVERYTHING_HTTP_URL).
    Falls back to es.exe Win32 IPC if HTTP is unreachable.
.PARAMETER Query
    The search query.
.PARAMETER Path
    Limit search to subfolders and files in this path.
.PARAMETER Limit
    Max results to return (default: 25).
.PARAMETER Type
    'all', 'file', 'dir' / 'folder'.
.PARAMETER Sort
    'default', 'dm' (date modified desc), 'size' (size desc), 'name'.
.PARAMETER Mode
    'auto', 'http', or 'cli'.
.PARAMETER AsJson
    Output results as JSON string.
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

    [ValidateSet("auto", "http", "cli")]
    [string]$Mode = "auto",

    [string]$Url = $env:EVERYTHING_HTTP_URL,

    [switch]$AsJson
)

if (-not $Url) {
    $Url = "http://127.0.0.1:8080"
}

function Convert-FileTimeToDate([long]$ft) {
    try {
        $origin = [DateTime]::new(1601, 1, 1, 0, 0, 0, [DateTimeKind]::Utc)
        return $origin.AddTicks($ft).ToLocalTime().ToString("yyyy-MM-dd HH:mm:ss")
    } catch {
        return "$ft"
    }
}

function Invoke-EverythingHttp {
    param($BaseUrl, $Q, $MaxCount, $ScopePath, $ItemType, $SortOrder)

    $parts = @()
    if (-not [string]::IsNullOrWhiteSpace($ScopePath)) {
        $parts += "path:`"$ScopePath`""
    }
    if ($ItemType -eq "dir" -or $ItemType -eq "folder") {
        $parts += "/ad"
    } elseif ($ItemType -eq "file") {
        $parts += "/a-d"
    }
    $parts += $Q
    $fullSearch = $parts -join " "

    $queryMap = @{
        search = $fullSearch
        json = "1"
        count = "$MaxCount"
        path_column = "1"
        size_column = "1"
        date_modified_column = "1"
    }

    switch ($SortOrder) {
        "dm"   { $queryMap["sort"] = "date_modified"; $queryMap["ascending"] = "0" }
        "size" { $queryMap["sort"] = "size";          $queryMap["ascending"] = "0" }
        "name" { $queryMap["sort"] = "name";          $queryMap["ascending"] = "1" }
    }

    $queryString = ($queryMap.GetEnumerator() | ForEach-Object { "$($_.Key)=$([Uri]::EscapeDataString($_.Value))" }) -join "&"
    $requestUri = "$($BaseUrl.TrimEnd('/'))/?$queryString"

    $resp = Invoke-RestMethod -Uri $requestUri -TimeoutSec 3 -UseBasicParsing -ErrorAction Stop
    $items = @()
    foreach ($item in $resp.results) {
        $folder = $item.path
        $name = $item.name
        $sep = if ($folder.EndsWith("\") -or $folder.EndsWith("/")) { "" } else { "\" }
        $fullPath = "$folder$sep$name"
        
        $items += [PSCustomObject]@{
            Filename = $fullPath
            Type = $item.type
            Size = $item.size
            DateModified = (Convert-FileTimeToDate $item.date_modified)
        }
    }
    return $items
}
function Invoke-EverythingCli {
    param(
        [string]$Q,
        [int]$MaxCount = 25,
        [string]$ScopePath = "",
        [string]$ItemType = "all",
        [string]$SortOrder = "default"
    )

    $scriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $PSCommandPath }
    $candidates = @(
        "es.exe",
        (Join-Path $scriptDir "..\bin\es.exe"),
        (Join-Path $env:USERPROFILE ".local\bin\es.exe"),
        "C:\Program Files\Everything\es.exe"
    )
    $esBinary = $null
    foreach ($c in $candidates) {
        if (Get-Command $c -ErrorAction SilentlyContinue) {
            $esBinary = (Get-Command $c).Source; break
        } elseif (Test-Path $c) {
            $esBinary = (Resolve-Path $c).Path; break
        }
    }
    if (-not $esBinary) { throw "es.exe not found" }

    $argsList = @("-csv", "-size", "-date-modified")
    if ($MaxCount -gt 0) { $argsList += @("-n", "$MaxCount") }
    if ($ScopePath -and "$ScopePath".Trim().Length -gt 0) {
        if (Test-Path -LiteralPath "$ScopePath") {
            $resolved = (Resolve-Path -LiteralPath "$ScopePath").Path
            $argsList += @("-path", "`"$resolved`"")
        }
    }
    if ($ItemType -eq "dir" -or $ItemType -eq "folder") { $argsList += "/ad" }
    elseif ($ItemType -eq "file") { $argsList += "/a-d" }
    switch ($SortOrder) {
        "dm"   { $argsList += "-sort-date-modified-descending" }
        "size" { $argsList += "-sort-size-descending" }
        "name" { $argsList += "-sort-name-ascending" }
    }
    $argsList += $Q

    $pinfo = New-Object System.Diagnostics.ProcessStartInfo
    $pinfo.FileName = $esBinary
    $pinfo.Arguments = $argsList -join " "
    $pinfo.RedirectStandardOutput = $true
    $pinfo.RedirectStandardError = $true
    $pinfo.UseShellExecute = $false
    $pinfo.StandardOutputEncoding = [System.Text.Encoding]::UTF8

    $proc = [System.Diagnostics.Process]::Start($pinfo)
    $stdout = $proc.StandardOutput.ReadToEnd()
    $stderr = $proc.StandardError.ReadToEnd()
    $proc.WaitForExit()

    if ($proc.ExitCode -ne 0 -and $stderr) {
        throw "es.exe error: $stderr"
    }

    if (-not $stdout.Trim()) { return @() }
    $rows = $stdout | ConvertFrom-Csv
    $items = @()
    foreach ($r in $rows) {
        $items += [PSCustomObject]@{
            Filename = $r.Filename
            Type = "file"
            Size = $r.Size
            DateModified = $r."Date Modified"
        }
    }
    return $items
}

# Execution logic
$results = $null
$httpErr = $null

if ($Mode -in "auto", "http") {
    try {
        $results = Invoke-EverythingHttp -BaseUrl $Url -Q $Query -MaxCount $Limit -ScopePath $Path -ItemType $Type -SortOrder $Sort
    } catch {
        $httpErr = $_.Exception.Message
        if ($Mode -eq "http") {
            Write-Error "HTTP Search Error ($Url): $httpErr"
            exit 1
        }
    }
}

if ($null -eq $results -and $Mode -in "auto", "cli") {
    try {
        $results = Invoke-EverythingCli -Q $Query -MaxCount $Limit -ScopePath $Path -ItemType $Type -SortOrder $Sort
    } catch {
        $cliErr = $_.Exception.Message
        Write-Error "CLI Search Error: $cliErr"
        if ($httpErr) {
            Write-Warning "Previous HTTP attempt also failed: $httpErr"
            Write-Host "Sandboxed Agent Tip: Ensure Everything HTTP Server is enabled on the host (port 8080)." -ForegroundColor Yellow
        }
        exit 1
    }
}

if ($AsJson) {
    if ($results) {
        $results | ConvertTo-Json -Depth 3
    } else {
        "[]"
    }
} else {
    if ($results) {
        foreach ($r in $results) {
            Write-Output $r.Filename
        }
    }
}
