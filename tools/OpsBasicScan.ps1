# OpsBasicScan.ps1 [OpsHostGuard]

<#
    .SYNOPSIS
    Automates the daily management of Windows hosts, including power-on, shutdown, system load monitoring, session detection,
    event log capture, mandatory updates, hardware inventory collection, and generating reports in HTML, CSV, and SQL queries
    for database . Also supports email notifications to the system administrator. Now includes support for secure credential
    management and dynamic PHP configuration updates. and now includes automated credential management.

    .DESCRIPTION
    This script automates several key administrative tasks for managing a group of Windows hosts, while also incorporating user logon
    functionality for secured access to the dashboard. Additionally, the script now supports secure credential storage for PSRemoting,
    database access, and dashboard access, leveraging the `Create-Credentials` script for automated credential creation and encryption.
    The script leverages a global configuration module for PowerShell settings and a specific module for dynamically generating PHP
    configuration variables required by the dashboard, which simplifies managing application configurations.

    This script imports four primary modules to manage different aspects of host control and configuration within OpsHostGuard:
    - GlobalConfig: Manages global settings and configurations.
    - ActiveSessions: Retrieves and processes active user sessions on specified hosts.
    - Stop-Hosts: Automates the shutdown of specified hosts, ensuring no active sessions are present.
    - Start-Hosts: Manages the startup of specified hosts.


    1. **Configuration Management**:
       - Loads a **global configuration module** for PowerShell settings, ensuring consistent configuration across 
         all related scripts.
       - Uses a **PHP configuration module** to dynamically generate PHP variables based on the application's current 
         settings.
    
    2. **Logon Management:**
       - Ensures users are authenticated before accessing the dashboard by verifying credentials via `AuthController.php`.
       - Handles session creation, validation, and automatic redirection on logon Success or failure.

    3. **Host Management:**
       - Powers on hosts from a specified group (default: "all").
       - Monitors CPU, memory, and disk usage for the powered-on hosts, including alerts when usage exceeds 80%.
       - Detects active user sessions on the hosts.
       - Attempts to shut down hosts that have no active sessions.

    4. **Updates and Event Logs:**
       - Automatically installs updates on Successfully powered-on hosts:
           - If `-UpdateHosts` is not specified, either the parameter is not passed, updates are installed using internal Windows commands (beta).
           - If `-UpdateHosts` is set to `psupdate`, updates are installed using the PSWindowsUpdate module.
       - Captures critical events (Level 1) from System and Setup logs, and Error events (Level 2) from Application logs from the last 7 days.

    5. **Reports and Notifications:**
       - Uses stored credentials for remote operations, including PowerShell remoting and Windows Update management.
       - Generates comprehensive reports in HTML with print preview and PDF export functionalities.
       - Exports host metrics, hardware inventory, and summary data to CSV and log files for easy data tracking and sharing.
       - Prepares SQL queries for host metrics, hardware details, and summary data, enabling easy database  for further analysis.
       - Sends email notifications to the system administrator, summarizing the results of the daily operations, including power-on and
         shutdown status, system resource usage, update results, and hardware inventory.

    6. **Credential Management:**
       - Integrates secure credential storage for PSRemoting, database access, and dashboard access by utilizing `Create-Credentials.ps1`.
       - `Create-Credentials.ps1` securely collects user credentials, encrypts them with PowerShell's Export-Clixml, and stores them as XML files.
       - Credentials are stored as SecureStrings to ensure encryption and security during retrieval, accessed in scripts using the `Import-Clixml` method.
    
    7. **Historical Hardware Inventory Tracking:**
       - The hardware inventory for each host is stored in the `hardware_inventory` table with a unique `inventory_datestamp` column.
       - Each `host_metrics` record includes an `inventory_datestamp` reference, linking performance metrics to a specific hardware configuration.
       - Allows tracking of changes in hardware over time, providing insights into how hardware modifications impact host performance.
    
    .CMDLET NAMING CONVENTION
    To maintain clarity and consistency, the cmdlets within each module follow a standardized naming convention:
    Verb-(ID-Module)Action
    Here:
    - "Verb" describes the action performed by the cmdlet.
    - "ID-Module" is a unique identifier based on the module name:
        - OpsHostGuard management script = MG
        - ActiveSessions = AS
        - Stop-Hosts = SH
        - Start-Hosts = ST
    - "Action" describes the specific operation of the cmdlet.

    EXAMPLES OF CMDLETS:
    - Get-ASActiveSessions: Retrieves active sessions from the ActiveSessions module.
    - Stop-STHHost: Shuts down a host through the Stop-Hosts module.
    - Start-STHost: Starts a host via the Start-Hosts module.

    This naming convention enhances readability and avoids conflicts by providing a unique prefix for each cmdlet, clearly
    linking it to its respective module.

    .EXAMPLE
    .\OpsBasicScan.ps1 -GroupName "all" -UpdateHosts "psupdate" -Inventory
    This example manages all hosts in the "all" group by powering them on, checking for active sessions, monitoring system load, 
    performing updates with the PSWindowsUpdate module, and running a comprehensive hardware inventory check.

    .EXAMPLE
    .\OpsBasicScan.ps1 -GroupName "administration" -csvFilePathHosts "./dashboard/data/csv/hostMetrics.csv"
    In this example, the script targets hosts in the "administration" group, generates a CSV report of host metrics, and saves it in the
    specified path.

    .EXAMPLE
    .\OpsBasicScan.ps1 -GroupName "labs" -Verbose
    This example invokes the script for the "labs" group with Debug mode enabled, providing detailed logs and messages for troubleshooting.

    .EXAMPLE
    .\OpsBasicScan.ps1 -config
    This example cctivates the dynamic generation or update of a PHP configuration file, used by the application's dashboard.

    .PARAMETER -GroupName
    Specifies the group of hosts to manage. The default value is "all."

    .PARAMETER -UseDNS
    Enable DNS usage when the -UseDNS parameter is specified upon script invocation.

    .PARAMETER -UpdateHosts ["psupdate", ""]
    If specified with the value `psupdate`, the script will install updates using the PSWindowsUpdate module.
    If specified without parameters, updates will be installed using internal Windows commands.

    .PARAMETER -Inventory
    Enables Inventory Mode, allowing the script to perform a comprehensive hardware inventory check for each host.
    When this parameter is set, the script collects detailed Information on hardware components, including 
    CPU, RAM, network adapters, BIOS, motherboard, and storage devices. This mode is designed for tracking hardware
    configurations over time, making it ideal for historical hardware auditing and asset management.

    .PARAMETER -config
    Activates the dynamic generation or update of a PHP configuration file, used by the application's dashboard.
    
    .PARAMETER -Verbose
    Debug mode, displaying detailed logs and messages for troubleshooting.

    .PARAMETER -Silent
    Silent mode for application messages (system messages will continue to appear)


    .NOTES
    - Requires administrative privileges for certain remote operations.
    - PowerShell remoting must be enabled on target hosts for remote execution.
    - Uses stored credentials loaded from XML files for remote authentication, database access, and dashboard access.
    - Credentials are securely created and stored using `Create-Credentials.ps1`, ensuring encrypted retrieval via `Import-Clixml`.
    - The PSWindowsUpdate module should be installed on target hosts if using the `-UpdateHosts psupdate` option.
    - Monitors system resource usage and flags hosts exceeding 70% CPU, RAM, or Disk usage.
    - Captures critical (Level 1) and Error (Level 2) events from the System, Setup, and Application logs.
    - Collects hardware inventory, including details such as CPU, Network Adapter, Motherboard, BIOS, OS, and GPU Information.
    - Generates reports in HTML with print preview and PDF export functionalities, and exports host data to CSV, log, and SQL formats.
    - Sends an email notification to the system administrator summarizing the daily checks, logs, update results, and hardware inventory.
    - The modules ActiveSessions.psm1, StartHosts.psm1, and StopHosts.psm1 are auxiliary modules for the main script, but they can be used
      independently by passing the corresponding parameters in each script. These scripts are self-documented.
    - Other auxiliary scripts accompany the application, which, while part of its workflow, can be used separately. They are located in
      the \`bin\` folder and include: \`Get-Events.ps1\`, \`HostsLoad.ps1\`, and \`Test-HostStatus.ps1\`. These scripts are self-documented.

    .ORGANIZATION
    Developed for: Faculty of Documentation and Communication Sciences at the University of Extremadura.

    .AUTHOR [© 2024 Alberto Ledo]
    Alberto Ledo [Faculty of Documentation and Communication Sciences] - with assistance from OpenAI
    IT Department: University of Extremadura - IT Services for Facilities
    Contact: albertoledo@unex.es

    .Copyright
    © 2024 Alberto Ledo

    .VERSION
    2.7.0

    .HISTORY
    1.0.0 - Initial release.
    1.1.0 - Added email reporting and session detection.
    1.5.0 - Introduced host load monitoring and resource usage alerts.
    
    
    
    
    
    2.6.0 - Added log message capture functionality during application initialization.
    2.5.0 - Added DNS resolution and silent mode.
    2.3.0 - Credential storage and secured access to the dashboard.

    .USAGE
    This script is strictly for internal use within University of Extremadura.
    The script is designed to operate within the IT infrastructure and environment of University of Extremadura
    and may not function as expected in other environments.

    .DATE
    November 13, 2024

    .DISCLAIMER
    This script is provided "as-is" and is intended for internal use at University of Extremadura.
    No warranties, express or implied, are provided. Any modifications or adaptations are not covered
    under this disclaimer.

    .LINK
    https://github.com/n7rc/OpsHostGuard
#>

param (
    [string]$HostName = $null, # Single host name
    [string]$GroupName = $null, # Host group parameter
    [array]$HostsList = @(), # List of hosts
    [bool]$UpdateHosts = $false, # Trigger update mode
    [bool]$UsePsUpdate = $false, # Use PSWindowsUpdate if true
    [bool]$ForceUpdate = $false, # Force updates
    [int]$UpdateHistoryDays = $null, # Number of days to look back for updates
    [bool]$Inventory = $false, # Enable hardware inventory collection
    [bool]$UseDNS = $false, # Enable DNS-based host lookups
    [bool]$Verbose = $false, # Enable debug mode
    [bool]$Silent = $false, # Enable silent mode
    [switch]$Help # Display help
)

# Capture user parameters into a hash table for future reference
$ParameterHash = @{
    HostName          = $HostName
    GroupName         = $GroupName
    HostsList         = $HostsList
    UpdateHosts       = $UpdateHosts
    UsePsUpdate       = $UsePsUpdate
    ForceUpdate       = $ForceUpdate
    UpdateHistoryDays = $UpdateHistoryDays
    Inventory         = $Inventory
    UseDNS            = $UseDNS
    Debug             = $Verbose
    Silent            = $Silent
}

# Determine the script's base path
$basePathRoot = $null
if ($null -ne $PSScriptRoot -and $PSScriptRoot -ne "") {
    # Use $PSScriptRoot if available
    $basePathRoot = (Resolve-Path -Path (Join-Path -Path $PSScriptRoot -ChildPath "..")).Path
}
elseif ($null -ne $MyInvocation.MyCommand.Path -and $MyInvocation.MyCommand.Path -ne "") {
    # Fallback to $MyInvocation.MyCommand.Path
    $basePathRoot = (Resolve-Path -Path (Join-Path -Path (Split-Path -Path $MyInvocation.MyCommand.Path -Parent) -ChildPath "..")).Path
}
else {
    throw "[Error] Unable to determine the base path. Ensure this script is being run from a script file."
}

# Validate the base path
if (-not $basePathRoot -or $basePathRoot -eq "") {
    throw "[Error] The base path ($basePathRoot) is empty or undefined. Check the script execution context."
}

# Function to display help information
function Show-Help-OpsBasicScan {
    param (
        [string]$functionName = "OpsBasicScan"
    )

    Write-Host "`nOpsBasicScan USAGE:`n" -ForegroundColor Yellow
    Write-Host "    $functionName [[-GroupName <String>] | [-HostName <String>] | [-listHosts <array>]] | [-UpdateHosts:[1|0]] [-UsePsUpdate:[1|0]]  [-ForceUpdate:[1|0]] | [-Inventory:[1|0]] | [config] [-UseDNS:[1|0]] [-Verbose:[1|0]] [-Silent:[1|0]]" -ForegroundColor White

    Write-Host "`nDESCRIPTION:`n" -ForegroundColor Yellow
    Write-Host "    The $functionName script automates key administrative tasks for a group of Windows hosts, including power-on, monitoring, updating, and reporting. This script can be run standalone or integrated within OpsHostGuard." -ForegroundColor White
    Write-Host "
    -GroupName [Optional]
        Name of the host group to manage." -ForegroundColor White
    Write-Host "
    -HostName [Optional]
        Name of a specific host belonging to a group to manage." -ForegroundColor White
    Write-Host "
    -HostsList [Optional]
        Arbitrary host list to manage. Format: host1, host2, host3, ..." -ForegroundColor White
    Write-Host "`nPARAMETERS:" -ForegroundColor Yellow
    Write-Host "
    -UpdateHosts:1 [Optional]
        Specifies the update host." -ForegroundColor White
    Write-Host "
    -UsePsUpdate:1 [Optional]
        Uses the PSWindowsUpdate module for updates." -ForegroundColor White
    Write-Host "
    -ForceUpdate:1 [Optional]
        Forces Windows updates even if active sessions are present." -ForegroundColor White
    Write-Host "
    -Inventory:1 [Optional]
        Enables Inventory Mode to perform a comprehensive hardware inventory check for each host. Ideal for tracking hardware changes over time." -ForegroundColor White
    Write-Host "
    -UseDNS:1 [Optional]
        Boolean to enable DNS resolution for host checks. Useful for dynamic networks. Default: false." -ForegroundColor White
    Write-Host "
    -Verbose:1 [Optional]
        Boolean to enable Debug Mode, which provides detailed logging for troubleshooting. Default: false." -ForegroundColor White
    Write-Host "
    -Silent:1 [Optional]
        Boolean to enable Silent Mode, suppressing non-critical output messages. Default: false." -ForegroundColor White

    Write-Host "`nEXAMPLES:`n" -ForegroundColor Yellow
    Write-Host "    $functionName -GroupName 'all' -UpdateHosts:1 -UsePsUpdate:1 -Inventory:1" -ForegroundColor White
    Write-Host "        Manages all hosts in the 'all' group, applies updates using PSWindowsUpdate, and performs a hardware inventory check.`n" -ForegroundColor White
    Write-Host "    $functionName -GroupName 'labs' -Verbose" -ForegroundColor White
    Write-Host "        Executes the script for the 'labs' group with Debug mode enabled for detailed troubleshooting logs.`n" -ForegroundColor White
}

