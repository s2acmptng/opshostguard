# Get-Events.ps1 [OpsHostGuard]

<#
    .SYNOPSIS
    Capture critical and Error events from the "Application", "System", and "Setup" logs of Windows hosts for a
    group of hosts, an individual host, or the localhost.

    This script captures and exports critical (Level 1) and Error (Level 2) events from the "Application", "System", and "Setup"
    event logs for a specific host, group of hosts, or the local machine. It filters logs from the last month and exports the results
    in a specified format (txt, csv, or json).

    .PARAMETER -GroupName
    Specifies the group of hosts to analyze.

    .PARAMETER -h
    Specifies an individual host or 'localhost' to analyze.

    .PARAMETER -exportFormat
    Specifies the export format: "txt", "csv", or "json". Default is "txt".

    .PARAMETER -Verbose
    Enables detailed Error messages if specified.

    .EXAMPLE
    .\Get-Events.ps1 -GroupName lab -exportFormat csv

    .EXAMPLE
    .\Get-Events.ps1 -h localhost -exportFormat json

    .NOTES
    Requires administrative privileges for remote hosts.

    .ORGANIZATION
    Developed for: Faculty of Documentation and Communication Sciences at the University of Extremadura.

    .AUTHOR [© 2024 Alberto Ledo]
    Alberto Ledo [Faculty of Documentation and Communication Sciences] - with assistance from OpenAI
    IT Department: University of Extremadura - IT Services for Facilities
    Contact: albertoledo@unex.es

    .@Copyright
    © 2024 Alberto Ledo

    .VERSION
    1.2

    .HISTORY
    1.0 - Original script created by Alberto Ledo.
    1.1 - Added parameter validation, export formats (CSV, JSON), and reduced credential requests.
    1.2 - Refactored for improved readability and structure.

    .USAGE
    This script is strictly for internal use within University of Extremadura.
    The script is designed to operate within the IT infrastructure and environment of University of Extremadura
    and may not function as expected in other environments.

    .DATE
    October 28, 2024 11:35

    .DISCLAIMER
    This script is provided "as-is" and is intended for internal use at University of Extremadura.
    No warranties, express or implied, are provided. Any modifications or adaptations are not covered
    under this disclaimer.

    .LINK
    https://github.com/n7rc/OpsHostGuard
#>

# Parameter validation and Error handling
param (
    [string]$GroupName,                         # Group name (optional)
    [string]$HostName,                         # Host name (optional)
    [ValidateSet("txt", "csv", "json")] 
    [string]$exportFormat = "txt",      # Export format (optional)
    [switch]$Verbose                      # Enable detailed Error messages (optional)
)

# Set Error handling based on Debug mode
$ErrorActionPreference = if ($Verbose) { "Continue" } else { "SilentlyContinue" }

# Debug mode message
if ($Verbose) {
    if (-not $global:silentMode) {
    Add-LogMessage "Debug mode enabled."
}
}

# Set output directory for logs
$outputDirectory = "../dashboard/data/log"
if (-not (Test-Path $outputDirectory)) {
    New-Item -Path $outputDirectory -ItemType Directory | Out-Null
}

# Load the host groups from an external JSON file
$currentHostGroupsFile = "../config/host_groups.json"
if (-not (Test-Path $currentHostGroupsFile)) {
    if (-not $global:silentMode) {
    Add-LogMessage "Error: Host groups file not found at $currentHostGroupsFile." -ForegroundColor Red }
    exit 1
}

try {
    $currentHostsGroups = Get-Content $currentHostGroupsFile | ConvertFrom-Json
}
catch {
    if (-not $global:silentMode) {
    Add-LogMessage "Error: Unable to load host groups from the JSON file." -ForegroundColor Red }
    exit 1
}

