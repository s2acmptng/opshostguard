# StopHosts.psm1 [OpsHostGuard Module]

<#
    .SYNOPSIS
    Module for shutting down hosts in a specified group if no active sessions are detected.

    .DESCRIPTION
    This module automates the shutdown process for one or more hosts within the `OpsHostGuard` 
    environment (or in standalone mode). It performs a check for active sessions and other shutdown 
    dependencies, proceeding with the shutdown only if no active users are detected on each specified host. 
    After issuing the shutdown command, the module verifies the host’s status by checking for both a ping 
    response and RPC (Remote Procedure Call) connectivity on port 135 to confirm that Windows has fully 
    powered off.

    Configuration data and host groups are loaded from an external JSON file. Active sessions are 
    identified using the `quser` command or specific query methods, while the RPC verification (port 135) 
    provides an additional confirmation layer.

    .PARAMETER -GroupName
    Specifies the name of a host group to analyze and potentially shut down.

    .PARAMETER -HostName
    Specifies the name of an individual host to analyze and shut down if no active sessions are found.

    .PARAMETER -Verbose
    Enables Debug mode, providing detailed log output for troubleshooting each process step.

    .EXAMPLE
    Invoke-STHHostShutdown -GroupName "lab"
    Checks all hosts in the "lab" group for active sessions, shuts down those without active sessions, 
    and verifies the shutdown status via ping and RPC port 135.

    .EXAMPLE
    Invoke-STHHostShutdown -HostName "i1-js-01"
    Checks the host "i1-js-01" for active sessions, shuts it down if no sessions are found, and verifies 
    the shutdown status via ping and RPC port 135.

    .NOTES
    This module requires administrative privileges and access to the external JSON file `host_groups.json`.
    It is optimized for environments where detailed verification of host shutdown is critical, as it 
    includes both ping and RPC checks to ensure Windows is not actively responding.

    .ORGANIZATION
    Developed for: Faculty of Documentation and Communication Sciences at the University of Extremadura.

    .AUTHOR [© 2024 Alberto Ledo]
    Alberto Ledo, Faculty of Documentation and Communication Sciences
    IT Department: University of Extremadura - IT Services for Facilities
    Contact: albertoledo@unex.es

    .Copyright
    © 2024 Alberto Ledo

    .VERSION
    1.3.0

    .HISTORY
       
    1.3.0 - Incorporated functions as replacements for others and loaded necessary modules to ensure standalone execution.
    1.0.0 - Initial script created by Alberto Ledo.
    1.1.0 - Added Debug parameter and improved Error handling.
    1.2.0 - Added RPC port 135 verification for more reliable shutdown confirmation.

    .USAGE
    This module is strictly for internal use within the University of Extremadura.
    It is designed to operate within the University’s IT infrastructure and may not function 
    as expected in other environments.

    .DATE
    November 11, 2024

    .DISCLAIMER
    This module is provided "as-is" and is intended for internal use at the University of Extremadura.
    No warranties, express or implied, are provided. Any modifications or adaptations are not covered
    under this disclaimer.

    .LINK
    https://github.com/n7rc/OpsHostGuard
#>

<#
#Requires -Module OpsInit
#Requires -Module LogManager
#Requires -Module OpsUtils
#Requires -Module ActiveSessions
#Requires -Module StartHosts
#>

if (-not $Global:ProjectRoot) {
    $scriptDirectory = (Get-Item -Path $MyInvocation.MyCommand.Definition).DirectoryName
    $Global:ProjectRoot = (Resolve-Path -Path (Join-Path -Path $scriptDirectory -ChildPath "../../../../")).Path
}

# Script variable to track the current mode
$Global:StandaloneMode = $false

# Module name setup
$Script:ModuleName = if ($null -ne $MyInvocation.MyCommand.Module) { $MyInvocation.MyCommand.Module.Name } else { "StopHosts" }

$timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")

# Load OpsBase module
$opsBasePath = Join-Path -Path $Global:ProjectRoot -ChildPath "modules/core/system/OpsBase.psd1"


# Import the OpsBase module globally with Error handling
if (-not (Get-Module -Name OpsBase)) {
    Import-Module -Name $opsBasePath -Scope Global -Force -ErrorAction Stop
}

