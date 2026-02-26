# LogManager.psm1 [OpsHostGuard Module]

<#
    .SYNOPSIS
    Provides utility functions for logging and log management within the OpsHostGuard project, including log 
    initialization, rotation, cleanup, and entry addition.

    .DESCRIPTION
    This module includes functions for initializing log files, managing log file rotation when a specified 
    size limit is exceeded, cleaning up old compressed logs, and adding log entries with different log 
    levels (e.g., Info, Success, Warning, Error, Debug). These utilities support effective logging practices 
    within the project and maintain logs for troubleshooting and historical reference.

    .FUNCTIONS
    - `Initialize-Log`: Ensures that the main log file is created and ready for writing. It checks the existence 
       of `LogFilePath` and initiates the log file, adding a header if it is newly created.
    - `New-LogIfNeeded`: Monitors log file size and performs log rotation if the file exceeds 10MB. Old logs are 
       renamed in sequence and compressed if necessary.
    - `Remove-OldLogFiles`: Deletes older compressed log files if their count exceeds the specified retention 
       limit, ensuring that storage is managed efficiently.
    - `Add-LogMessage`: Adds an entry to the log file with a timestamp, log level, and custom message. It also 
       provides color-coded output in the console based on the log level.

    .PARAMETERS
    - `logDirectory` (Remove-OldLogFiles): Specifies the directory where compressed logs are stored. Default is 
       the main log directory defined in `$Global:Config.Paths.Log.Root`.
    - `retainCount` (Remove-OldLogFiles): Number of compressed log files to retain before older files are deleted.
    - `message` (Add-LogMessage): The message content for the log entry.
    - `functionName` (Add-LogMessage): Indicates the function where the log entry is generated. Default is "Main".
    - `logLevel` (Add-LogMessage): Defines the severity level of the log (Info, Success, Warning, Error, Debug).

    .NOTES
    This module relies on paths initialized by `OpsInit.psm1`. Ensure that `OpsInit.psm1` is imported 
    and the `Initialize-Variables` function is called prior to using any functions within `LogManager.psm1`.

    .ORGANIZATION
    Developed for: Faculty of Documentation and Communication Sciences at the University of Extremadura.

    .AUTHOR [© 2024 Alberto Ledo]
    Alberto Ledo [Faculty of Documentation and Communication Sciences] - with assistance from OpenAI
    IT Department: University of Extremadura - IT Services for Facilities
    Contact: albertoledo@unex.es

    .Copyright
    © 2024 Alberto Ledo

    .VERSION
    1.3.0 

    .HISTORY
    1.0.0 - Initial version with logging functions.
    1.1.0 - Added log rotation and cleanup functionality.
    1.2.0 - Enhanced `Add-LogMessage` with log level color-coding and automatic rotation checks.
    1.3.0 - Added Add-LogMessage for capturing initial log messages before initializing the System.

    .USAGE
    This script is strictly for internal use within University of Extremadura.
    It is designed to operate within the IT infrastructure and may not function as expected in other environments.

    .DATE
    November 4, 2024

    .DISCLAIMER
    This script is provided "as-is" and is intended for internal use at University of Extremadura.
    No warranties, express or implied, are provided. Any modifications or adaptations are not covered
    under this disclaimer.

    .LINK
    https://github.com/n7rc/OpsHostGuard
#>
<#
if (-not (Get-Module -Name OpsInit)) {
    try {
        $basePathUtils = (Resolve-Path -Path (Join-Path -Path $PSScriptRoot -ChildPath "../../")).Path
        $configPathDataUtils = Join-Path -Path $basePathUtils -ChildPath "configurations/OpsInit.psd1"
        
        # Attempt to import the OpsInit module
        #Import-Module -Name $configPathDataUtils -Force
        
        # Console and log message for Successful import
        Write-Host "[Info] Successfully imported OpsInit module from path: $configPathDataUtils"
        #Add-LogMessage -logLevel "Info" -message "Successfully imported OpsInit module from path: $configPathDataUtils"
    }
    catch {
        # Error handling for failed import
        $ErrorMessage = "[Error] Failed to import OpsInit module from path: $configPathDataUtils. Error: $($_.Exception.Message)"
        Write-Host $ErrorMessage -ForegroundColor Red
        #Add-LogMessage -logLevel "Error" -message $ErrorMessage
        
        # Throw an exception to halt further processing if OpsInit is required
        throw "OpsInit module is required but could not be loaded. Program execution halted."
    }
}

# Import LogManager Module
if (-not (Get-Module -Name LogManager)) {
    try {
        $basePathUtils = (Resolve-Path -Path (Join-Path -Path $PSScriptRoot -ChildPath ".")).Path
        $configPathDataUtils = Join-Path -Path $basePathUtils -ChildPath "LogManager.psd1"
        
        # Attempt to import the LogManager module
        #Import-Module -Name $configPathDataUtils -Force
        
        # Console message for Successful import
        Write-Host "[Info] Successfully imported LogManager module from path: $configPathDataUtils"
        # Add-LogMessage -logLevel "Info" -message "Successfully imported LogManager module from path: $configPathDataUtils"
    }
    catch {
        # Error handling for failed import
        $ErrorMessage = "[Error] Failed to import LogManager module from path: $configPathDataUtils. Error: $($_.Exception.Message)"
        Write-Host $ErrorMessage -ForegroundColor Red
        # Add-LogMessage -logLevel "Error" -message $ErrorMessage
        
        # Throw an exception to halt further processing if LogManager is required
        throw "LogManager module is required but could not be loaded. Program execution halted."
    }
}
#>
# Function to process power-on results and return two lists: failed hosts and Successful hosts
function Resolve-PowerOn {
    param (
        [array]$powerOnResult,
        [string]$timestamp
    )
    
    $failedHosts = @()  # Array to store hosts that failed to power on
    $successfulHosts = @()  # Array to store hosts that Successfully powered on

    Add-LogMessage "Checking power-on results..."
    foreach ($hostEntry in $powerOnResult) {
        if ($hostEntry.Status -ne "Success") {
            Add-LogMessage "Power-on failed for host: $($hostEntry.Name)"
            $failedHosts += New-Object PSObject -Property @{
                HostName  = $hostEntry.Name
                Timestamp = $timestamp
                Status    = "Power-on Failed"
            }
        }
        else {
            Add-LogMessage "Power-on succeeded for host: $($hostEntry.Name)"
            $successfulHosts += New-Object PSObject -Property @{
                HostName  = $hostEntry.Name
                Timestamp = $timestamp
                Status    = "Powered On"
            }
        }
    }
    
    return @($failedHosts, $successfulHosts)
}

# Function to retrieve all hosts from a specific group in host_groups.json
function Get-HostsFromGroup {
    param (
        [string]$GroupName  # Name of the group to retrieve hosts from
    )

    $hostGroupsFile = "./config/host_groups.json"  # Path to the host groups file
    if (Test-Path $hostGroupsFile) {
        $hostGroups = Get-Content $hostGroupsFile | ConvertFrom-Json
        if ($hostGroups.$GroupName) {
            return $hostGroups.$GroupName
        }
        else {
            if (-not $Silent) {
                Add-LogMessage "Group '$GroupName' not found in $hostGroupsFile." -ForegroundColor Red 
            }
            exit 1
        }
    }
    else {
        if (-not $Silent) {
            Add-LogMessage "File $hostGroupsFile not found." -ForegroundColor Red 
        }
        exit 1
    }
}

Export-ModuleMember -Function Resolve-PowerOn, Get-HostsFromGroup
