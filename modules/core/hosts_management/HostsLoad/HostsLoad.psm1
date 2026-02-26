<#
    .SYNOPSIS
    Monitors the CPU, memory, and disk usage of one or more Windows hosts, with the option to export the results in CSV format.

    .DESCRIPTION
    This module monitors the CPU, memory, and disk usage of specified Windows hosts by retrieving performance metrics.
    Hosts can be provided individually or grouped from an external JSON file. Results are displayed in a table format and
    optionally exported to a CSV file. 

    It integrates seamlessly within the OpsHostGuard framework or can function in standalone mode. Dependencies and
    configurations are handled dynamically to ensure modularity and consistency with other OpsHostGuard modules.

    .PARAMETER GroupName
    Specifies the group of hosts to monitor, as defined in the external JSON configuration file.

    .PARAMETER HostName
    Specifies a single host to monitor. If specified, the GroupName parameter is ignored.

    .PARAMETER export
    When specified, results are exported to a CSV file in the designated log directory.

    .PARAMETER Verbose
    Enables detailed log output for debugging purposes.

    .PARAMETER Silent
    Suppresses non-critical output messages. Only essential information and errors are displayed.

    .EXAMPLE
    Get-HostLoad -GroupName lab
    Monitors CPU, memory, and disk usage for all hosts in the "lab" group.

    .EXAMPLE
    Get-HostLoad -HostName server01
    Monitors CPU, memory, and disk usage for the "server01" host.

    .EXAMPLE
    Get-HostLoad -GroupName lab -export
    Monitors CPU, memory, and disk usage for the "lab" group and exports the results to a CSV file.

    .NOTES
    This module requires administrative privileges and remote access permissions on the target hosts.

    .VERSION
    1.0.0

    .AUTHOR
    Faculty of Documentation and Communication Sciences - University of Extremadura
    Alberto Ledo, with contributions from OpenAI.

    .LINK
    https://github.com/n7rc/OpsHostGuard
#>

<#
#Requires -Module OpsInit
#Requires -Module LogManager
#Requires -Module OpsUtils
#>

if (-not $Global:ProjectRoot) {
    $scriptDirectory = (Get-Item -Path $MyInvocation.MyCommand.Definition).DirectoryName
    $Global:ProjectRoot = (Resolve-Path -Path (Join-Path -Path $scriptDirectory -ChildPath "../../../../")).Path
}

# Script variable to track the current mode
$Global:StandaloneMode = $false

# Module name setup
$Script:ModuleName = if ($null -ne $MyInvocation.MyCommand.Module) { $MyInvocation.MyCommand.Module.Name } else { "HostsLoad" }

$timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")

# Load OpsBase module
$opsBasePath = Join-Path -Path $Global:ProjectRoot -ChildPath "modules/core/system/OpsBase.psd1"

# Import OpsBase module
if (-not (Get-Module -Name OpsBase)) {
    Import-Module -Name $opsBasePath -Scope Global -Force -ErrorAction Stop
}

if (Test-ExecutionContext -RootCheck) {
    # Validate core modules
    foreach ($moduleName in @("OpsVar", "OpsInit", "LogManager", "OpsUtils")) {
        if (-not (Get-Module -Name $moduleName)) {
            Add-OpsBaseLogMessage -message "$moduleName module is missing. Please ensure it is loaded." -logLevel "Error"
        }
    }

    if (-not $Global:Config) {
        Add-OpsBaseLogMessage -message "Configuration variable is required." -logLevel "Error"
    }

    if (-not $Global:Config.Paths) {
        Add-OpsBaseLogMessage -message "Configuration paths not initialized. Ensure OpsVar is loaded." -logLevel "Error"
    }
}
else {
    # Standalone mode setup
    $Global:StandaloneMode = $true

    # Paths for OpsInit module
    $opsInitPath = Join-Path -Path $Global:ProjectRoot -ChildPath "modules/core/system/OpsInit.psd1"

    if (-not (Get-Module -Name OpsInit)) {
        Import-Module -Name $opsInitPath -Scope Global -Force -ErrorAction Stop
    }

    if (-not $Global:Config) {
        Add-OpsBaseLogMessage -message "Configuration variable is required." -logLevel "Error"
    }

    if (-not $Global:Config.InternalConfig.Modules) {
        Write-Host "[$timestamp] [Error] [$ModuleName] Global configuration paths are not properly initialized." -ForegroundColor Red
        return
    }

    Clear-OpsBaseLogBuffer -logPath $Global:FallbackLogPath

    # Initialize standalone dependencies
    $Script:StandaloneDependencies = @("LogManager", "OpsUtils", "StartHosts")

    try {
        Import-StandaloneDependencies -standaloneDependencies $Script:StandaloneDependencies
        New-ModuleStandalone -moduleName $Script:ModuleName
        Add-OpsBaseLogMessage -message "Standalone mode activated for $Script:ModuleName." -logLevel "Info"
    }
    catch {
        Add-OpsBaseLogMessage -message "Failed to initialize standalone mode. Error: $_" -logLevel "Error"
        throw
    }
}

