# Test-HostStatus.ps1 [OpsHostGuard]

<#
    .SYNOPSIS
    Verifies the status of one or more Windows hosts (alive or down) by checking their connectivity.

    .DESCRIPTION
    This script checks the connectivity of a group of hosts or an individual host specified by the user. The hosts are defined
    in a JSON file, and the script uses the Test-Connection command and the RPC port scan to verify if the hosts are reachable
    (alive) or not. The script provides feedback on whether the hosts are alive or down and supports checking multiple hosts
    from predefined groups or a single host. It also validates the parameters to ensure the proper execution.

    .PARAMETER -GroupName
    Specifies the name of the group of hosts to be analyzed. The group should exist in the external JSON file.

    .PARAMETER -h
    Specifies the name of the individual host to analyze.

    .PARAMETER -Verbose
    Enables Debug mode, providing detailed output for each step of the script, including the RPC status check.

    .EXAMPLE
    .\Test-HostStatus.ps1 -GroupName lab
    This will check all hosts in the "lab" group, verify their connectivity, and display which hosts are alive or down.

    .EXAMPLE
    .\Test-HostStatus.ps1 -h i1-js-01
    This will check the status of the host "i1-js-01" and show whether it is alive or down.

    .EXAMPLE
    .\Test-HostStatus.ps1 -GroupName "all" -Verbose
    This will check all hosts in the "lab" group, verify their connectivity, and display which hosts are alive or down with
    detailed Debug output, including RPC checks.


    .NOTES
    The script requires the external JSON file `host_groups.json` to contain the predefined host groups.

    .ORGANIZATION
    Developed for: Faculty of Documentation and Communication Sciences at the University of Extremadura.

    .AUTHOR [© 2024 Alberto Ledo]
    Alberto Ledo [Faculty of Documentation and Communication Sciences] - with assistance from OpenAI
    IT Department: University of Extremadura - IT Services for Facilities
    Contact: albertoledo@unex.es

    .@Copyright
    © 2024 Alberto Ledo

    .VERSION
    1.1 

    .HISTORY
    1.0 - Original script created by Alberto Ledo.
    1.1 - Refactored for improved readability, added parameter validation, and enhanced output messaging.
   
    .USAGE
    This script is strictly for internal use within University of Extremadura.
    The script is designed to operate within the IT infrastructure and environment of University of Extremadura
    and may not function as expected in other environments.

    .DATE
    October 28, 2024 12:24

    .DISCLAIMER
    This script is provided "as-is" and is intended for internal use at University of Extremadura.
    No warranties, express or implied, are provided. Any modifications or adaptations are not covered
    under this disclaimer.

    .LINK
    https://github.com/n7rc/OpsHostGuard
#>

param (
    [string]$GroupName, # Group of hosts to analyze (optional)
    [string]$HostName,  # Individual host to analyze (optional)
    [switch]$Verbose    # Enable Debug mode (optional)
)

# Function to print Debug messages when Debug mode is active
function Add-LogMessage {
    param (
        [string]$message
    )
    if ($Verbose) {
        if (-not $global:silentMode) {
    Add-LogMessage " $message" -ForegroundColor Yellow }
    }
}

# Load host groups from a JSON file
$currentHostGroupsFile = "../config/host_groups.json"

# Check if the file exists
if (-not (Test-Path $currentHostGroupsFile)) {
    if (-not $global:silentMode) {
    Add-LogMessage "Error: The host groups file was not found at $currentHostGroupsFile." -ForegroundColor Red }
    exit 1
}

# Try to load the data from the JSON file
try {
    $currentHostsGroups = Get-Content $currentHostGroupsFile | ConvertFrom-Json
}
catch {
    if (-not $global:silentMode) {
    Add-LogMessage "Error: Unable to load the host groups from the JSON file." -ForegroundColor Red }
    exit 1
}

# Convert the JSON object to a hashtable to use ContainsKey
$currentHostsGroupsHash = [PSCustomObject]@{}
$currentHostsGroups.psobject.Properties | ForEach-Object {
    $currentHostsGroupsHash[$_.Name] = $_.Value
}

# Display usage Information if no parameters are provided
if (-not $GroupName -and -not $h) {
    if (-not $global:silentMode) {
    Add-LogMessage "Usage: .\Test-HostStatus.ps1 [-g <GroupName> | -h <HostName>]" -ForegroundColor Yellow }
    if (-not $global:silentMode) {
    Add-LogMessage "   -GroupName: Specifies the group of hosts to check."
}
    if (-not $global:silentMode) {
    Add-LogMessage "   -h: Specifies an individual host to check."
}
    if (-not $global:silentMode) {
    Add-LogMessage "`nExamples:"
}
    if (-not $global:silentMode) {
    Add-LogMessage "   .\Test-HostStatus.ps1 -GroupName i1"
}
    if (-not $global:silentMode) {
    Add-LogMessage "   .\Test-HostStatus.ps1 -h i1-js-01"
}
    if (-not $global:silentMode) {
    Add-LogMessage "`nThis script verifies the status of one or more Windows hosts (alive or down) by checking their connectivity."
}
    exit 1
}

# Validate if the group exists
if ($GroupName -and -not $currentHostsGroupsHash.ContainsKey($GroupName)) {
    if (-not $global:silentMode) {
    Add-LogMessage "Error: The group '$g' does not exist in the JSON file." -ForegroundColor Red }
    exit 1
}

# Get the list of hosts to check
$hostToCheck = if ($GroupName) {
    $currentHostsGroupsHash[$GroupName]
}
else {
    @($h)
}

# Function to check if a host is alive
function Test-STHostUp {
    param (
        [string]$currentHostName
    )
    Add-LogMessage "Checking if host $currentHostName is up via ping and RPC port."

    # Initial ping check
    if (Test-Connection -ComputerName $currentHostName -Count 1 -Quiet) {
        Add-LogMessage "Ping Successful for $currentHostName. Now checking RPC port 135."
        
        # Attempt to connect to TCP port 135
        try {
            $tcpClient = New-Object System.Net.Sockets.TcpClient
            $tcpClient.Connect($currentHostName, 135)
            $tcpClient.Close()

            Add-LogMessage "RPC port 135 on $currentHostName is open. Host is confirmed to be up."
            return $true
        }
        catch {
            Add-LogMessage "Failed to connect to RPC port 135 on $currentHostName. Host may still be booting."
            return $false
        }
    }
    else {
        Add-LogMessage "Ping failed for $currentHostName. Host is down."
        return $false
    }
}

# Lists to store live and dead hosts
$liveHosts = @()
$downHosts = @()

# Check the status of hosts in a group
foreach ($currentHost in $hostToCheck) {
    if (Test-STHostUp -currentHostName $currentHost) {
        $liveHosts += $currentHost
    }
    else {
        $downHosts += $currentHost
    }
}

# Display results
if ($liveHosts.Count -eq 0) {
    if (-not $global:silentMode) {
    Add-LogMessage "`nNo active hosts detected." -ForegroundColor Yellow }
}
elseif ($downHosts.Count -eq 0) {
    if (-not $global:silentMode) {
    Add-LogMessage "`nAll hosts are active." -ForegroundColor Green }
}
else {
    if (-not $global:silentMode) {
    Add-LogMessage "`nThe following hosts are down:" -ForegroundColor Red }
    $downHosts | ForEach-Object { Add-LogMessage $_ }
}