# Display help and exit if the -Help switch is provided
if ($Help -or ((!$GroupName) -and (!$HostName) -and (!$HostsList))) {
    Show-Help-OpsBasicScan -CommandName "OpsBasicScan"
    return
}

# Unified validation: Ensure at least one of groupName, hostName, or hostsList is provided
if (-not $GroupName -and -not $HostName -and (-not $HostsList -or $HostsList.Count -eq 0)) {
    Write-Host "Error: You must specify either a group name (-GroupName), a host name (-HostName), or a list of hosts (-HostsList)."
    Show-Help-OpsBasicScan -CommandName "OpsBasicScan"
    return
}

# Global configurations initialization
$Global:OpsHostGuardCalling = $true
$Global:SilentMode = $Silent
$Script:ScriptName = "OpsBasicScan"


# Timestamp format for logging
$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

# Temporary storage for log messages
$Global:tempLogMessages = @()

try {
    # Load OpsInit module for configuration management
    if (Get-Module -Name LoadManager) {
        Remove-Module -Name LoadManager -Force -ErrorAction SilentlyContinue | Out-Null
    }
    if (Get-Module -Name OpsInit) {
        Remove-Module -Name OpsInit -Force -ErrorAction SilentlyContinue | Out-Null
    }

    # Load OpsInit.psd1
    $loadOpsInit = Join-Path -Path $basePathRoot -ChildPath "modules/core/system/OpsInit.psd1"
    Import-Module -Name $loadOpsInit -Scope Global -Force

    # Validate OpsInit module
    if (Get-Module -Name OpsInit -ErrorAction SilentlyContinue) {
        try {
            # Initialize configuration with user parameters
            Initialize-Configuration -UserParameters $ParameterHash
        }
        catch {
            # Log and rethrow exceptions
            Write-Host $_.Exception.Message
            $tempLogMessages += $_.Exception.Message
            throw "Initialization halted due to unexpected error during path or file creation."
        }
    }
    else {
        Write-Host "[Error] OpsInit module not found. Ensure OpsInit.psm1 is correctly loaded." -ForegroundColor Red
        $tempLogMessages += "[$timestamp] [Error] [Main] OpsInit module not found. Ensure OpsInit.psm1 is correctly loaded."
        throw "OpsInit.psm1 could not be loaded properly. Exiting script."
    }
}
Catch {
    Write-Host "[Error] Failed to load necessary modules: $($_.Exception.Message)" -ForegroundColor Red
    $tempLogMessages += "[$timestamp] [Error] [Main] Failed to load necessary modules: $($_.Exception.Message)"
    throw "Critical error: Unable to load configuration or utilities module."
}

