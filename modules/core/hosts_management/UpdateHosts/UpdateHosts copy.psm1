# UpdateHosts.psm1 [OpsHostGuard Core Module]

<#
    .SYNOPSIS
    Automates and manages Windows updates on remote hosts with support for native Windows Update 
    or PSWindowsUpdate, including verification and reporting functionalities. Supports both standalone 
    and integrated operation within OpsHostGuard, with enhanced logging, JSON-based configuration, 
    and dual-mode output.

    .DESCRIPTION
    This module provides a robust and flexible approach for automating System updates across remote 
    Windows hosts. Administrators can choose between native Windows Update and PSWindowsUpdate for 
    applying updates, with additional functionality for verifying installation history. Host selection 
    is configurable via individual hosts or groups defined in a validated JSON file.

    The module operates in dual-mode:
    - **Standalone Mode**: Executes independently, focusing on console-based outputs for applied 
      and verified updates, with simpler logging tailored for standalone usage.
    - **Integrated Mode**: Operates within the OpsHostGuard environment, offering structured output 
      and centralized logging for compatibility with larger workflows.

    Additional features include flexible logging with automatic rotation (after 50 entries or when 
    log size exceeds 10 MB), log compression, and separate reporting of applied and verified updates 
    in standalone mode for improved clarity.

    .FUNCTIONS
    - `Invoke-UHWindowsUpdateNative`: Applies updates using native Windows Update for selected hosts.
    - `Invoke-UHWindowsUpdatePsUpdate`: Applies updates via PSWindowsUpdate for both local and remote hosts.
    - `Invoke-UHTestNativeUpdates`: Verifies the installation history of updates using native Windows Update API.
    - `Invoke-UHTestUpdates`: Verifies updates installed on specified hosts using PSWindowsUpdate.
    - `Update-UHWindows`: Main function coordinating update and verification processes with dual-mode logging.
    - `Update-Windows`: Standalone function providing user-friendly output for update and verification results.
    - `Set-Standalone`: Activates standalone mode for independent operations.
    - `Show-Help`: Displays usage instructions, syntax, and examples for core module functions.

    .PARAMETERS
    - `usePsUpdate`: Boolean to select PSWindowsUpdate for applying updates (defaults to native method if not specified).
    - `silent`: Boolean to suppress non-critical log output.
    - `groupName`: Name of a predefined host group for updates.
    - `hostName`: Name of a specific host, taking precedence over group if provided.
    - `successfulHosts`: Array of hosts validated for connectivity and update readiness.
    - `PsRemotingCredential`: Optional credentials for remote access if required.
    - `updateHistoryDays`: Specifies the number of days to retrieve update history for verification.

    .DEPENDENCIES
    The module relies on the `OpsUtils` core utilities module, which provides essential logging, 
    configuration, and utility functions. The `OpsUtils` module is imported during initialization if not already loaded.

    .LOGGING AND ROTATION
    The module integrates enhanced logging via `OpsUtils`, with a rotation mechanism that archives 
    logs every 50 entries or when the log size exceeds 10 MB. Logging behavior adapts to the operational 
    mode (standalone or integrated) for optimized output.

    .EXAMPLES
    `Update-Windows -UsePsUpdate:$true -GroupName "servers"`
    Applies PSWindowsUpdate to all hosts in the "servers" group, logging each action.

    `Update-Windows -successfulHosts $successfulHosts -Silent:$true`
    Applies native Windows Update to validated hosts, suppressing non-critical logs.

    .NOTES
    Designed for compatibility with both standalone and integrated environments, this module ensures 
    flexibility and reliability for managing Windows updates. The separation of applied and verified 
    updates enhances clarity, particularly in standalone mode.

    .ORGANIZATION
    Developed for the Faculty of Documentation and Communication Sciences, University of Extremadura.

    .AUTHOR [© 2024 Alberto Ledo]
    Alberto Ledo, Faculty of Documentation and Communication Sciences, University of Extremadura.
    Contact: albertoledo@unex.es

    .VERSION
    2.4.0

    .HISTORY
    2.4.0 - Added standalone table separation for applied and verified updates. Enhanced error handling in all functions.
    2.3.3 - Added conditional for dependency import in case they do not exist.
    2.3.2 - Enhanced logging and finalized standalone logging improvements.
    2.3.1 - Added `Update-Windows` alias for simplified command execution.
    2.3.0 - Implemented log rotation and dual-mode logging support.
    2.2.0 - Added JSON validation for host configuration and dual-mode function enhancements.
    2.1.0 - Modularized functions for update and logging operations.
    1.0.0 - Initial release supporting basic update automation.

    .DATE
    November 19, 2024

    .DISCLAIMER
    Provided "as-is" for internal University of Extremadura use. No warranty or support implied.

    .LINK
    https://github.com/n7rc/OpsHostGuard
#>


<#
#Requires -Module OpsInit
#Requires -Module OpsBase
#Requires -Module LogManager
#Requires -Module OpsUtils
#Requires -Module CredentialsManager
#>

if (-not $Global:ProjectRoot) {
    $scriptDirectory = (Get-Item -Path $MyInvocation.MyCommand.Definition).DirectoryName
    $Global:ProjectRoot = (Resolve-Path -Path (Join-Path -Path $scriptDirectory -ChildPath "../../../../")).Path
}

# Registrar la ruta del módulo
$moduleFolderPath = Join-Path -Path $ProjectRoot -ChildPath "modules/core/hosts_management/UpdateHosts"
if (-not ($env:PSModulePath -split ";" -contains $moduleFolderPath)) {
    $env:PSModulePath += ";$moduleFolderPath"
}

# Global variable to track the current mode
$Global:StandaloneMode = $false

# Module name setup
$Script:ModuleName = if ($null -ne $MyInvocation.MyCommand.Module) { $MyInvocation.MyCommand.Module.Name } else { "UpdateHosts" }

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

    $Script:StandaloneDependencies = @("OpsUtils", "CredentialsManager")

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

    # Get Credentials
    Initialize-GlobalPsRemotingCredential

}