# Function to display module-specific help
function Show-Help {
    param ([string]$functionName = "Get-Load")
    Write-Host "`nUSAGE:`n" -ForegroundColor Yellow
    Write-Host "    $functionName [[-GroupName <String>] | [-HostName <String>] | [-HostsList <array>]] [-export] [-Verbose:[1|0]] [-Silent:[1|0]]`n" -ForegroundColor White
    Write-Host "`nDESCRIPTION:`n" -ForegroundColor Yellow
    Write-Host "    Retrieves system load metrics (CPU, RAM, Disk, ...) for specified hosts or groups." -ForegroundColor White

    # Describe each parameter for the function in detail
    Write-Host "`nPARAMETERS:`n" -ForegroundColor Yellow
    Write-Host "
    -GroupName [Optional]
        Name of the host group to check. Specifies a group of hosts defined in the configuration." -ForegroundColor White
    Write-Host "
    -HostName [Optional]
        Name of a specific host to check for active sessions." -ForegroundColor White
    Write-Host "
    -HostsList [Optional]
        Arbitrary host list to update. Format: host1, host2, host3, ..." -ForegroundColor White
    Write-Host "`nPARAMETERS:`n" -ForegroundColor Yellow    
    Write-Host "
    -export [Optional]
    If specified, the results are exported to a CSV file in the output directory." -ForegroundColor White
    Write-Host "
    -Verbose [Optional]
    Enables Debug mode, providing detailed log output for troubleshooting." -ForegroundColor White
    Write-Host "
    -Silent [Optional]
    Suppresses non-critical output messages. Only Errors and essential Information will be displayed." -ForegroundColor White
}

# Function to test host reachability
function Test-HostReachability {
    param ([string]$HostName)
    return (Test-Connection -ComputerName $HostName -Count 1 -Quiet)
}

# Function to retrieve host metrics
function Get-Metrics {
    param ([string]$HostName)

    try {
        Invoke-Command -ComputerName $HostName -Credential $Global:PsRemotingCredential -ScriptBlock {
            $cpu = (Get-WmiObject win32_processor).LoadPercentage
            $ram = Get-WmiObject Win32_OperatingSystem | Select-Object @{Name = "RAM"; Expression = { [math]::Round(($_.TotalVisibleMemorySize - $_.FreePhysicalMemory) / 1MB, 2) } }
            $disks = Get-WmiObject Win32_LogicalDisk -Filter "DriveType=3" | ForEach-Object {
                [PSCustomObject]@{
                    Drive = $_.DeviceID
                    Usage = [math]::Round((($_.Size - $_.FreeSpace) / $_.Size) * 100, 2)
                }
            }
            [PSCustomObject]@{
                CPU   = $cpu
                RAM   = $ram.RAM
                Disks = $disks
            }
        } -ErrorAction Stop
    }
    catch {
        Add-OpsBaseLogMessage -message "Failed to retrieve metrics from $HostName. Error: $_" -logLevel "Warning"
        return $null
    }
}

# Function to export results to CSV
function Export-Results {
    param ([array]$Results, [string]$FilePath)
    $Results | Export-Csv -Path $FilePath -NoTypeInformation
}

# Wrapper function for Get-HostLoad
function Get-HostLoad {
    param (
        [string]$GroupName,
        [string]$HostName,
        [switch]$export,
        [switch]$Verbose,
        [switch]$Silent
    )

    # Load host groups
    $hostsToCheck = if ($GroupName) {
        $Global:Config.hostsData.Groups.GroupName[$GroupName]
    }
    elseif ($HostName) {
        @($HostName)
    }
    else {
        Add-OpsBaseLogMessage -message "Invalid parameters. Specify either GroupName or HostName." -logLevel "Error"
        return
    }

    $results = @()
    foreach ($currentHost in $hostsToCheck) {
        if (Test-HostReachability -HostName $currentHost) {
            $metrics = Get-Metrics -HostName $currentHost
            if ($metrics) {
                $results += [PSCustomObject]@{
                    HostName = $currentHost
                    CPU      = $metrics.CPU
                    RAM      = $metrics.RAM
                    Disks    = ($metrics.Disks | ForEach-Object { "$($_.Drive): $($_.Usage)%" }) -join ", "
                }
            }
        }
        else {
            Add-OpsBaseLogMessage -message "Host $currentHost is unreachable." -logLevel "Warning"
        }
    }

    if ($Verbose) {
        $results | Format-Table -AutoSize
    }

    if ($export) {
        $filePath = Join-Path -Path $Global:Config.Paths.Log.Load -ChildPath "LoadResults.csv"
        Export-Results -Results $results -FilePath $filePath
        Add-OpsBaseLogMessage -message "Results exported to $filePath" -logLevel "Info"
    }

    return $results
}

# Export functions
Export-ModuleMember -Function Get-HostLoad, Show-Help