# Log successful initialization and base path definition
Add-LogMessage -logLevel "" -functionName $MyInvocation.InvocationName `
    -message "Returning the definition of root directory: $($Global:Config.Paths.Root)" -ForegroundColor White
Add-LogMessage -logLevel "" -functionName $MyInvocation.InvocationName `
    -message "OpsHostGuard fully initialized." -ForegroundColor White

if ($GroupName) {
    # Validate the provided group
    if (-not (Test-HostsGroups -GroupName $GroupName)) {
        throw "Error: Group '$GroupName' does not exist or is invalid."
    }
}

# Abstraction for a single host or a list of hosts
if (-not $GroupName) {
    if ($HostName) {
        #$GroupName = "temporaryGroup"
        New-TemporaryGroup -GroupName temporaryGroup -HostsList @($HostName)
        New-TemporaryGroupMac -GroupName temporaryGroupMac -HostsList @($HostName)
    }
    elseif ($HostsList.Count -gt 0) {
        #$GroupName = "temporaryGroup"
        New-TemporaryGroup -GroupName temporaryGroup -HostsList $HostsList
        New-TemporaryGroupMac -GroupName temporaryGroupMac -HostsList $HostsList
    }
}

# Check and create the ./dashboard/data/csv directory if it does not exist
if (-not (Test-Path -Path $Global:Config.Paths.Data.Csv)) {
    New-Item -ItemType Directory -Path $Global:Config.Paths.Data.Csv -Force | Out-Null
    Add-LogMessage -message "Directory created: $($Global:Config.Paths.Data.Csv)" -functionName "Setup" -logLevel "Info"
}
else {
    Add-LogMessage -message "Directory already exists: $($Global:Config.Paths.Data.Csv)" -functionName "Setup" -logLevel "Info"
}

# Check and create the ./dashboard/data/log directory if it does not exist
if (-not (Test-Path -Path $Global:Config.Paths.Data.Log)) {
    New-Item -ItemType Directory -Path $Global:Config.Paths.Data.Log -Force | Out-Null
    Add-LogMessage -message "Directory created: $($Global:Config.Paths.Data.Log)" -functionName "Setup" -logLevel "Info"
}
else {
    Add-LogMessage -message "Directory already exists: $($Global:Config.Paths.Data.Log)" -functionName "Setup" -logLevel "Info"
}

# Inicialización del hash combinando valores proporcionados y predeterminados
$ParameterHash = @{
    HostName          = $HostName #if ($HostName -ne $null) { $HostName } else { $Global:DefaultParameters.HostName.Default }
    GroupName         = $GroupName #if ($GroupName -ne $null) { $GroupName } else { $Global:DefaultParameters.GroupName.Default }
    HostsList         = $HostsList #if ($HostsList.Count -gt 0) { $HostsList } else { $Global:DefaultParameters.HostsList.Default }
    UpdateHosts       = if ($UpdateHosts -ne $null) { $UpdateHosts } else { $Global:DefaultParameters.UpdateHosts.Default }
    UsePsUpdate       = if ($UsePsUpdate -ne $null) { $UsePsUpdate } else { $Global:DefaultParameters.UsePsUpdate.Default }
    ForceUpdate       = if ($ForceUpdate -ne $null) { $ForceUpdate } else { $Global:DefaultParameters.ForceUpdate.Default }
    UpdateHistoryDays = if ($UpdateHistoryDays -ne $null) { $UpdateHistoryDays } else { $Global:DefaultParameters.UpdateHistoryDays.Default }
    Inventory         = if ($Inventory -ne $null) { $Inventory } else { $Global:DefaultParameters.Inventory.Default }
    UseDNS            = if ($UseDNS -ne $null) { $UseDNS } else { $Global:DefaultParameters.UseDNS.Default }
    Verbose           = if ($Verbose -ne $null) { $Verbose } else { $Global:DefaultParameters.Verbose.Default }
    Silent            = if ($Silent -ne $null) { $Silent } else { $Global:DefaultParameters.Silent.Default }
}

# Define file paths for the output reports and logs
$csvFile = $Global:Config.InternalConfig.Files.DataCsvFile
$logFile = $Global:Config.InternalConfig.Files.DataLogFile
$htmlReportPath = "./dashboard/views/reports/standar_report.php"
$htmlReportHardware = "./dashboard/views/reports/hardware_inventory_report.php"

Add-LogMessage -logLevel "" -functionName $MyInvocation.InvocationName `
    -message "Setting CSV report output path to: $csvFile"
Add-LogMessage -logLevel "" -functionName $MyInvocation.InvocationName `
    -message "Setting Log report output path to: $logFile"
Add-LogMessage -logLevel "" -functionName $MyInvocation.InvocationName `
    -message "Setting HTML report output path to: $htmlReportPath"
Add-LogMessage -logLevel "" -functionName $MyInvocation.InvocationName `
    -message "Setting Hardware inventory report output path to: $htmlReportHardware"

    # Function to check CPU, memory, and disk usage of hosts (threshold set to 70%)