if (Test-ExecutionContext -RootCheck) {
    # Validate core modules
    if (-not (Get-Module -Name OpsVar)) {
        Add-OpsBaseLogMessage -message "OpsVar module is missing. Please ensure it is loaded." -logLevel "Error"
    }

    if (-not (Get-Module -Name OpsInit)) {
        Add-OpsBaseLogMessage -message "OpsInit module is missing. Please ensure it is loaded." -logLevel "Error"
    }

    if (-not (Get-Module -Name LogManager)) {
        Add-OpsBaseLogMessage -message "LogManager module is missing. Please ensure it is loaded." -logLevel "Error"
    }

    if (-not (Get-Module -Name OpsBase)) {
        Add-OpsBaseLogMessage -message "OpsBase module is missing. Please ensure it is loaded." -logLevel "Error"
    }

    if (-not $Global:Config) {
        Add-OpsBaseLogMessage -message "Configuration variable is required." -logLevel "Error"
    }
    if (-not $Global:Config.Paths) {
        Add-OpsBaseLogMessage -message "OpsVar did not initialize Paths."  -logLevel "Error"
    }
    # Validate essential keys in Config.Paths
    if (-not $Global:Config.Paths.Log -or -not $Global:Config.Paths.Log.Root) {
        Add-OpsBaseLogMessage -message "Missing required log paths in OpsVar."  -logLevel "Error"
    }
}
else {

    # Global variable to track the current mode
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

    # Core dependencies

    $Script:StandaloneDependencies = @("OpsUtils", "ActiveSessions", "StartHosts")

    # Ensure CoreDependencies is not empty before calling New-CoreStandalone
    if (-not $Script:StandaloneDependencies -or $Script:StandaloneDependencies.Count -eq 0) {
        Add-LogMessage -message "No valid standalone dependencies to process. Aborting standalone initialization." -logLevel "Error"
        throw "No valid core dependencies to process."
    }

    # Call standalone initialization
    try {
        Import-StandaloneDependencies -standaloneDependencies $Script:StandaloneDependencies
        New-ModuleStandalone -moduleName $Script:ModuleName
        Add-LogMessage -message "Standalone mode activated for $Script:ModuleName." -logLevel "Info"
    }
    catch {
        Add-LogMessage -message "Failed to initialize standalone mode for $Script:ModuleName. Error: $_" -logLevel "Error"
        throw
    }
}

# Function to display help message for the StopHosts module
function Show-Help {
    param (
        [string]$functionName = "Stop-Hosts"
    )

    # Display usage instructions for Stop-Hosts function
    Write-Host "`nUSAGE:`n" -ForegroundColor Yellow
    Write-Host "    $functionName [[-GroupName <String>] | [-HostName <String>] | [-HostsList <array>]] [-Silent:[1|0]] [-Verbose:[1|0]] [-PsRemotingCredential <PSCredential>]`n" -ForegroundColor White

    Write-Host "`nDESCRIPTION:`n" -ForegroundColor Yellow
    Write-Host "    The $functionName function facilitates the remote shutdown of hosts within a specified group or individually. It checks for active user sessions and other shutdown dependencies before attempting to power off each host. This function can operate as a standalone module or as part of the OpsHostGuard System." -ForegroundColor White

    # Describe each parameter for the function in detail
    Write-Host "`nPARAMETERS:`n" -ForegroundColor Yellow
    Write-Host "
    -GroupName [Optional]
        Name of the host group to shutdown. Default: 'all'." -ForegroundColor White
    Write-Host "
    -HostName [Optional]
        Name of a specific host within the group to shutdown." -ForegroundColor White
    Write-Host "
    -HostsList [Optional]
        Arbitrary host list to shutdown. Format: host1, host2, host3, ..." -ForegroundColor White
    Write-Host "`nPARAMETERS:`n" -ForegroundColor Yellow
    Write-Host "
    -Silent [Optional]
        Boolean to suppress output messages except critical logs. Default: false." -ForegroundColor White
    Write-Host "
    -Verbose [Optional]
        Boolean to enable detailed Debug output for troubleshooting. Default: false." -ForegroundColor White
    Write-Host "
    -PsRemotingCredential [Optional]
        Administrator credentials for remote connection. If not provided, the user will be prompted." -ForegroundColor White

    # Provide example usage for different scenarios
    Write-Host "`nEXAMPLES:`n" -ForegroundColor Yellow
    Write-Host "    Stop-Hosts -GroupName 'lab_machines' -Silent:1" -ForegroundColor White
    Write-Host "        Initiates shutdown of all hosts in the 'lab_machines' group in silent mode." -ForegroundColor White
    Write-Host "    
    Stop-Hosts -HostName 'server01' -Verbose:1" -ForegroundColor White
    Write-Host "        Attempts to shut down a specific host named 'server01' with Debug mode enabled for troubleshooting." -ForegroundColor White
    Write-Host "    
    Stop-Hosts -GroupName 'all' -PsRemotingCredential \$adminCreds" -ForegroundColor White
    Write-Host "        Shuts down all hosts in the configuration, using provided credentials for remote connections.`n" -ForegroundColor White
}