# Show usage Information when no parameters are passed
if (-not $GroupName -and -not $h) {
    if (-not $global:silentMode) {
    Add-LogMessage "Usage: CaptureEvents -GroupName <group> | -h <host> [-Verbose] [-ExportFormat <txt|csv|json>]" -ForegroundColor Yellow }
    if (-not $global:silentMode) {
    Add-LogMessage "`nParameters:"
}
    if (-not $global:silentMode) {
    Add-LogMessage "   -GroupName: Specifies the group of hosts to capture events from."
}
    if (-not $global:silentMode) {
    Add-LogMessage "   -h: Specifies an individual host to capture events from."
}
    if (-not $global:silentMode) {
    Add-LogMessage "   -ExportFormat: Specifies the export format: txt (default), csv, or json."
}
    if (-not $global:silentMode) {
    Add-LogMessage "   -Verbose: Enables detailed Error messages."
}
    if (-not $global:silentMode) {
    Add-LogMessage "`nExamples:"
}
    if (-not $global:silentMode) {
    Add-LogMessage "   .\Get-Events.ps1 -GroupName i1 -ExportFormat csv"
}
    if (-not $global:silentMode) {
    Add-LogMessage "   .\Get-Events.ps1 -h localhost -ExportFormat json"
}
    exit 1
}

# Check if the group exists in the loaded host groups using `PSObject.Properties`
function GroupExists {
    param ([PSCustomObject]$groups, [string]$GroupName)
    return $groups.PSObject.Properties.Name -contains $GroupName
}

# Determine which hosts to analyze
$hostToCheck = if ($GroupName) {
    if (-not (GroupExists -groups $currentHostsGroups -GroupName $g)) {
        if (-not $global:silentMode) {
    Add-LogMessage "Error: The group '$g' does not exist in the JSON file." -ForegroundColor Red }
        exit 1
    }
    $currentHostsGroups.$g
}
else {
    @($h)
}

# Error handler function
function Handle-Exception {
    param ([string]$message)
    if ($Verbose) { if (-not $global:silentMode) {
    Add-LogMessage "Debug: $message" -ForegroundColor Red } }
}

# Check if a host is reachable
function Test-HostReachability {
    param ([string]$remoteHost)
    try {
        return Test-Connection -ComputerName $remoteHost -Count 1 -Quiet -ErrorAction Stop
    }
    catch {
        Handle-Exception "Unable to reach $remoteHost"
        return $false
    }
}

# Capture critical and Error logs
function Get-LogsForHost {
    param ([string]$remoteHostName, [pscredential]$credential = $null)

    $logs = @('Application', 'System', 'Setup')
    $dateLimit = (Get-Date).AddMonths(-1)
    $allEvents = @()

    foreach ($logType in $logs) {
        # Capture Error (Level 2) and Critical (Level 1) events
        foreach ($level in 1, 2) {
            $events = Get-WinEvent -FilterHashtable @{LogName = $logType; Level = $level; StartTime = $dateLimit }
            $events | ForEach-Object {
                $allEvents += [PSCustomObject]@{
                    TimeCreated = $_.TimeCreated
                    Id          = $_.Id
                    Level       = if ($level -eq 1) { "Critical" } else { "Error" }
                    LogType     = $logType
                    Message     = $_.Message
                }
            }
        }
    }

    # Export events based on the format
    $computerName = if ($remoteHostName -eq "localhost") { "localhost" } else { $remoteHostName }
    $filePath = "$outputDirectory\$computerName-Events"

    switch ($ExportFormat) {
        "txt" { $allEvents | Format-List | Out-File "$filePath.log" }
        "csv" { $allEvents | Export-Csv -Path "$filePath.csv" -NoTypeInformation }
        "json" { $allEvents | ConvertTo-Json | Out-File "$filePath.json" }
    }

    if (-not $global:silentMode) {
    Add-LogMessage "Logs exported for $computerName in $ExportFormat format."
}
}

# Check if the hosts are reachable and capture logs
foreach ($remoteHost in $hostToCheck) {
    if (Test-HostReachability -RemoteHost $remoteHost) {
        if (-not $global:silentMode) {
    Add-LogMessage "Capturing logs from $remoteHost..."
}
        Get-LogsForHost -remoteHostName $remoteHost
    }
    else {
        if (-not $global:silentMode) {
    Add-LogMessage "Host '$remoteHost' is unreachable."
}
    }
}