function Get-HostLoad {
    param (
        [array]$hostsToCheck, # Hosts to check for load metrics
        [int]$TimeoutSeconds = 5       # Timeout for connection attempts
    )

    $results = @()       # Array to store hosts exceeding the threshold
    $failedHosts = @()   # Array to store hosts that failed to respond

    foreach ($currentHost in $hostsToCheck) {
        Add-LogMessage -logLevel "" -functionName $MyInvocation.InvocationName -message "Checking host $currentHost for CPU, memory, and disk usage..."

        if (-not (Test-Connection -ComputerName $currentHost -Count 1 -Quiet)) {
            Add-LogMessage -logLevel "" -functionName $MyInvocation.InvocationName -message "Host $currentHost is unreachable."
            Write-Warning "Host $currentHost is unreachable."
            $failedHosts += $currentHost
            continue
        }

        try {
            Add-LogMessage -logLevel "" -functionName $MyInvocation.InvocationName -message "Retrieving metrics for host $currentHost..."
            $result = Invoke-Command -ComputerName $currentHost -Credential $Global:PsRemotingCredential -ScriptBlock {
                $cpu = Get-WmiObject win32_processor | Measure-Object -Property LoadPercentage -Average | Select-Object -ExpandProperty Average
                $ram = Get-WmiObject Win32_OperatingSystem | Select-Object @{Name = "RAM"; Expression = { [math]::round(($_.TotalVisibleMemorySize - $_.FreePhysicalMemory) / 1048576, 2) } }
                $ramTotal = Get-WmiObject Win32_OperatingSystem | Select-Object @{Name = "RAMTotal"; Expression = { [math]::round($_.TotalVisibleMemorySize / 1MB, 2) } }
                $disks = Get-WmiObject Win32_LogicalDisk -Filter "DriveType = 3" | ForEach-Object {
                    $diskUsage = [math]::Round((($_.Size - $_.FreeSpace) / $_.Size) * 100, 2)
                    [pscustomobject]@{
                        Drive = $_.DeviceID
                        Usage = $diskUsage
                    }
                }

                return @{CPU = $cpu; RAM = [math]::Round(($ram.RAM / $ramTotal.RAMTotal) * 100, 2); Disks = $disks }
            }

            Add-LogMessage -logLevel "" -functionName $MyInvocation.InvocationName -message "Metrics Successfully retrieved for host $currentHost."

            # Check if CPU, RAM, or any disk exceeds 70%
            $exceedsThreshold = $false
            if ($result.CPU -gt 70) {
                Add-LogMessage -logLevel "" -functionName $MyInvocation.InvocationName -message "CPU usage for $currentHost exceeds 70% ($($result.CPU) % )"
                $exceedsThreshold = $true
            }
            if ($result.RAM -gt 70) {
                Add-LogMessage -logLevel "" -functionName $MyInvocation.InvocationName -message "RAM usage for $currentHost exceeds 70% ($($result.RAM) % )"
                $exceedsThreshold = $true
            }
            $result.Disks | ForEach-Object {
                if ($_.Usage -gt 70) {
                    Add-LogMessage -logLevel "" -functionName $MyInvocation.InvocationName -message "Disk usage for drive $($_.Drive) on $currentHost exceeds 70% ($($_.Usage) % )"
                    $exceedsThreshold = $true # Ignore unused variable Warning
                }
            }
            # If any metric exceeds the threshold, include the host in the results
            if ($exceedsThreshold) {
                $diskColumns = @{ }
                $diskCount = 1
                $result.Disks | ForEach-Object {
                    $diskColumns["Disk${diskCount}"] = "$($_.Usage) %"
                    $diskCount++
                }
            
                $finalResult = [pscustomobject]@{
                    HostName = $currentHost
                    CPU      = $result.CPU
                    RAM      = $result.RAM
                    DateTime = (Get-Date).ToString("dd-MM-yyyy HH:mm:ss")
                }
            
                # Add disk columns to the final result
                $diskColumns.GetEnumerator() | ForEach-Object {
                    $finalResult | Add-Member -MemberType NoteProperty -Name $_.Key -Value $_.Value
                }
            
                $results += $finalResult
                Add-LogMessage -logLevel "" -functionName $MyInvocation.InvocationName -message "Host $currentHost added to results: CPU=$($result.CPU)%, RAM=$($result.RAM)%, Disks=$($diskColumns | Out-String)"
            }
            
        }
        catch {
            Add-LogMessage -logLevel "" -functionName $MyInvocation.InvocationName -message "Failed to retrieve metrics for host $currentHost. Error: $_"
            Write-Warning "Could not retrieve metrics for host $currentHost. Error: $_"
            $failedHosts += $currentHost
        }
    }
          
    Add-LogMessage -logLevel "" -functionName $MyInvocation.InvocationName -message "Host load retrieval completed. Successfully processed $($results.Count) hosts that exceed the 70% threshold. Failed hosts: $($failedHosts.Count)."
            
    return @($results, $failedHosts)
}
           
# Function to capture critical logs (Level 1) from System and Setup logs
function Get-CriticalLogsForHost {
    param ([string]$remoteHostName )
            
    $logs = @('System', 'Setup')  # Logs to check
    $dateLimit = (Get-Date).AddDays(-7)  # Only capture logs from the last 7 days
    $criticalEvents = @()
            
    foreach ($logType in $logs) {
        # Capture only Critical (Level 1) events
        $events = Invoke-Command -ComputerName $remoteHostName -Credential $Global:PsRemotingCredential -ScriptBlock {
            Get-WinEvent -FilterHashtable @{LogName = $logType; Level = 1; StartTime = $dateLimit }
        }
        $events | ForEach-Object {
            $criticalEvents += [PSCustomObject]@{
                TimeCreated = $_.TimeCreated
                Id          = $_.Id
                Level       = "Critical"
                LogType     = $logType
                Message     = $_.Message
            }
        }
    }
            
    return $criticalEvents
}
# Function to capture Error logs (Level 2) from Application log for a specific host
function Get-ApplicationErrorLogsForHost {
    param ([string]$remoteHostName)

    $logType = 'Application'  # Log to check
    $level = 2  # Error level
    $dateLimit = (Get-Date).AddDays(-7)  # Capture events from the last 7 days
    $applicationErrors = @()

    # Capture Error (Level 2) events from the Application log
    $events = Invoke-Command -ComputerName $remoteHostName -Credential $Global:PsRemotingCredential -ScriptBlock {
        Get-WinEvent -FilterHashtable @{LogName = $logType; Level = $level; StartTime = $dateLimit }
    }
    $events | ForEach-Object {
        $applicationErrors += [PSCustomObject]@{
            TimeCreated = $_.TimeCreated
            Id          = $_.Id
            Level       = "Error"
            LogType     = $logType
            Message     = $_.Message
        }
    }

    return $applicationErrors
}