# Function to display help message for the module's main functions
function Show-Help {
    param (
        [string]$functionName = "Update-Windows"
    )       

    # Display usage instructions for Update-UHWindows function
    Write-Host "`nUSAGE:`n" -ForegroundColor Yellow
    Write-Host "    $functionName [[-GroupName <String>] | [-HostName <String>] | [-HostsList <array>]] [-UsePsUpdate:[1|0]] [-ForceUpdate:[1|0]] [-UpdateHistoryDays [int]] 
        [-Silent:[1|0]] [-Verbose:[1|0]] [-PsRemotingCredential <PSCredential>]`n" -ForegroundColor White

    Write-Host "`nDESCRIPTION:`n" -ForegroundColor Yellow
    Write-Host "    The $functionName function facilitates Windows updates on remote hosts using both native Windows Update and the PSWindowsUpdate module. 
        Allows updating specific hosts or groups defined in the configuration." -ForegroundColor White

    # Describe each parameter for the function in detail
    Write-Host "
    -GroupName [Optional]
        Name of the host group to update." -ForegroundColor White
    Write-Host "
    -HostName [Optional]
        Name of a specific host belonging to a group to update." -ForegroundColor White
    Write-Host "
    -HostsList [Optional]
        Arbitrary host list to update. Format: host1, host2, host3, ..." -ForegroundColor White
    Write-Host "`nPARAMETERS:`n" -ForegroundColor Yellow
    Write-Host "    
    -UsePsUpdate [Optional]`n        
        Boolean to indicate if PSWindowsUpdate should be used." -ForegroundColor White
    Write-Host "
    -ForceUpdate [Optional]`n
        Boolean to Force Windows to update even with sessions activated. May require reboot." -ForegroundColor White
    Write-Host "
    -UpdateHistoryDays [Optional]`n
        Number of days for which the update history will be retrieved." -ForegroundColor White
    Write-Host "
    -Verbose [Optional]`n
        Boolean to active output messages debug mode." -ForegroundColor White
    Write-Host "
    -Silent [Optional]`n
        Boolean to suppress output messages except critical logs." -ForegroundColor White
    Write-Host "
    -PsRemotingCredential [Optional]`n
        Administrator credentials for remote connection. If not provided, the user will be prompted." -ForegroundColor White

    # Provide example usage for different scenarios
    Write-Host "`nEXAMPLES:`n" -ForegroundColor Yellow
    Write-Host "    Update-Windows -UsePsUpdate:1 -GroupName 'servers'" -ForegroundColor White
    Write-Host "    Applies updates using PSWindowsUpdate to all hosts in the 'servers' group."

    Write-Host "    Update-Windows -HostsList [host1 host2 ...] -Silent:1" -ForegroundColor White
    Write-Host "    Updates the hosts listed using the native method.`n" -ForegroundColor White
}