# Function to check if a host is alive
function Get-HostsStatus {
    param ([string]$HostName)
    $logMessage = "Checking status of host: $HostName"
        if (Test-ExecutionContext -ConsoleCheck) {
            Add-LogMessage -message $logMessage -logLevel "Info" -logCorePath $logCorePath
        }
        else {
            Add-LogMessage -message $logMessage -logLevel "Info"
        }
    try {
        return (Test-Connection -ComputerName $HostName -Count 1 -Quiet)
    }
    catch {
        $logMessage = "Error checking host status: $HostName. Error: $_"
        if (Test-ExecutionContext -ConsoleCheck) {
            Add-LogMessage -message $logMessage -logLevel "Info" -logCorePath $logCorePath
        }
        else {
            Add-LogMessage -message $logMessage -logLevel "Info"
        }
        return $false
    }
}

# Function to check RPC status on port 135
function Get-RpcStatus {
    param ([string]$HostName)
    $logMessage = "Checking RPC status on port 135 for host: $HostName"
        if (Test-ExecutionContext -ConsoleCheck) {
            Add-LogMessage -message $logMessage -logLevel "Info" -logCorePath $logCorePath
        }
        else {
            Add-LogMessage -message $logMessage -logLevel "Info"
        }
    try {
        # Test the TCP connection on port 135 (RPC)
        $ipv4Address = [System.Net.Dns]::GetHostAddresses($HostName) | Where-Object { $_.AddressFamily -eq 'InterNetwork' }
        if ($ipv4Address) {
            $rpcTest = Test-NetConnection -ComputerName $ipv4Address.IPAddressToString -Port 135 -ErrorAction Stop
            return $rpcTest.TcpTestSucceeded
        }
        else {
            Write-Host "No IPv4 address found for $HostName in RPC port"
            return $false
        }
    }
    catch {
        $logMessage = "RPC check failed for host ${HostName}: Host might be offline. Error: $_"
        if (Test-ExecutionContext -ConsoleCheck) {
            Add-LogMessage -message $logMessage -logLevel "Info" -logCorePath $logCorePath
        }
        else {
            Add-LogMessage -message $logMessage -logLevel "Info"
        }
        return $false
    }
}

function Stop-STHHost {
   
    param ([string]$HostName,
        [bool]$Silent
    )
   
    try {
        $logMessage = "Attempting to shut down host: $HostName"
        if (Test-ExecutionContext -ConsoleCheck) {
            Add-LogMessage -message $logMessage -logLevel "Info" -logCorePath $logCorePath
        }
        else {
            Add-LogMessage -message $logMessage -logLevel "Info"
        }
        invoke-command -ComputerName $HostName -Credential $PsRemotingCredential -ScriptBlock {
            Stop-Computer -Force
        }
        if (-not $Silent) {
            $logMessage = "Shutdown signal sent to host $HostName."
            if (Test-ExecutionContext -ConsoleCheck) {
                Add-LogMessage -message $logMessage -logLevel "Info" -logCorePath $logCorePath
            }
            else {
                Add-LogMessage -message $logMessage -logLevel "Info"
            }
        }
    }
    catch {
        if (-not $Silent) {
            $logMessage = "Error shutting down ${hostName}: $_"
            if (Test-ExecutionContext -ConsoleCheck) {
                Add-LogMessage -message $logMessage -logLevel "Error" -logCorePath $logCorePath
            }
            else {
                Add-LogMessage -message $logMessage -logLevel "Error"
            }
        }
        $logMessage = "Failed to shut down $HostName. Error: $_"
        if (Test-ExecutionContext -ConsoleCheck) {
            Add-LogMessage -message $logMessage -logLevel "Error" -logCorePath $logCorePath
        }
        else {
            Add-LogMessage -message $logMessage -logLevel "Error"
        }
    }
}