# Function to retrieve hardware inventory for a specific host
function Get-HardwareInventory {
    param (
        [string]$HostName,
        [pscredential]$credential = $null
    )

    $hardwareInfo = @{}

    try {
        # Collect processor Information
        $cpuInfo = Invoke-Command -ComputerName $HostName -Credential $credential -ScriptBlock {
            Get-CimInstance Win32_Processor | Select-Object -Property Name, NumberOfCores, MaxClockSpeed
        }

        # Collect RAM Information
        $ramInfo = Invoke-Command -ComputerName $HostName -Credential $credential -ScriptBlock {
            Get-CimInstance Win32_PhysicalMemory | Select-Object -Property Capacity, Speed
        }

        # Collect disk Information
        $diskInfo = Invoke-Command -ComputerName $HostName -Credential $credential -ScriptBlock {
            Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3" | Select-Object -Property DeviceID, Size, FreeSpace
        }

        # Collect network adapter Information
        $networkInfo = Invoke-Command -ComputerName $HostName -Credential $credential -ScriptBlock {
            Get-CimInstance Win32_NetworkAdapter | Where-Object { $_.NetEnabled -eq $true } | Select-Object -Property Name, MACAddress, Speed
        }

        # Collect motherboard Information
        $motherboardInfo = Invoke-Command -ComputerName $HostName -Credential $credential -ScriptBlock {
            Get-CimInstance Win32_BaseBoard | Select-Object -Property Manufacturer, Product, SerialNumber
        }

        # Collect BIOS Information
        $biosInfo = Invoke-Command -ComputerName $HostName -Credential $credential -ScriptBlock {
            Get-CimInstance Win32_BIOS | Select-Object -Property SMBIOSBIOSVersion, ReleaseDate
        }

        # Collect operating system Information
        $osInfo = Invoke-Command -ComputerName $HostName -Credential $credential -ScriptBlock {
            Get-CimInstance Win32_OperatingSystem | Select-Object -Property Caption, BuildNumber
        }

        # Collect GPU (Graphics Card) Information
        $gpuInfo = Invoke-Command -ComputerName $HostName -Credential $credential -ScriptBlock {
            Get-CimInstance Win32_VideoController | Select-Object -Property Name, DriverVersion
        }

        # Store the collected Information in the hash table
        $hardwareInfo = @{
            CPUInfo         = $cpuInfo
            RAMInfo         = $ramInfo
            DiskInfo        = $diskInfo
            NetworkInfo     = $networkInfo
            MotherboardInfo = $motherboardInfo
            BIOSInfo        = $biosInfo
            OSInfo          = $osInfo
            GPUInfo         = $gpuInfo
        }
    }
    catch {
        if (-not $Silent) {
            Add-LogMessage -logLevel "" -functionName $MyInvocation.InvocationName -message "Error retrieving hardware inventory from host: $HostName" -ForegroundColor Red 
        }
    }
    return $hardwareInfo
}

# Log the start of script execution
Add-LogMessage -logLevel "Info" -functionName $MyInvocation.InvocationName `
    -message "Script execution started. Debug mode: $Verbose, Silent mode: $Silent"

# Invoke the StartHosts.psm1 module to power on the hosts and capture the result
try {
    Add-LogMessage -logLevel "Info" -functionName $MyInvocation.InvocationName `
        -message "Attempting to power on hosts for group '$GroupName' or provided hosts list."

    <#
    #$powerOnResult = Invoke-PowerOnHosts -GroupName $GroupName `
    $powerOnResult = Start-Hosts -GroupName $GroupName -HostName $HostName `
        -UseDNS:$ParameterHash.UseDNS `
        -Verbose:$ParameterHash.Verbose `
        -Silent:$ParameterHash.Silent
    #>

    # Determinar el valor de groupName basado en las condiciones
    $effectiveGroupName = $null
    if ($GroupName) {
        $effectiveGroupName = $GroupName
    }
    elseif ($HostsList.Count -gt 0 -or $HostName) {
        $effectiveGroupName = "temporaryGroupMac"
    }

    # Llamar a Start-Hosts con el groupName efectivo
    $powerOnResult = Start-Hosts -GroupName $effectiveGroupName -HostName $ParameterHash.HostName `
        -UseDNS:$ParameterHash.UseDNS `
        -Verbose:$ParameterHash.Verbose `
        -Silent:$ParameterHash.Silent

    # Validate the power-on results
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"  # Capture the timestamp of execution
    $powerOnResults = Resolve-PowerOn -powerOnResult $powerOnResult -timestamp $timestamp

    $failedHosts = $powerOnResults[0]  # Hosts that failed to power on
    $successfulHosts = $powerOnResults[1]  # Hosts that powered on successfully

    # Log the results of the power-on attempt
    if ($successfulHosts.Count -gt 0) {
        Add-LogMessage -logLevel "Success" -functionName $MyInvocation.InvocationName `
            -message "Successfully powered on $($successfulHosts.Count) host(s): $($successfulHosts -join ', ')"
    }

    if ($failedHosts.Count -gt 0) {
        Add-LogMessage -logLevel "Warning" -functionName $MyInvocation.InvocationName `
            -message "Failed to power on $($failedHosts.Count) host(s): $($failedHosts -join ', ')"
    }

    # Generate reports for failed power-on attempts
    if ($failedHosts.Count -gt 0) {
        New-CSVReport -failedHosts $failedHosts -csvFile $csvFile
        New-LogReport -failedHosts $failedHosts -logFile $logFile
        Add-LogMessage -logLevel "Info" -functionName $MyInvocation.InvocationName `
            -message "Generated reports for failed power-on attempts."
    }
}
catch {
    Add-LogMessage -logLevel "Error" -functionName $MyInvocation.InvocationName `
        -message "Error occurred during power-on process: $($_.Exception.Message)"
    throw "Power-on process halted due to an unexpected error."
}

# Log the end of the power-on process
Add-LogMessage -logLevel "Info" -functionName $MyInvocation.InvocationName `
    -message "Completed the power-on process. Proceeding with session validation."

# Retrieve the list of hosts with active sessions
try {
    if ($successfulHosts.Count -gt 0) {
        Add-LogMessage -logLevel "Info" -functionName $MyInvocation.InvocationName `
            -message "Checking active sessions for successfully powered-on hosts."
        
        <#
        $effectiveGroupName = $null
        if ($GroupName) {
            $effectiveGroupName = $GroupName
        }
        elseif ($HostsList.Count -gt 0 -or $HostName) {
            $effectiveGroupName = "temporaryGroup"
        }
        #>
        <#
        $activeSessionsResult = Invoke-ActiveSession -GroupName  $effectiveGroupName `
            -successfulHosts $successfulHosts `
            -export `
            -Verbose:$ParameterHash.Verbose `
            -Silent:$ParameterHash.Silent
        #>
        Invoke-ActiveSession -GroupName $GroupName -HostName $HostName -HostsList $HostsList `
            -successfulHosts $successfulHosts `
            -export `
            -Verbose:$ParameterHash.Verbose `
            -Silent:$ParameterHash.Silent


        # Retrieve the list of hosts with active sessions by reading the active_sessions.cache file
        $hostsInSession = Get-HostsInSession

        if ($hostsInSession.Count -gt 0) {
            Add-LogMessage -logLevel "Warning" -functionName $MyInvocation.InvocationName `
                -message "Active sessions detected on $($hostsInSession.Count) host(s): $($hostsInSession.Host -join ', ')"
        }
        else {
            Add-LogMessage -logLevel "Success" -functionName $MyInvocation.InvocationName `
                -message "No active sessions detected on successfully powered-on hosts."
        }
    }
    else {
        Add-LogMessage -logLevel "Warning" -functionName $MyInvocation.InvocationName `
            -message "No successfully powered-on hosts available for session validation."
    }
}
catch {
    Add-LogMessage -logLevel "Error" -functionName $MyInvocation.InvocationName `
        -message "Error occurred during session validation: $($_.Exception.Message)"
    throw "Session validation process halted due to an unexpected error."
}

# Initialize $resultUpdate as null to avoid errors if updates are not applied
$resultUpdate = $null

# Initialize PsRemotingCredential
Initialize-GlobalPsRemotingCredential