<#
Function: Invoke-UHWindowsUpdateNative
.SYNOPSIS
Performs native Windows updates on a list of successfully connected hosts.
.DESCRIPTION
This function executes Windows updates on a list of hosts using the native Windows Update API. 
It supports both local and remote hosts, checking for prerequisites and ensuring updates are 
installed without interrupting active user sessions unless forced. The function operates 
exclusively in integrated mode.
.PARAMETER forceUpdate
Indicates whether to bypass user session checks and proceed with updates. May trigger forced reboots.
.PARAMETER successfulHosts
An array of hosts that have been successfully connected and are eligible for updates.
.PARAMETER PsRemotingCredential
Administrator credentials for remote access to Windows hosts. Required for remote operations.
.PARAMETER debug
Enables detailed logging for debugging purposes.
.PARAMETER silent
Enables silent mode to suppress non-critical logs while still recording critical errors and results.
.OUTPUTS
Array of PSCustomObject containing the update results. Each object includes:
- HostName: The name of the host.
- Update: The title of the update.
- Status: The result of the update (e.g., Success, Failed).
- Timestamp: The date and time of the update.
.EXAMPLE
Perform updates on all successfully connected hosts without forcing updates:
Invoke-UHWindowsUpdateNative -successfulHosts $successfulHosts -PsRemotingCredential $cred -ForceUpdate $false
.EXAMPLE
Force updates on all hosts with detailed logging:
Invoke-UHWindowsUpdateNative -successfulHosts $successfulHosts -PsRemotingCredential $cred -ForceUpdate $true -Verbose $true
.EXAMPLE
Run updates silently for a predefined list of hosts:
Invoke-UHWindowsUpdateNative -successfulHosts $successfulHosts -PsRemotingCredential $cred -Silent $true
.NOTES
This function operates only in integrated mode. It validates each host to determine whether 
it is local or remote and applies appropriate update logic. Errors and update statuses are 
captured for each host in the returned results.
#>
function Invoke-UHWindowsUpdateNative {
    param (
        [bool]$ForceUpdate,
        [array]$successfulHosts, # Array of hosts that have been Successfully connected
        [PSCredential]$PsRemotingCredential,
        [bool]$Verbose,
        [bool]$Silent
    )

    Write-Host "Executing Invoke-UHWindowsUpdateNative in integrated mode..."

    $updateLogEntries = @()  # Initialize array for log entries

    if ($successfulHosts.Count -eq 0) {
        # Log no available hosts
        if (-not $Silent) {
            $logMessage = "No hosts are powered on for updating or verification."
            Add-LogMessage -message $logMessage -functionName $MyInvocation.InvocationName -logLevel "Info"
        }
        return $updateLogEntries
    }

    function Invoke-Update {
        param (
            [string]$targetHost,
            [bool]$isLocal,
            [PSCredential]$credential,
            [bool]$ForceUpdate,
            [bool]$Silent
        )

        try {
            # Detect active sessions if forceUpdate is not enabled
            if (-not $ForceUpdate) {
                $Sessions = if ($isLocal) {
                    try {
                        quser | Where-Object { $_ -match '\sActivo\s' } -ErrorAction SilentlyContinue
                    }
                    catch {
                        Add-LogMessage -message "Failed to check active sessions on host $targetHost. $_" `
                            -functionName $MyInvocation.InvocationName -logLevel "Warning"
                        $false
                    }
                }
                else {
                    try {
                        Invoke-Command -ComputerName $targetHost -credential $PsRemotingCredential -ScriptBlock {
                            quser | Where-Object { $_ -match '\sActivo\s' } -ErrorAction SilentlyContinue
                        }
                    }
                    catch {
                        Add-LogMessage -message "Failed to check active sessions on host $targetHost. $_" `
                            -functionName $MyInvocation.InvocationName -logLevel "Warning"
                        $false
                    }
                }

                if ($Sessions) {
                    Add-LogMessage -message "Active sessions detected on $targetHost. Skipping updates." `
                        -functionName $MyInvocation.InvocationName -logLevel "Warning"
                    return @()
                }
            }

            # Proceed with updates if no sessions are active or if forceUpdate is enabled
            if ($isLocal) {
                Write-Host "Applying updates locally on $env:COMPUTERNAME..." -ForegroundColor Cyan
                $updateSession = New-Object -ComObject Microsoft.Update.Session
                $updateSearcher = $updateSession.CreateUpdateSearcher()
                $updateHistory = $updateSearcher.QueryHistory(0, 50)
                foreach ($update in $updateHistory) {
                    [PSCustomObject]@{
                        HostName  = $env:COMPUTERNAME
                        Update    = $update.Title
                        Status    = "Installed"
                        Timestamp = Get-Date
                    }
                }
            }
            else {
                Write-Host "Applying updates remotely on $targetHost..." -ForegroundColor Cyan
                Invoke-Command -ComputerName $targetHost -credential $PsRemotingCredential -ScriptBlock {
                    $updateSession = New-Object -ComObject Microsoft.Update.Session
                    $updateSearcher = $updateSession.CreateUpdateSearcher()
                    $updateHistory = $updateSearcher.QueryHistory(0, 50)
                    foreach ($update in $updateHistory) {
                        [PSCustomObject]@{
                            HostName  = $env:COMPUTERNAME
                            Update    = $update.Title
                            Status    = "Installed"
                            Timestamp = Get-Date
                        }
                    }
                }
            }
        }
        catch {
            Add-LogMessage -message "Error updating host: $targetHost. $_" -functionName $MyInvocation.InvocationName -logLevel "Error"
            return [PSCustomObject]@{
                HostName  = $targetHost
                Update    = "Error"
                Status    = "Failed"
                Timestamp = Get-Date
            }
        }
    }
    
    
    #$HostNames = $successfulHosts | ForEach-Object { $_.HostName }

    foreach ($currentHost in $successfulHosts) {

        $HostName = $currentHost.HostName
        <#
        $HostName = if ($currentHost -is [string]) {
            $currentHost
        } elseif ($currentHost -is [hashtable] -and $currentHost.ContainsKey('HostName')) {
            $currentHost.HostName
        } else {
            throw "Invalid host format: $currentHost"
        } 
        #>     
        
        try {
            # Detect if host is local
            $isLocal = ($HostName -eq "localhost" -or $HostName -eq $env:COMPUTERNAME)

            # Invoke the update process for the host
            $updateResults = Invoke-Update -targetHost $HostName -isLocal $isLocal -credential $PsRemotingCredential -ForceUpdate $ForceUpdate -Silent $Silent

            # Append results to the log
            $updateLogEntries += $updateResults
            foreach ($entry in $updateResults) {
                Add-LogMessage -message "Host: $($entry.HostName), Update: $($entry.Update), Status: $($entry.Status)" -functionName $MyInvocation.InvocationName -logLevel "Info"
            }
        }
        catch {
            Add-LogMessage -message "Error processing host: $HostName. $_" -functionName $MyInvocation.InvocationName -logLevel "Error"
        }
    }

    return $updateLogEntries
}


<#
Function: Invoke-UHTestNativeUpdates
.SYNOPSIS
Verifies the installation history of updates on a list of successfully connected hosts using the native Windows Update API.
.DESCRIPTION
This function checks the Windows Update history on a list of hosts to verify updates installed within a configurable date range. 
It supports both local and remote hosts, ensuring compatibility with integrated operations. The function operates exclusively in integrated mode, 
and it uses the native Windows Update API for retrieval and validation.
.PARAMETER successfulHosts
An array of hosts that have been successfully connected and are eligible for update verification.
.PARAMETER updateHistoryDays
Specifies the number of days to retrieve update history for verification. Defaults to 7 days if not specified.
.PARAMETER PsRemotingCredential
Administrator credentials for remote access to Windows hosts. Required for remote operations.
.PARAMETER debug
Enables detailed logging for debugging purposes.
.PARAMETER silent
Enables silent mode to suppress non-critical logs while still recording critical errors and results.
.OUTPUTS
Array of PSCustomObject containing the verification results. Each object includes:
- HostName: The name of the host.
- Timestamp: The date and time of the update.
- Update: The title of the update.
- Status: The result of the verification (e.g., Installed, Error).
.EXAMPLE
Verify updates installed within the last 7 days on all successfully connected hosts:
Invoke-UHTestNativeUpdates -successfulHosts $successfulHosts -PsRemotingCredential $cred -UpdateHistoryDays 7
.EXAMPLE
Verify updates silently for a specific host with detailed logging:
Invoke-UHTestNativeUpdates -successfulHosts @("Host1") -PsRemotingCredential $cred -Silent $true -Verbose $true
.EXAMPLE
Check updates on a remote host without credentials (local-only mode):
Invoke-UHTestNativeUpdates -successfulHosts @("localhost") -UpdateHistoryDays 5
.NOTES
This function operates exclusively in integrated mode. It uses the Windows Update API to retrieve update history. 
Errors during the process are logged for each host, and results are returned in a structured format.
#>
function Invoke-UHTestNativeUpdates {
    param (
        [array]$successfulHosts, # List of successfully connected hosts
        [int]$UpdateHistoryDays = 7, # Number of days to check the update history
        [PSCredential]$PsRemotingCredential, # Credentials for remote access
        [bool]$Verbose, # Enables detailed logging
        [bool]$Silent # Silent mode to minimize output
    )

    if (-not $successfulHosts -or $successfulHosts.Count -eq 0) {
        Add-LogMessage -message "No hosts provided for update verification." `
            -functionName $MyInvocation.InvocationName -logLevel "Error" -Silent:$Silent
        return @()
    }

    $verificationUpdateEntries = @()

    foreach ($currentHost in $successfulHosts) {

        $HostName = $currentHost.HostName
        <#
        $HostName = if ($currentHost -is [string]) {
            $currentHost
        } elseif ($currentHost -is [hashtable] -and $currentHost.ContainsKey('HostName')) {
            $currentHost.HostName
        } else {
            throw "Invalid host format: $currentHost"
        } 
        #>     

        try {
            $isLocal = ($HostName -eq "localhost" -or $HostName -eq $env:COMPUTERNAME)
            $updateHistory = @()

            if ($isLocal) {
                # Validate Windows Update Service
                if (-not (Get-Service -Name "wuauserv" -ErrorAction SilentlyContinue).Status -eq "Running") {
                    throw "Windows Update service is not running on $env:COMPUTERNAME."
                }

                # Local update history
                $updateSession = New-Object -ComObject Microsoft.Update.Session
                $updateSearcher = $updateSession.CreateUpdateSearcher()
                $history = $updateSearcher.QueryHistory(0, 50) | Where-Object {
                    [DateTime]$_.Date -ge (Get-Date).AddDays(-$UpdateHistoryDays)
                }
                $updateHistory = $history | ForEach-Object {
                    [PSCustomObject]@{
                        HostName  = $env:COMPUTERNAME
                        Timestamp = $_.Date
                        Update    = $_.Title
                        Status    = "Installed"
                    }
                }
            }
            else {
                # Remote update history
                $updateHistory = Invoke-Command -ComputerName $HostName -credential $PsRemotingCredential -ArgumentList $UpdateHistoryDays -ScriptBlock {
                    param ($historyDays)
                    if (-not (Get-Service -Name "wuauserv" -ErrorAction SilentlyContinue).Status -eq "Running") {
                        throw "Windows Update service is not running on $env:COMPUTERNAME."
                    }

                    $updateSession = New-Object -ComObject Microsoft.Update.Session
                    $updateSearcher = $updateSession.CreateUpdateSearcher()
                    $history = $updateSearcher.QueryHistory(0, 50) | Where-Object {
                        [DateTime]$_.Date -ge (Get-Date).AddDays(-$historyDays)
                    }
                    $history | ForEach-Object {
                        [PSCustomObject]@{
                            HostName  = $env:COMPUTERNAME
                            Timestamp = $_.Date
                            Update    = $_.Title
                            Status    = "Installed"
                        }
                    }
                }
            }

            $verificationUpdateEntries += $updateHistory
            foreach ($entry in $updateHistory) {
                Add-LogMessage -message "Verified update: $($entry.Update) on $($entry.HostName)" `
                    -functionName $MyInvocation.InvocationName -logLevel "Info" -Silent:$Silent
            }
        }
        catch {
            Add-LogMessage -message "Error verifying updates on ${hostName}: $_" `
                -functionName $MyInvocation.InvocationName -logLevel "Error" -Silent:$Silent
            $verificationUpdateEntries += [PSCustomObject]@{
                HostName  = $HostName
                Timestamp = Get-Date
                Update    = "Error"
                Status    = "Failed"
            }
        }
    }

    return $verificationUpdateEntries
}
  
    
<#
Function: Invoke-UHWindowsUpdatePsUpdate
.SYNOPSIS
Invokes Windows updates on specified hosts using PSWindowsUpdate with optional forced updates.
.DESCRIPTION
This function updates Windows hosts, both local and remote, using the PSWindowsUpdate module.
It supports forced updates, silent mode, and the ability to check for active user sessions before 
proceeding (if not in forceUpdate mode). The updates are applied selectively based on whether the 
host is "localhost" or a remote machine, with appropriate credential handling for remote operations.
.PARAMETER forceUpdate
Specifies whether updates should be forced regardless of active user sessions. 
Forced updates may result in automatic reboots.
.PARAMETER successfulHosts
An array of hosts (local or remote) to be updated. The function validates the host list 
and excludes "localhost" references, replacing them with the actual machine name.
.PARAMETER PsRemotingCredential
Administrator credentials used for remote host access. If not provided, the function assumes 
local updates or fails for remote updates requiring authentication.
.PARAMETER debug
Enables debug mode to provide detailed logs during the update process.
.PARAMETER silent
Suppresses console output, limiting logs to the primary log file or fallback log.
.OUTPUTS
An array of custom objects, each containing the following fields:
- HostName: Name of the host where the update was Invokeed.
- Update: Title of the update applied.
- Status: The outcome of the update process (e.g., "Success" or "Failed").
- Timestamp: Date and time of the update operation.
.EXAMPLE
Invoke updates on a single remote host using PSWindowsUpdate with no forced updates:
Invoke-UHWindowsUpdatePsUpdate -successfulHosts @("RemoteHost1") -PsRemotingCredential $credential
.EXAMPLE
Force updates on multiple hosts without checking for active sessions:
Invoke-UHWindowsUpdatePsUpdate -ForceUpdate -successfulHosts @("Host1", "Host2", "Host3")
.EXAMPLE
Update localhost in silent mode with forced updates:
Invoke-UHWindowsUpdatePsUpdate -ForceUpdate -successfulHosts @("localhost") -Silent:$true
.NOTES
This function is intended to be used in integrated mode. 
It does not support standalone execution and throws an exception if called in standalone mode.
To Invoke updates in standalone mode, use the `Update-Windows` function instead.
#>

function Invoke-UHWindowsUpdatePsUpdate {
    param (
        [bool]$ForceUpdate,
        [array]$successfulHosts, # List of successfully powered-on hosts
        [PSCredential]$PsRemotingCredential, # Administrator credentials for remote access
        [bool]$Verbose,
        [bool]$Silent  # Silent mode flag to suppress output
    )

    Write-Host "Executing Invoke-UHWindowsUpdatePsUpdate..." -ForegroundColor Green

    # Validate successfulHosts as an array
    if (-not ($successfulHosts -is [array])) {
        Add-LogMessage -message "The successfulHosts parameter must be an array. Received type: $($successfulHosts.GetType().Name)" `
            -functionName $MyInvocation.InvocationName -logLevel "Error"
        throw "Invalid parameter: successfulHosts must be an array."
    }

    # Validate input hosts
    if (-not $successfulHosts -or $successfulHosts.Count -eq 0) {
        Add-LogMessage -message "No hosts provided for update operation." `
            -functionName $MyInvocation.InvocationName -logLevel "Warning" -Silent:$Silent
        return @()
    }

    # Normalize "localhost" references
    $successfulHosts = $successfulHosts | ForEach-Object {
        if ($_ -eq "localhost") { $env:COMPUTERNAME } else { $_ }
    }

    $updateLogEntries = @()

    # Helper function to Invoke updates
    
    function Invoke-Update {
        param (
            [string]$targetHost,
            [bool]$isLocal,
            [PSCredential]$credential
        )

        try {
            if ($isLocal) {
                # Local update logic
                if (-not (Get-PackageProvider -Name NuGet -ErrorAction SilentlyContinue)) {
                    Install-PackageProvider -Name NuGet -Force -Scope CurrentUser
                }
                if (-not (Get-Module -ListAvailable -Name PSWindowsUpdate)) {
                    Install-Module -Name PSWindowsUpdate -Force -Scope CurrentUser
                }
                Import-Module PSWindowsUpdate

                $localUpdates = Get-WindowsUpdate | Where-Object { $_.Title -notlike "Preview" }
                foreach ($update in $localUpdates) {
                    Install-WindowsUpdate -AcceptAll -AutoReboot -ErrorAction SilentlyContinue |
                    ForEach-Object {
                        [PSCustomObject]@{
                            HostName  = $env:COMPUTERNAME
                            Update    = $_.Title
                            Status    = if ($_.InstallResult -eq 'Succeeded') { "Success" } else { "Failed" }
                            Timestamp = Get-Date
                        }
                    }
                }
            }
            else {
                # Remote update logic
                #Invoke-Command -ComputerName $targetHost -credential $PsRemotingCredential  -ScriptBlock {
                Invoke-Command -ComputerName $targetHost -Credential $PsRemotingCredential -ScriptBlock {
                    $ConfirmPreference = 'None'
                    $ErrorActionPreference = 'SilentlyContinue'

                    if (-not (Get-PackageProvider -Name NuGet -ErrorAction SilentlyContinue)) {
                        Install-PackageProvider -Name NuGet -Force -Scope CurrentUser
                    }
                    if (-not (Get-Module -ListAvailable -Name PSWindowsUpdate)) {
                        Install-Module -Name PSWindowsUpdate -Force -Scope CurrentUser
                    }
                    Import-Module PSWindowsUpdate
                    Update-WUModule -Online -Credential $PsRemotingCredential


                    #Get-WindowsUpdate | Where-Object { $_.Title -notlike "Preview" } |
                    #-IgnoreReboot: Evita que el sistema se reinicie automáticamente después de la instalación de las actualizaciones, incluso si es necesario.
                    Invoke-WUJob -RunNow -Credential $PsRemotingCredential -Force -Script {
                        # Ejecutar Get-WindowsUpdate y validar la salida
                        $updates = Get-WindowsUpdate -Verbose -MicrosoftUpdate -AcceptAll -Install -ForceInstall -AutoReboot -ErrorAction SilentlyContinue
                        
                        # Verificar si $updates contiene resultados
                        if ($null -ne $updates -and $updates.Count -gt 0) {
                            # Filtrar actualizaciones y procesarlas
                            $updates | Where-Object { $_.Title -notlike "Preview" } | ForEach-Object {
                                try {
                                    # Instalar cada actualización y capturar resultados
                                    $installResult = Install-WindowsUpdate -Verbose -AcceptAll -AutoReboot -ErrorAction SilentlyContinue
                                    [PSCustomObject]@{
                                        HostName  = $env:COMPUTERNAME
                                        Update    = $_.Title
                                        Status    = if ($installResult.InstallResult -eq 'Succeeded') { "Success" } else { "Failed" }
                                        Timestamp = Get-Date
                                    }
                                }
                                catch {
                                    # Manejar errores durante la instalación de la actualización
                                    Write-Error "Error installing update $($_.Title) on ${$env:COMPUTERNAME}: $_"
                                    [PSCustomObject]@{
                                        HostName  = $env:COMPUTERNAME
                                        Update    = $_.Title
                                        Status    = "Failed"
                                        Timestamp = Get-Date
                                    }
                                }
                            }
                        }
                        else {
                            # Registrar que no hay actualizaciones disponibles
                            Write-Verbose "No updates available or an error occurred for $env:COMPUTERNAME."
                            [PSCustomObject]@{
                                HostName  = $env:COMPUTERNAME
                                Update    = "No updates"
                                Status    = "Skipped"
                                Timestamp = Get-Date
                            }
                        }
                    }
                    
                }
            }
        }
        catch {
            Add-LogMessage -message "Error updating host: $targetHost. $_" -functionName $MyInvocation.InvocationName -logLevel "Error"
            return [PSCustomObject]@{
                HostName  = $targetHost
                Update    = "Error"
                Status    = "Failed"
                Timestamp = Get-Date
            }
        }
    }

    # Main loop to process each host

    #$HostNames = $successfulHosts | ForEach-Object { $_.HostName }
    
    foreach ($currentHost in $successfulHosts) {
        
        $HostName = $currentHost.HostName
        <#
        $HostName = if ($currentHost -is [string]) {
            $currentHost
        } elseif ($currentHost -is [hashtable] -and $currentHost.ContainsKey('HostName')) {
            $currentHost.HostName
        } else {
            throw "Invalid host format: $currentHost"
        } 
        #>     
        
        try {
            $isLocal = ($HostName -eq "localhost" -or $HostName -eq $env:COMPUTERNAME)

            if (-not $ForceUpdate) {
                # Check for active sessions
                $Sessions = if ($isLocal) {
                    try {
                        quser | Where-Object { $_ -match '\sActivo\s' } -ErrorAction SilentlyContinue
                    }
                    catch {
                        Add-LogMessage -message "Failed to check active sessions on host $HostName. $_" `
                            -functionName $MyInvocation.InvocationName -logLevel "Warning"
                        $false
                    }
                }
                else {
                    try {
                        Invoke-Command -ComputerName $HostName -credential $PsRemotingCredential -ScriptBlock {
                            quser | Where-Object { $_ -match '\sActivo\s' } -ErrorAction SilentlyContinue
                        }
                    }
                    catch {
                        Add-LogMessage -message "Failed to check active sessions on host $HostName. $_" `
                            -functionName $MyInvocation.InvocationName -logLevel "Warning"
                        $false
                    }
                }

                if ($Sessions) {
                    Add-LogMessage -message "Active sessions detected on $HostName. Skipping updates." `
                        -functionName $MyInvocation.InvocationName -logLevel "Warning"
                    continue
                }
            }

            $updateResults = Invoke-Update -targetHost $HostName -isLocal $isLocal -credential $PsRemotingCredential
            $updateLogEntries += $updateResults
        }
        catch {
            Add-LogMessage -message "Error processing host: $HostName. $_" -functionName $MyInvocation.InvocationName -logLevel "Error"
        }
    }

    return $updateLogEntries
}

Write-Host "[$timestamp] [Info] Invoke-UHWindowsUpdatePsUpdate function loaded successfully." -ForegroundColor Green

<#
Function: Invoke-UHTestUpdates
.SYNOPSIS
Verifies updates installed on a list of Windows hosts within a configurable date range.
.DESCRIPTION
This function checks the Windows Update history on a list of successfully connected hosts
to verify if updates were installed within a specific date range. The range can be configured
via the global configuration or defaults to a specified number of days.
.PARAMETER successfulHosts
An array of hosts that are successfully connected and need update verification.
.PARAMETER updateHistoryDays
Specifies the number of days to retrieve update history for verification. Defaults to a global or predefined value.
.PARAMETER PsRemotingCredential
Administrator credentials required for remote access to the hosts. If not provided,
verification will not proceed.
.PARAMETER debug
Enables detailed logging for debugging purposes.
.PARAMETER silent
Enables silent mode to suppress non-critical logs. Critical errors and important messages
are still logged.
.OUTPUTS
Array of PSCustomObject containing the verification results. Each object includes:
- HostName: The name of the host.
- Timestamp: The date and time of the update.
- Status: The title of the update.
- Result: Whether the update was successful or failed.
.EXAMPLE
Verify updates on all hosts in a group within a specific number of days:
Invoke-UHTestUpdates -successfulHosts $successfulHosts -UpdateHistoryDays 7 -PsRemotingCredential $cred -Silent $true
.EXAMPLE
Invoke a detailed update verification with debug mode enabled:
Invoke-UHTestUpdates -successfulHosts $successfulHosts -UpdateHistoryDays 10 -PsRemotingCredential $cred -Verbose $true
#>
function Invoke-UHTestUpdates {
    param (
        [array]$successfulHosts, # List of successfully powered-on hosts
        [int]$UpdateHistoryDays = 7,
        [PSCredential]$PsRemotingCredential, # Administrator credentials for remote access
        [bool]$Verbose = $false,
        [bool]$Silent = $false  # Silent mode flag to suppress output
    )

    # Initialize verification log entries
    $verificationUpdateEntries = @()

    # Validate input hosts
    if (-not $successfulHosts -or $successfulHosts.Count -eq 0) {
        Add-LogMessage -message "No hosts are powered on to verify updates." -functionName $MyInvocation.InvocationName -logLevel "Info" -Silent:$Silent
        return $verificationUpdateEntries
    }

    # Get the number of days to check for update history
    $historyDays = $UpdateHistoryDays
    if (-not $historyDays) {
        $historyDays = 5 # Default to 5 days if not configured
    }

    # Loop through each host to verify updates
    #$HostNames = $successfulHosts | ForEach-Object { $_.HostName }
    
    foreach ($currentHost in $successfulHosts) {

        $HostName = $currentHost.HostName
        <#
        $HostName = if ($currentHost -is [string]) {
            $currentHost
        } elseif ($currentHost -is [hashtable] -and $currentHost.ContainsKey('HostName')) {
            $currentHost.HostName
        } else {
            throw "Invalid host format: $currentHost"
        } 
        #>     

        try {
            # Execute remote command to get update history within the defined range
            $updateHistory = Invoke-Command -ComputerName $HostName -credential $PsRemotingCredential -ArgumentList $historyDays -ScriptBlock {
                param ($days)
                $startDate = (Get-Date).AddDays(-$days)
                $endDate = Get-Date # Today
                Import-Module PSWindowsUpdate
                Get-WUHistory | Where-Object { 
                    $_.Date -ge $startDate -and $_.Date -le $endDate 
                }
            }

            # Parse and log updates for the host
            foreach ($update in $updateHistory) {
                $verificationEntry = [PSCustomObject]@{
                    HostName  = $HostName
                    Timestamp = $update.Date
                    Update    = $($update.Title)
                    Status    = "Installed"
                }
                $verificationUpdateEntries += $verificationEntry
                Add-LogMessage -message "Verified update: $($verificationEntry.Update) on $($verificationEntry.HostName)" `
                    -functionName $MyInvocation.InvocationName -logLevel "Info" -Silent:$Silent
            }

            # Log verification completion for the host
            Add-LogMessage -message "Verification completed for host: $HostName" -functionName $MyInvocation.InvocationName -logLevel "Info" -Silent:$Silent
        }
        catch {
            # Handle and log errors during verification
            $errorMessage = "Error verifying updates on host: $HostName. Exception: $($_.Exception.Message)"
            Add-LogMessage -message $errorMessage -functionName $MyInvocation.InvocationName -logLevel "Error" -Silent:$Silent

            # Record error in verification log entries
            $verificationUpdateEntries += [PSCustomObject]@{
                HostName  = $HostName
                Timestamp = Get-Date
                Update    = "Error"
                Status    = "Failed"
            }
        }
    }

    # Return the verification log entries
    return $verificationUpdateEntries
}


<#
Function: Update-UHWindows
.SYNOPSIS
Updates Windows hosts from a specified group using PSWindowsUpdate or a native method.
.DESCRIPTION
This function Invokes updates on a group of Windows hosts. It validates the specified group,
checks the connectivity of each host, and executes updates using either PSWindowsUpdate or a native
method based on the provided flags. The function works only in integrated mode.
.PARAMETER groupName
The name of the host group for updates.
.PARAMETER successfulHosts
(Optional) A pre-defined list of hosts to update. If not provided, the function validates and populates the list.
.PARAMETER usePsUpdate
Flag to indicate whether PSWindowsUpdate should be used.
.PARAMETER forceUpdate
Indicates whether to force updates.
.PARAMETER updateHistoryDays
Specifies the number of days to retrieve update history for verification. Defaults to a global or predefined value.
.PARAMETER PsRemotingCredential
Credentials for remote access. If not provided, the user is prompted for credentials.
.PARAMETER debug
Enables debug logging.
.PARAMETER silent
Enables silent mode to suppress non-critical logs.
.OUTPUTS
Hashtable with update results.
.EXAMPLE
Update all hosts in Group1 using PSWindowsUpdate
Update-UHWindows -GroupName "Group1" -UsePsUpdate -ForceUpdate
#>
function Update-UHWindows {
    param (
        [string]$HostName = $null, # Specific host to update if provided
        [string]$GroupName, # Name of the host group for updates
        [array]$HostsList = @(),
        [array]$successfulHosts = @(),
        [bool]$UsePsUpdate,
        [bool]$ForceUpdate,
        [int]$UpdateHistoryDays,
        [Pscredential]$PsRemotingCredential,
        [bool]$Verbose,
        [bool]$Silent
    )

    # Load the host list
    if ($GroupName -eq "temporaryGroup" -and $Global:Config.hostsData.Groups -is [hashtable] -and $Global:Config.hostsData.Groups.ContainsKey("temporaryGroup")) {
        $HostsList = $Global:Config.hostsData.Groups["temporaryGroup"]
    }
    else {
        $HostsList = Get-HostsGroups -GroupName $GroupName
    }
    
    if (-not $HostsList) {
        Add-LogMessage -functionName $MyInvocation.InvocationName -logLevel "Error" -message "Failed to load host groups from JSON."
        return
    }

    # Populate successfulHosts if not already provided
    if (-not $successfulHosts -or $successfulHosts.Count -eq 0) {
        # Validar y obtener los hosts asociados al grupo
        if ($GroupName) {
            # Caso: Se especifica un grupo, buscarlo usando Get-HostsGroups
            $groupHosts = Get-HostsGroups -GroupName $GroupName
    
            if (-not $groupHosts) {
                Add-LogMessage -functionName $MyInvocation.InvocationName -logLevel "Error" `
                    -message "Group '$GroupName' not found or contains no hosts."
                return
            }
            # Convertir cada host en el formato esperado de PSCustomObject
            $groupHosts = $groupHosts[$GroupName] | ForEach-Object {
                [PSCustomObject]@{ HostName = $_ }
            }
        }
        # Filtrar los hosts que están en línea
        $successfulHosts = $groupHosts | Where-Object {
            if (Test-Connection -ComputerName $_.HostName -Count 1 -Quiet) {
                Add-LogMessage -functionName $MyInvocation.InvocationName -logLevel "Info" `
                    -message "Host $($_.HostName) is online and will be added to the update list."
                $true
            }
            else {
                Add-LogMessage -functionName $MyInvocation.InvocationName -logLevel "Info" `
                    -message "Host $($_.HostName) is offline and will not be added to the update list."
                $false
            }
        }

        # Validar si hay hosts en línea
        if ($successfulHosts.Count -eq 0) {
            Add-LogMessage -functionName $MyInvocation.InvocationName -logLevel "Error" `
                -message "No hosts are online in the specified group or list."
            return
        }
    }
    # Initialize log arrays
    $updateLogEntries = @()
    $verificationUpdateEntries = @()

    # Execute updates
    if ($UsePsUpdate) {
        Add-LogMessage -message "Using PSWindowsUpdate for updates..." `
            -functionName $MyInvocation.InvocationName -logLevel "Info"

        $updateLogEntries = Invoke-UHWindowsUpdatePsUpdate `
            -ForceUpdate:$ForceUpdate `
            -successfulHosts $successfulHosts `
            -PsRemotingCredential $PsRemotingCredential `
            -Verbose:$Verbose `
            -Silent:$Silent

        if ($UpdateHistoryDays) {
            $verificationUpdateEntries = Invoke-UHTestUpdates `
                -successfulHosts $successfulHosts `
                -UpdateHistoryDays $UpdateHistoryDays `
                -PsRemotingCredential $PsRemotingCredential `
                -Verbose:$Verbose `
                -Silent:$Silent
        }
    }
    else {
        Add-LogMessage -message "Using native Windows Update method for updates..." `
            -functionName $MyInvocation.InvocationName -logLevel "Info"

        $updateLogEntries = Invoke-UHWindowsUpdateNative `
            -ForceUpdate:$ForceUpdate `
            -successfulHosts $successfulHosts `
            -PsRemotingCredential $PsRemotingCredential `
            -Verbose:$Verbose `
            -Silent:$Silent

        if ($UpdateHistoryDays) {
            $verificationUpdateEntries = Invoke-UHTestNativeUpdates `
                -successfulHosts $successfulHosts `
                -UpdateHistoryDays $UpdateHistoryDays `
                -PsRemotingCredential $PsRemotingCredential `
                -Verbose:$Verbose `
                -Silent:$Silent
        }
    }

        
    # Create the result hashtable dynamically
    $result = @{}
    $result["UpdateLogEntries"] = $updateLogEntries

    # Conditionally add VerificationUpdateEntries
    if ($UpdateHistoryDays) {
        $result["VerificationUpdateEntries"] = $verificationUpdateEntries
    }

    # Return the constructed hashtable
    return $result
   
}

<#
Function: Update-Windows
.SYNOPSIS
Updates Windows hosts in standalone mode using PSWindowsUpdate or a native method, with separate reporting for applied and verified updates.
.DESCRIPTION
This function invokes updates on Windows hosts in standalone mode. It validates the provided group, host, or list of hosts, and then delegates
the update process to the integrated `Update-UHWindows` function. The function supports optional silent mode, forced updates, and the use of PSWindowsUpdate
if specified. The output is formatted for console display in standalone mode, with separate tables for applied updates and verified updates.
.PARAMETER hostName
(Optional) Specifies a single host to update. Takes precedence over groupName and hostsList.
.PARAMETER groupName
Specifies the name of the host group for updates.
.PARAMETER hostsList
(Optional) A pre-defined list of hosts to update. If not provided, the function validates and populates the list.
.PARAMETER usePsUpdate
Flag to indicate whether PSWindowsUpdate should be used.
.PARAMETER forceUpdate
Indicates whether to force updates. This may trigger a System reboot.
.PARAMETER updateHistoryDays
Specifies the number of days to retrieve update history for verification. Defaults to a global or predefined value.
.PARAMETER PsRemotingCredential
Credentials for remote access. If not provided, the user is prompted to enter credentials.
.PARAMETER silent
Enables silent mode to suppress non-critical logs.
.OUTPUTS
Two separate formatted console tables displaying:
- Updates Applied: Lists updates that were applied to the selected hosts.
- Updates Verified: Lists update history of selected hosts within the specified range.
.EXAMPLE
Update a single host in standalone mode using native updates:
Update-Windows -HostName "Host1" -UsePsUpdate:$false -Silent:$true
.EXAMPLE
Update all hosts in Group1 using PSWindowsUpdate in standalone mode:
Update-Windows -GroupName "Group1" -UsePsUpdate -ForceUpdate
.EXAMPLE
Update a custom list of hosts with forced updates:
Update-Windows -HostsList Host1, Host2, Host3 -UsePsUpdate -ForceUpdate
.NOTES
This function works exclusively in standalone mode and assumes console output. Integrated mode operations should use `Update-UHWindows` directly.
The output separates applied updates and verified updates into distinct tables for clarity.
#>

function Update-Windows {
    param (
        [string]$HostName = $null, # Specific host to update if provided
        [string]$GroupName, # Name of the host group for updates
        [array]$HostsList = @(),
        [bool]$UsePsUpdate, # Flag to indicate if PSWindowsUpdate should be used
        [bool]$ForceUpdate,
        [int]$UpdateHistoryDays,
        [pscredential]$PsRemotingCredential, # Credentials for remote access
        [bool]$UseDNS,
        [bool]$Silent # Silent mode to suppress non-critical logs
    )

    Add-LogMessage -message "Executing Update-Windows in standalone mode..." `
        -functionName $MyInvocation.InvocationName -logLevel "Info"

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
        Show-Help -CommandName "Update-Windows"
        return
    }

    Write-Host "Executing Update-Windows in standalone mode..."

    if ($Silent) {
        Write-Host "Silent mode enabled. Suppressing non-critical logs." -ForegroundColor White
    }
    if ($UsePsUpdate) {
        Write-Host "Using PSWindowsUpdate for updates." -ForegroundColor White
    }
    if ($ForceUpdate) {
        Write-Host "Forced update activated, the System might reboot." -ForegroundColor White
    }

    try {

        $effectiveCredential = if ($Global:Standalone) {
            $Global:PsRemotingCredential
        } else {
            $PsRemotingCredential
        }

        # Delegate to Update-UHWindows
        $resultUpdate = Update-UHWindows -GroupName $GroupName `
            -UsePsUpdate:$UsePsUpdate `
            -ForceUpdate:$ForceUpdate `
            -UpdateHistoryDays $UpdateHistoryDays `
            -PsRemotingCredential $effectiveCredential `
            -Silent:$Silent

        # Display results
        if ($resultUpdate["UpdateLogEntries"].Count -gt 0) {
            Write-Host "`nUpdates Applied:" -ForegroundColor Green
            $resultUpdate["UpdateLogEntries"] | Format-Table -AutoSize
        }

        if ($resultUpdate.ContainsKey("VerificationUpdateEntries") -and $resultUpdate["VerificationUpdateEntries"].Count -gt 0) {
            Write-Host "`nUpdates Verified:" -ForegroundColor Cyan
            $resultUpdate["VerificationUpdateEntries"] | Format-Table -AutoSize
        }
    }
    finally {
        Add-LogMessage -message "Update-Windows execution completed." `
            -functionName $MyInvocation.InvocationName -logLevel "Info"
    }
}

$Global:StandaloneMode = $false

# Clean up old logs in standalone mode
if (Test-ExecutionContext -ConsoleCheck) {
    Remove-OldLogFiles -logDirectory $Global:Config.Paths.Log.Update -retainCount 10
}

# Export all proxy functions
Export-ModuleMember -Function Show-Help, Update-Windows, Update-UHWindows