function Get-STHShutdownState {
    param ([string]$HostName,
        [bool]$Verbose,
        [bool]$Silent
    )

    $pingStatus = Get-HostsStatus -HostName $HostName
    $rpcStatus = Get-RpcStatus -HostName $HostName

    if (-not $pingStatus -and -not $rpcStatus) {
        if (-not $Silent) {
            $logMessage = "Host $HostName is Successfully shut down."
            if (Test-ExecutionContext -ConsoleCheck) {
                Add-LogMessage -message $logMessage -logLevel "Success" -logCorePath $logCorePath
            }
            else {
                Add-LogMessage -message $logMessage -logLevel "Success"
            }
        } 
        return "Success"
    }
    elseif ($pingStatus -and -not $rpcStatus) {
        if (-not $Silent) {
            $logMessage = "Warning: Host $HostName responds to ping but not to RPC."
            if (Test-ExecutionContext -ConsoleCheck) {
                Add-LogMessage -message $logMessage -logLevel "Warning" -logCorePath $logCorePath
            }
            else {
                Add-LogMessage -message $logMessage -logLevel "Warning"
            }
        } 
        return "false"
    }
    elseif ($pingStatus -and $rpcStatus) {
        if (-not $Silent) {
            $logMessage = "Error: Host $HostName did not shut down, Windows is still operational."
            if (Test-ExecutionContext -ConsoleCheck) {
                Add-LogMessage -message $logMessage -logLevel "Error" -logCorePath $logCorePath
            }
            else {
                Add-LogMessage -message $logMessage -logLevel "Error"
            } 
        }
        return "false"
    }
    else {
        if (-not $Silent) {
            $logMessage = "Unknown state for host $HostName."
            if (Test-ExecutionContext -ConsoleCheck) {
                Add-LogMessage -message $logMessage -logLevel "Warning" -logCorePath $logCorePath
            }
            else {
                Add-LogMessage -message $logMessage -logLevel "Warning"
            } 
        }
        return "false"
    }
}