# Apply updates to the hosts if the -UpdateHosts parameter is provided
try {
    if ($UpdateHosts -eq $true) {
        Add-LogMessage -logLevel "Info" -functionName $MyInvocation.InvocationName `
            -message "Initiating update process for successfully powered-on hosts."

        # Ensure there are valid hosts to update
        if ($successfulHosts.Count -gt 0) {
            $effectiveGroupName = $null
            if ($GroupName) {
                $effectiveGroupName = $GroupName
            }
            elseif ($HostsList -or $HostName) {
                $effectiveGroupName = "temporaryGroup"
            }
            $resultUpdate = Update-UHWindows -GroupName $effectiveGroupName `
                -successfulHosts $successfulHosts `
                -UsePsUpdate:$ParameterHash.UsePsUpdate `
                -ForceUpdate:$ParameterHash.ForceUpdate `
                -UpdateHistoryDays $ParameterHash.UpdateHistoryDays `
                -PsRemotingCredential $Global:PsRemotingCredential `
                -Silent:$ParameterHash.Silent

            Add-LogMessage -logLevel "Info" -functionName $MyInvocation.InvocationName `
                -message "Update process completed for group '$GroupName'."
        }
        else {
            Add-LogMessage -logLevel "Warning" -functionName $MyInvocation.InvocationName `
                -message "No valid hosts available for updates in group '$GroupName'."
        }
    }
    else {
        Add-LogMessage -logLevel "Info" -functionName $MyInvocation.InvocationName `
            -message "Update process skipped. Run the script with -UpdateHosts to apply updates."
    }
}
catch {
    Add-LogMessage -logLevel "Error" -functionName $MyInvocation.InvocationName `
        -message "Error occurred during the update process: $($_.Exception.Message)"
    throw "Update process halted due to an unexpected error."
}

# Log the update results if updates were applied
if ($resultUpdate) {
    try {
        Add-LogMessage -logLevel "Info" -functionName $MyInvocation.InvocationName `
            -message "Logging update results."

        # Log update entries
        $resultUpdate.UpdateLogEntries | ForEach-Object {
            $logMessage = "[Update] Host: $($_.HostName), Update: $($_.Update), Status: $($_.Status), Timestamp: $($_.Timestamp)"
            Add-LogMessage -logLevel "Info" -message $logMessage
        }

        # Log verification entries
        $resultUpdate.VerificationUpdateEntries | ForEach-Object {
            $logMessage = "[Verification] Host: $($_.HostName), Status: $($_.Status), Result: $($_.Result), Timestamp: $($_.Timestamp)"
            Add-LogMessage -logLevel "Info" -message $logMessage
        }
    }
    catch {
        Add-LogMessage -logLevel "Error" -functionName $MyInvocation.InvocationName `
            -message "Error occurred while logging update results: $($_.Exception.Message)"
    }
}
else {
    Add-LogMessage -logLevel "Warning" -functionName $MyInvocation.InvocationName `
        -message "No updates applied; no log entries available."
}

# Retrieve the system load metrics (CPU, RAM, Disk) for the successfully powered-on hosts
try {
    $hostLoadResults = Get-HostLoad -hostsToCheck $successfulHosts
    $loadMetrics = $hostLoadResults[0]  # Successfully retrieved load metrics
    $failedLoadHosts = $hostLoadResults[1]  # Hosts that failed to report load metrics

    # Log system load metrics
    if ($loadMetrics.Count -gt 0) {
        Add-LogMessage -logLevel "Info" -functionName $MyInvocation.InvocationName `
            -message "System load metrics retrieved for $($loadMetrics.Count) hosts."
    }
    else {
        Add-LogMessage -logLevel "Warning" -functionName $MyInvocation.InvocationName `
            -message "No system load metrics retrieved. Check connectivity to the hosts."
    }

    # Log hosts that failed to report metrics
    if ($failedLoadHosts.Count -gt 0) {
        Add-LogMessage -logLevel "Warning" -functionName $MyInvocation.InvocationName `
            -message "Some hosts failed to report load metrics: $($failedLoadHosts -join ', ')."
    }
}
catch {
    Add-LogMessage -logLevel "Error" -functionName $MyInvocation.InvocationName `
        -message "Error occurred while retrieving host load metrics: $($_.Exception.Message)"
    throw "Metrics retrieval process halted due to an unexpected error."
}



# Shutdown the successfully powered-on hosts and log any shutdown failures or hosts with active sessions
try {
    $effectiveGroupName = $null
    if ($GroupName) {
        $effectiveGroupName = $GroupName
    }
    elseif ($HostsList -or $HostName) {
        $effectiveGroupName = "temporaryGroup"
    }

    #$shutdownResults = Stop-MGHosts -allHosts $allHosts -successfulHosts $successfulHosts -GroupName $effectiveGroupName -Verbose:$Verbose -Silent:$Silent
    
    $shutdownResults = Stop-MGHosts -GroupName $effectiveGroupName -successfulHosts $successfulHosts -Verbose:$Verbose -Silent:$Silent

    $failedShutdowns = $shutdownResults[0]  # Hosts that failed to shut down
    $hostsInSession = $shutdownResults[1]  # Hosts with active sessions

    # Log shutdown failures
    if ($failedShutdowns.Count -gt 0) {
        Add-LogMessage -logLevel "Warning" -functionName $MyInvocation.InvocationName `
            -message "Some hosts failed to shut down. Generating reports."

        # Generate reports for shutdown failures
        New-CSVReport -failedHosts $failedShutdowns -csvFile $csvFile
        New-LogReport -failedHosts $failedShutdowns -logFile $logFile
    }
    else {
        Add-LogMessage -logLevel "Info" -functionName $MyInvocation.InvocationName `
            -message "All hosts shut down successfully."
    }

    # Log active sessions

    if ($hostsInSession.Count -gt 0) {
        Add-LogMessage -logLevel "Warning" -functionName $MyInvocation.InvocationName `
            -message "Active sessions detected on some hosts. Logging entries."

        # Create log entries for hosts with active sessions
        $hostsInSession | ForEach-Object {
            $logEntry = [PSCustomObject]@{
                HostName  = $_.Host
                Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                Status    = "Host in Session"
            }

            # Append log entry to both CSV and log files
            New-CSVReport -failedHosts @($logEntry) -csvFile $csvFile
            New-LogReport -failedHosts @($logEntry) -logFile $logFile
        }
    }
}
catch {
    Add-LogMessage -logLevel "Error" -functionName $MyInvocation.InvocationName `
        -message "Error occurred during shutdown process: $($_.Exception.Message)"
    throw "Shutdown process halted due to an unexpected error."
}

# Initialize an array to store critical log entries for all hosts
$allCriticalLogs = @()

try {
    # Loop through each host and collect critical logs from System and Setup logs
    foreach ($currentHost in $successfulHosts) {

        if (Test-Connection -ComputerName $currentHost -Count 1 -Quiet) {
            Add-LogMessage -logLevel "Info" -functionName $MyInvocation.InvocationName `
                -message "Collecting critical logs for host: $currentHost."

            $criticalLogs = Get-CriticalLogsForHost -remoteHostName $currentHost
            $allCriticalLogs += $criticalLogs
        }
        else {
            Add-LogMessage -logLevel "Warning" -functionName $MyInvocation.InvocationName `
                -message "Host $currentHost is unreachable. Skipping critical log collection."
        }
    }

    Add-LogMessage -logLevel "Info" -functionName $MyInvocation.InvocationName `
        -message "Critical logs collection completed. Total logs retrieved: $($allCriticalLogs.Count)."
}
catch {
    Add-LogMessage -logLevel "Error" -functionName $MyInvocation.InvocationName `
        -message "Error occurred during critical logs retrieval: $($_.Exception.Message)"
    throw "Critical logs retrieval process halted due to an unexpected error."
}

# Initialize an array to store all Application Error logs (Level 2)
$allApplicationErrorLogs = @()

try {
    # Loop through each host and collect Application Error logs (Level 2)
    foreach ($currentHost in $successfulHosts) {

        if (Test-Connection -ComputerName $currentHost -Count 1 -Quiet) {
            Add-LogMessage -logLevel "Info" -functionName $MyInvocation.InvocationName `
                -message "Collecting application error logs for host: $currentHost."

            $applicationErrorLogs = Get-ApplicationErrorLogsForHost -remoteHostName $currentHost
            $allApplicationErrorLogs += $applicationErrorLogs
        }
        else {
            Add-LogMessage -logLevel "Warning" -functionName $MyInvocation.InvocationName `
                -message "Host $currentHost is unreachable. Skipping application error log collection."
        }
    }

    Add-LogMessage -logLevel "Info" -functionName $MyInvocation.InvocationName `
        -message "Application error logs collection completed. Total logs retrieved: $($allApplicationErrorLogs.Count)."
}
catch {
    Add-LogMessage -logLevel "Error" -functionName $MyInvocation.InvocationName `
        -message "Error occurred during application error logs retrieval: $($_.Exception.Message)"
    throw "Application error logs retrieval process halted due to an unexpected error."
}

# Initialize an array to store hardware inventory data for all hosts
$allHardwareInventory = @()

if ($Inventory) {
    try {
        Add-LogMessage -logLevel "Info" -functionName $MyInvocation.InvocationName `
            -message "Starting hardware inventory collection for successfully powered-on hosts."

        # Retrieve hardware inventory for each successfully powered-on host
        foreach ($currentHost in $successfulHosts) {
            Add-LogMessage -logLevel "Info" -functionName $MyInvocation.InvocationName `
                -message "Retrieving hardware inventory for host: $currentHost."

            $hardwareInventory = Get-HardwareInventory -HostName $currentHost -credential $Global:PsRemotingCredential
            $allHardwareInventory += $hardwareInventory
        }

        Add-LogMessage -logLevel "Info" -functionName $MyInvocation.InvocationName `
            -message "Hardware inventory collection completed. Total entries retrieved: $($allHardwareInventory.Count)."
    }
    catch {
        Add-LogMessage -logLevel "Error" -functionName $MyInvocation.InvocationName `
            -message "Error occurred during hardware inventory retrieval: $($_.Exception.Message)"
        throw "Hardware inventory retrieval process halted due to an unexpected error."
    }
}

# Function to generate a table with host load metrics for the email body
function New-HostLoadTable {
    param (
        [array]$results  # Array of load metrics
    )

    # Create table headers for the metrics
    $table = "Host".PadRight(20) + "| CPU ( % )".PadRight(10) + " | RAM ( % )".PadRight(10) + " | Disk1 ( % )".PadRight(11) + " | Disk2 ( % )".PadRight(11) + " | Disk3 ( % )".PadRight(10) + "`n"
    $table += ("-" * 74) + "`n"

    # Add each host's load metrics to the table
    foreach ($result in $results) {
        $disk2 = if ($result.Disk2) { $result.Disk2 } else { "N/A" }
        $disk3 = if ($result.Disk3) { $result.Disk3 } else { "N/A" }
        $table += $result.HostName.PadRight(20) + "| " + $result.CPU.ToString().PadRight(8) + " | " + $result.RAM.ToString().PadRight(8) + " | " + $result.Disk1.PadRight(9) + " | " + $disk2.PadRight(9) + " | " + $disk3.PadRight(10) + "`n"
    }

    return $table  # Return the generated table as a string
}

# Function to generate a table of critical logs for the email body
function New-CriticalLogTable {
    param ([array]$criticalLogs)  # Array of critical logs

    # Create table headers for the critical logs
    $table = "TimeCreated".PadRight(20) + "| EventID".PadRight(8) + " | LogType".PadRight(10) + " | Message".PadRight(50) + "`n"
    $table += ("-" * 90) + "`n"

    # Add each critical log entry to the table
    foreach ($log in $criticalLogs) {
        $timeCreated = $log.TimeCreated.ToString("yyyy-MM-dd HH:mm:ss")
        $table += $timeCreated.PadRight(20) + "| " + $log.Id.ToString().PadRight(8) + " | " + $log.LogType.PadRight(10) + " | " + $log.Message.Substring(0, [Math]::Min(50, $log.Message.Length)).PadRight(50) + "`n"
    }

    return $table  # Return the generated table as a string
}

# Generate the table for host load metrics to include in the email body
$hostLoadTable = New-HostLoadTable -results $loadMetrics

# Generate the table for critical logs to include in the email body
$criticalLogTable = New-CriticalLogTable -criticalLogs $allCriticalLogs

# Define the output paths for the HTML reports
$htmlReportPath = "./dashboard/views/reports/standar_report.php"
$htmlReportHardware = "./dashboard/views/reports/hardware_inventory_report.php"

Add-LogMessage -logLevel "Info" -functionName $MyInvocation.InvocationName `
    -message "Setting HTML report output path to: $htmlReportPath"
Add-LogMessage -logLevel "Info" -functionName $MyInvocation.InvocationName `
    -message "Setting HTML hardware inventory report output path to: $htmlReportHardware"

### *** AQUÍ ***
# DEBUG: Check which arrays or parameters are $null
    Write-Host "DEBUG: Inspecting parameters for null values..."
    Write-Host "Power ONResult: $($powerOnResults[0]) "
    Write-Host "Power ONResult: $($powerOnResults[1]) "
    Write-Host "Failed Hostys: $failedHosts"
    Write-Host "GroupName: $GroupName"
    Write-Host "filePath: $htmlReportPath"
    Write-Host "filePathHardwareInventory: $htmlReportHardware"
    Write-Host "loadMetrics is null? $([string]($null -eq $loadMetrics))"
    Write-Host "criticalLogs is null? $([string]($null -eq $criticalLogs))"
    Write-Host "applicationErrorLogs is null? $([string]($null -eq $applicationErrorLogs))"
    Write-Host "failedHostsLogs is null? $([string]($null -eq $failedHostsLogs))"
    Write-Host "activeSessionsLogs is null? $([string]($null -eq $activeSessionsLogs))"
    Write-Host "failedShutdownLogs is null? $([string]($null -eq $failedShutdownLogs))"
    Write-Host "updateLogs is null? $([string]($null -eq $updateLogs))"
    Write-Host "verificationUpdateLogs is null? $([string]($null -eq $verificationUpdateLogs))"
    Write-Host "hardwareInventory is null? $([string]($null -eq $hardwareInventory))"
    Write-Host "dbHost: $($Global:Config.UserConfigData.DatabaseConnection.dataBaseHost)"
    Write-Host "dbName: $($Global:Config.UserConfigData.DatabaseConnection.dataBaseName)"
    Write-Host "DEBUG: Inspecting safe arrays content..."
Write-Host "criticalLogsSafe count: $($criticalLogsSafe.Count)"
Write-Host "applicationErrorLogsSafe count: $($applicationErrorLogsSafe.Count)"
Write-Host "failedHostsLogsSafe count: $($failedHostsLogsSafe.Count)"
Write-Host "activeSessionsLogsSafe count: $($activeSessionsLogsSafe.Count)"
Write-Host "failedShutdownLogsSafe count: $($failedShutdownLogsSafe.Count)"
Write-Host "updateLogsSafe count: $($updateLogsSafe.Count)"
Write-Host "verificationLogsSafe count: $($verificationLogsSafe.Count)"
Write-Host "loadMetricsSafe count: $($loadMetricsSafe.Count)"
Write-Host "hardwareInventorySafe count: $($hardwareInventorySafe.Count)"

# Opcional: imprimir primer elemento si existe
if ($criticalLogsSafe.Count -gt 0) { Write-Host "First critical log:" $criticalLogsSafe[0] }
if ($applicationErrorLogsSafe.Count -gt 0) { Write-Host "First application error log:" $applicationErrorLogsSafe[0] }
if ($failedHostsLogsSafe.Count -gt 0) { Write-Host "First failed host log:" $failedHostsLogsSafe[0] }
if ($activeSessionsLogsSafe.Count -gt 0) { Write-Host "First active session log:" $activeSessionsLogsSafe[0] }
if ($failedShutdownLogsSafe.Count -gt 0) { Write-Host "First failed shutdown log:" $failedShutdownLogsSafe[0] }
if ($updateLogsSafe.Count -gt 0) { Write-Host "First update log:" $updateLogsSafe[0] }
if ($verificationLogsSafe.Count -gt 0) { Write-Host "First verification log:" $verificationLogsSafe[0] }
if ($loadMetricsSafe.Count -gt 0) { Write-Host "First load metric:" $loadMetricsSafe[0] }
if ($hardwareInventorySafe.Count -gt 0) { Write-Host "First hardware inventory entry:" $hardwareInventorySafe[0] }

# Prepare safe arrays for the call to New-ReportFiles
# Ensure all arrays are not null
$criticalLogsSafe          = if ($allCriticalLogs)          { $allCriticalLogs }          else { @() }
$applicationErrorLogsSafe  = if ($allApplicationErrorLogs)  { $allApplicationErrorLogs }  else { @() }
$failedHostsLogsSafe       = if ($failedHosts)              { $failedHosts }              else { @() }
$activeSessionsLogsSafe    = if ($sessionLogEntries)        { $sessionLogEntries }        else { @() }
$failedShutdownLogsSafe    = if ($failedShutdowns)          { $failedShutdowns }          else { @() }
$updateLogsSafe            = if ($resultUpdate -and $resultUpdate.UpdateLogEntries)          { $resultUpdate.UpdateLogEntries }          else { @() }
$verificationLogsSafe      = if ($resultUpdate -and $resultUpdate.VerificationUpdateEntries) { $resultUpdate.VerificationUpdateEntries } else { @() }
$loadMetricsSafe           = if ($loadMetrics)              { $loadMetrics }              else { @() }
$hardwareInventorySafe     = if ($allHardwareInventory)     { $allHardwareInventory }     else { @() }

# Generate the HTML report with collected metrics, logs, and inventory
try {
    Add-LogMessage -logLevel "Info" -functionName $MyInvocation.InvocationName `
        -message "Generating HTML reports for collected data."

    New-ReportFiles -GroupName $GroupName `
        -filePath $htmlReportPath `
        -filePathHardwareInventory $htmlReportHardware `
        -loadMetrics $loadMetricsSafe `
        -criticalLogs $criticalLogsSafe `
        -applicationErrorLogs $applicationErrorLogsSafe `
        -failedHostsLogs $failedHostsLogsSafe `
        -activeSessionsLogs $activeSessionsLogsSafe `
        -failedShutdownLogs $failedShutdownLogsSafe `
        -updateLogs $updateLogsSafe `
        -verificationUpdateLogs $verificationLogsSafe `
        -hardwareInventory $hardwareInventorySafe `
        -dbHost $Global:Config.UserConfigData.DatabaseConnection.dataBaseHost `
        -dbName $Global:Config.UserConfigData.DatabaseConnection.dataBaseName
    
    Add-LogMessage -logLevel "Success" -functionName $MyInvocation.InvocationName `
        -message "HTML reports successfully generated."
}
catch {
    Add-LogMessage -logLevel "Error" -functionName $MyInvocation.InvocationName `
        -message "Error occurred during report generation: $($_.Exception.Message)"
    throw "Report generation failed."
}

# Combine all logs and prepare for logging or report
$logEntries = $failedHosts + $sessionLogEntries + $failedShutdowns
Add-LogMessage -logLevel "Info" -functionName $MyInvocation.InvocationName `
    -message "Log entries prepared. Count: $($logEntries.Count)."

# Record the execution end time
[DateTime]$executionEndTime = Get-Date

# Calculate execution duration
$executionDuration = $executionEndTime - $executionStartTime
Add-LogMessage -logLevel "Info" -functionName $MyInvocation.InvocationName `
    -message "Execution duration: $($executionDuration.ToString())."

# Log execution summary
Add-LogMessage -logLevel "Summary" -functionName $MyInvocation.InvocationName `
    -message "Script executed successfully. Start: $($executionStartTime.ToString("yyyy-MM-dd HH:mm:ss")), End: $($executionEndTime.ToString("yyyy-MM-dd HH:mm:ss")), Duration: $executionDuration."

# Final cleanup: Delete temporary files and clear cache
try {
    if (Test-Path "./tmp/cache/backend/active_sessions.cache") {
        Remove-Item -Path "./tmp/cache/backend/active_sessions.cache" -Force
        Add-LogMessage -logLevel "Info" -functionName $MyInvocation.InvocationName `
            -message "Temporary file './tmp/cache/backend/active_sessions.cache' deleted."
    }

    if (Test-Path "./tmp/cache/frontend/html_options_all_hosts.cache") {
        Remove-Item -Path "./tmp/cache/frontend/html_options_all_hosts.cache" -Force
        Add-LogMessage -logLevel "Info" -functionName $MyInvocation.InvocationName `
            -message "Temporary file './tmp/cache/frontend/html_options_all_hosts.cache' deleted."
    }

    if (Test-Path "./tmp/cache/frontend/html_options_alive_hosts.cache") {
        Remove-Item -Path "./tmp/cache/frontend/html_options_alive_hosts.cache" -Force
        Add-LogMessage -logLevel "Info" -functionName $MyInvocation.InvocationName `
            -message "Temporary file './tmp/cache/frontend/html_options_alive_hosts.cache' deleted."
    }
}
catch {
    Add-LogMessage -logLevel "Warning" -functionName $MyInvocation.InvocationName `
        -message "Error during temporary file cleanup: $($_.Exception.Message)."
}

# Delete old log files
try {
    Remove-OldLogFiles -logDirectory "$($Global:Config.Paths.Log.Root)" -retainCount 10
    Add-LogMessage -logLevel "Info" -functionName $MyInvocation.InvocationName `
        -message "Old log files cleaned up. Retained latest 10 logs."
}
catch {
    Add-LogMessage -logLevel "Warning" -functionName $MyInvocation.InvocationName `
        -message "Error during log file cleanup: $($_.Exception.Message)."
}

# Clear global variables if necessary
try {
    if (Get-Variable -Name "OpsHostGuardCalling" -Scope Global -ErrorAction SilentlyContinue) {
        Remove-Variable -Name "OpsHostGuardCalling" -Scope Global -ErrorAction SilentlyContinue
        Add-LogMessage -logLevel "Info" -functionName $MyInvocation.InvocationName `
            -message "Cleared global variable: OpsHostGuardCalling."
    }

    if (Get-Variable -Name "tempLogMessages" -Scope Global -ErrorAction SilentlyContinue) {
        Remove-Variable -Name "tempLogMessages" -Scope Global -ErrorAction SilentlyContinue
        Add-LogMessage -logLevel "Info" -functionName $MyInvocation.InvocationName `
            -message "Cleared global variable: tempLogMessages."
    }
}
catch {
    Add-LogMessage -logLevel "Warning" -functionName $MyInvocation.InvocationName `
        -message "Error clearing global variables: $($_.Exception.Message)."
}

# Final log message
Add-LogMessage -logLevel "Info" -functionName $MyInvocation.InvocationName `
    -message "OpsBasicScan script execution completed successfully."

# End the script gracefully
Write-Host "`nOpsBasicScan script execution completed. Check logs for details." -ForegroundColor Green
exit 0