function Invoke-STHHostShutdown {
    param (
        [string]$GroupName = $null, # Group of hosts to shut down
        [string]$HostName = $null, # Specific host to shut down
        [bool]$Verbose = $false,
        [bool]$Silent = $false
    )

    # Log function start
    Add-LogMessage -functionName $MyInvocation.InvocationName -logLevel "Info" `
        -message "Starting Invoke-STHHostShutdown with parameters: groupName='$GroupName', hostName='$HostName'."

    # Ensure host groups are loaded
    #if (-not $Script:hostsGroupsHash) {
        $Script:hostsGroupsHash = Get-HostsGroups -GroupName $GroupName
        if (-not $Script:hostsGroupsHash) {
            Add-LogMessage -functionName $MyInvocation.InvocationName -logLevel "Error" `
                -message "Failed to load host groups. Ensure JSON data is correctly configured."
            return
        }
    #}

    # Debug log for loaded groups
    Add-LogMessage -functionName $MyInvocation.InvocationName -logLevel "Debug" `
        -message "Loaded host groups: $($Script:hostsGroupsHash.Keys -join ', ')."

    # Validate input parameters: Ensure at least one of groupName or hostName is provided
    if (-not $GroupName -and -not $HostName) {
        Add-LogMessage -functionName $MyInvocation.InvocationName -logLevel "Error" `
            -message "Invalid parameters: Specify at least groupName or hostName."
        return
    }

    # Determine the list of hosts to shut down
    $hostsToCheck = if ($GroupName) {
        if ($Script:hostsGroupsHash.ContainsKey($GroupName)) {
            $Script:hostsGroupsHash[$GroupName]
        }
        else {
            Add-LogMessage -functionName $MyInvocation.InvocationName -logLevel "Error" `
                -message "Group '$GroupName' does not exist in the host groups."
            return
        }
    }
    
    # Log if no hosts are found
    if (-not $hostsToCheck -or $hostsToCheck.Count -eq 0) {
        Add-LogMessage -functionName $MyInvocation.InvocationName -logLevel "Info" `
            -message "Group '$GroupName' is empty or no hosts specified. No hosts to shut down."
        return
    }

    # Debug log for hosts to check
    Add-LogMessage -functionName $MyInvocation.InvocationName -logLevel "Debug" `
        -message "Hosts to check for shutdown: $($hostsToCheck -join ', ')."

    # Prepare the list of hosts to shut down
    $hostsToShutdown = @()
    foreach ($currentHost in $hostsToCheck) {
        if (-not (Get-ASSessions -remoteHost $currentHost -SimpleCheck) -and (Test-STHostUp -HostName $currentHost)) {
            Add-LogMessage -message "Adding $currentHost to shutdown list." -logLevel "Info"
            $hostsToShutdown += $currentHost
        }
        else {
            $reason = if (Get-ASSessions -remoteHost $currentHost -SimpleCheck) {
                "Active sessions detected."
            }
            elseif (-not (Test-STHostUp -HostName $currentHost)) {
                "Host unreachable."
            }
            else {
                "Unknown reason."
            }
            Add-LogMessage -message "Skipping ${currentHost}: $reason" -logLevel "Info"
        }
    }

    # Log if no hosts are available for shutdown
    if ($hostsToShutdown.Count -eq 0) {
        Add-LogMessage -message "No hosts available for shutdown." -logLevel "Info"
        return
    }

    # Initialize shutdown process
    $hostsShutdownStatus = @()
    $checkIntervalStop = if ($null -ne $Global:Config.UserConfigData.HostSettings.checkIntervalStop) {
        $Global:Config.UserConfigData.HostSettings.checkIntervalStop
    } else {
        15
    }

    foreach ($currentHost in $hostsToShutdown) {
        # Attempt to shut down the host
        Stop-STHHost -HostName $currentHost -Silent:$Silent

        # Wait before rechecking the status
        Add-LogMessage -message "Waiting $checkIntervalStop seconds before rechecking host status." -logLevel "Info"
        Start-Sleep -Seconds $checkIntervalStop

        # Get and log the shutdown state
        $shutdownState = Get-STHShutdownState -HostName $currentHost -Verbose:$Verbose -Silent:$Silent
        $hostsShutdownStatus += [pscustomobject]@{
            Name   = $currentHost
            Status = "Power off $shutdownState"
        }
    }

    # Return the shutdown status of all hosts
    return $hostsShutdownStatus
}

# Public "wrapper" function that invokes `Invoke-ASCheck` to hide it in standalone mode.
# Avoids the use of aliases and allows the function to remain hidden when calling get-command.

function Stop-Hosts {
    param (
        [string]$GroupName,
        [string]$HostName,
        [array]$HostsList = @(),
        [bool]$Verbose,
        [bool]$Silent
    )

    # Abstraction for a single host or a list of hosts
    if ($HostName) {
        $GroupName = "temporaryGroup"
        New-TemporaryGroup -GroupName $GroupName -HostsList @($HostName)
    }

    if ($HostsList) {
        $GroupName = "temporaryGroup"
        New-TemporaryGroup -GroupName $GroupName -HostsList $HostsList
    }

    # Unified validation: Ensure at least one of groupName, hostName, or successfulHosts is provided
    if (-not $GroupName -and -not $HostName -and (-not $HostsList -or $HostsList.Count -eq 0)) {
        Write-Host "Error: You must specify either a group name (-GroupName), a host name (-HostName), or a list of hosts (-HostsList)."
        Show-Help -CommandName "Stop-Hosts"
        return
    }

    Invoke-STHHostShutdown -GroupName $GroupName -Verbose:$Verbose -Silent:$Silent
}

<#
function Stop-Hosts {
    param (
        [string]$GroupName,
        [string]$HostName,
        [bool]$Verbose,
        [bool]$Silent
    )

    Invoke-STHHostShutdown -GroupName $GroupName -HostName $HostName -Verbose:$Verbose -Silent:$Silent
}
#>

# Clean up old logs in standalone mode
if (Test-ExecutionContext -ConsoleCheck) {
    Remove-OldLogFiles -logDirectory $Global:Config.Paths.Log.Stop -retainCount 10
}

# Conditional export based on execution mode
if (Test-ExecutionContext -ConsoleCheck) {
    # In standalone mode, export only the alias and Show-Help
    Export-ModuleMember -Function Stop-Hosts, Show-Help
}
else {
    # In integrated mode, export Invoke-ASCheck and Get-ASSessions directly
    Export-ModuleMember -Function Invoke-STHHostShutdown, Stop-STHHost, Get-STHShutdownState
}

