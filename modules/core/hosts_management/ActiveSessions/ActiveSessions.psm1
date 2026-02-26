# ActiveSessions.psm1 [OpsHostGuard Module]

<#
    .SYNOPSIS
    Captures and displays active sessions on one or more Windows hosts, with the option to export results to CSV.

    .DESCRIPTION
    This module collects active user sessions from Windows Systems using the `quser` command. It includes functions 
    to check host reachability, retrieve active session data, and export results to a CSV file. The module can 
    operate in two modes:
    - **Standalone mode**: It functions independently, allowing logging and configuration tailored to autonomous 
      execution.
    - **Integrated mode**: When executed within the OpsHostGuard framework, it utilizes global logging and 
      configuration settings.

    Displayed Information includes username, session type (graphical or console), session state (active or disconnected), 
    and logon date and time.

    .FUNCTIONS
    - `Invoke-ASCheck`: Main function that drives the module’s logic, checking host reachability, capturing active 
       sessions, and exporting to CSV if specified.
    - `Test-ASHostReachability`: Checks if a host is reachable using ICMP.
    - `Get-ASSessions`: Retrieves active sessions on a specified host.

    .FUNCTION PARAMETERS

    - Invoke-ASCheck

    .PARAMETER groupName
    Specifies the name of the group of hosts to analyze.

    .PARAMETER hostName
    Specifies the name of the individual host to analyze.

    .PARAMETER export
    If specified, the results will be exported to a CSV file in the output directory.

    - Get-ASSessions

    .PARAMETER SimpleCheck
    Parameter to control the output type. Purpose of cmdlet reuse.

    .EXAMPLE
    Invoke-ASCheck -GroupName lab
    This will check all hosts in the "lab" group, capture the active user sessions, and display them on the console.

    .EXAMPLE
    Invoke-ASCheck -h i1-js-01
    This will check the host "i1-js-01" for active sessions and display the results on the console.

    .EXAMPLE
    Invoke-ASCheck -GroupName lab -export
    This will capture active user sessions on the hosts in group "lab" and export the results to a CSV file.

    .NOTES
    - This module requires administrative privileges to function correctly on remote hosts.
    - It is compatible with both standalone execution and integration within OpsHostGuard.

    .ORGANIZATION
    Developed for: Faculty of Documentation and Communication Sciences at the University of Extremadura.

    .AUTHOR [© 2024 Alberto Ledo]
    Alberto Ledo [Faculty of Documentation and Communication Sciences] - with assistance from OpenAI
    IT Department: University of Extremadura - IT Services for Facilities
    Contact: albertoledo@unex.es

    .Copyright
    © 2024 Alberto Ledo

    .VERSION
    1.4.0 

    .HISTORY
    
    1.4.0 - Added dual-mode functionality for both standalone and OpsHostGuard-integrated usage.
    1.3.1 - Bug fixes and addition of enhanced Debug Information.
    1.3.0 - Converted to a PowerShell module with distinct functions. Added `Invoke-ASCheck` as the primary function 
            to handle session retrieval and CSV export. Improved session processing with a unique key mechanism to 
            avoid duplicate entries. Added support for waiting session mode for inactive console users.
    1.2.0 - Added Debug parameter and Error handling improvements.
    1.1.0 - Refactored for improved readability and structure.
    1.0.0 - Original script created by Alberto Ledo.
    
    .USAGE
    This script is strictly for internal use within the University of Extremadura. 
    It is designed to operate within the IT infrastructure and environment of the University of Extremadura and 
    may not function as expected in other environments.

    .DATE
    November 12, 2024

    .DISCLAIMER
    This script is provided "as-is" and is intended for internal use at the University of Extremadura.
    No warranties, express or implied, are provided. Any modifications or adaptations are not covered 
    under this disclaimer.

    .LINK
    https://github.com/n7rc/OpsHostGuard
#>

<#
#Requires -Module OpsInit
#Requires -Module OpsBase
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
$Script:ModuleName = if ($null -ne $MyInvocation.MyCommand.Module) { $MyInvocation.MyCommand.Module.Name } else { "ActiveSessions" }

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

    $Script:StandaloneDependencies = @("LogManager", "OpsUtils", "StartHosts")

    # Ensure CoreDependencies is not empty before calling New-CoreStandalone
    if (-not $Script:StandaloneDependencies -or $Script:StandaloneDependencies.Count -eq 0) {
        Add-LogMessage -message "No valid standalone dependencies to process. Aborting standalone initialization." -logLevel "Error"
        throw "No valid core dependencies to process."
    }

    # Call standalone initialization
    try {
        # Indicate that ActiveSessions is importing other module
        Import-StandaloneDependencies -standaloneDependencies $Script:StandaloneDependencies
        New-ModuleStandalone -moduleName $Script:ModuleName
        Add-LogMessage -message "Standalone mode activated for $Script:ModuleName." -logLevel "Info"
    }
    catch {
        Add-LogMessage -message "Failed to initialize standalone mode for $Script:ModuleName. Error: $_" -logLevel "Error"
        throw
    }   
}


# Function to display help message for the ActiveSessions module's main functions
function Show-Help {
    param (
        [string]$functionName = "Get-ActiveSessions"
    )

    # Display usage instructions for Get-ActiveSessions function
    Write-Host "`nUSAGE:`n" -ForegroundColor Yellow
    Write-Host "    $functionName [[-GroupName <String>] | [-HostName <String>] | [-HostsList <array>]] [-export] [-Verbose:[1|0]] [-Silent:[1|0]]`n" -ForegroundColor White

    Write-Host "`nDESCRIPTION:`n" -ForegroundColor Yellow
    Write-Host "    The $functionName function facilitates active session checks on remote hosts. It retrieves active user sessions on specified hosts or groups and exports results to a CSV file if requested." -ForegroundColor White

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

    # Provide example usage for different scenarios
    Write-Host "`nEXAMPLES:`n" -ForegroundColor Yellow
    Write-Host "    Get-ActiveSessions -GroupName 'lab'" -ForegroundColor White
    Write-Host "        Checks all hosts in the 'lab' group for active sessions and displays the results on the console."

    Write-Host "    Get-ActiveSessions -HostName 'i1-js-01'" -ForegroundColor White
    Write-Host "        Checks the host 'i1-js-01' for active sessions and displays the results on the console."

    Write-Host "    Get-ActiveSessions -GroupName 'lab' -export" -ForegroundColor White
    Write-Host "        Captures active user sessions on the hosts in group 'lab' and exports the results to a CSV file."

    Write-Host "    Get-ActiveSessions -HostName 'i1-js-01' -Silent:0" -ForegroundColor White
    Write-Host "        Checks the host 'i1-js-01' for active sessions in silent mode, suppressing most output."

    Write-Host "`nNOTES:`n" -ForegroundColor Yellow
    Write-Host "    The ActiveSessions module requires administrative privileges to retrieve sessions on remote hosts.`n" -ForegroundColor White
}

# Function to check if a host is reachable
function Test-ASHostReachability {
    param ([string]$remoteHost)

    try {
        if (Test-Connection -ComputerName $remoteHost -Count 1 -Quiet -ErrorAction Stop) {
            $logMessage = "Host $remoteHost is reachable via ping."
            if (Test-ExecutionContext -ConsoleCheck) {
                Add-LogMessage -message $logMessage -logLevel "Info" -logCorePath $logCorePath
            }
            else {
                Add-LogMessage -message $logMessage -logLevel "Info"
            }
            return $true
        }
        else {
            $logMessage = "Host $remoteHost is not reachable via ping."
            if (Test-ExecutionContext -ConsoleCheck) {
                Add-LogMessage -message $logMessage -logLevel "Info" -logCorePath $logCorePath
            }
            else {
                Add-LogMessage -message $logMessage -logLevel "Info"
            }
            return $false
        }
    }
    catch {
        $logMessage = "Connection attempt failed for host ${remoteHost}: $_"
        if (Test-ExecutionContext -ConsoleCheck) {
            Add-LogMessage -message $logMessage -logLevel "Info" -logCorePath $logCorePath
        }
        else {
            Add-LogMessage -message $logMessage -logLevel "Info"
        }
        $logMessage = "Unable to reach $remoteHost. Please verify network settings or firewall."
        if (Test-ExecutionContext -ConsoleCheck) {
            Add-LogMessage -message $logMessage -logLevel "Warning" -logCorePath $logCorePath
        }
        else {
            Add-LogMessage -message $logMessage -logLevel "Warning"
        }
        return $false
    }
}

# Function to get active sessions from a host
function Get-ASSessions { 
    param (
        [string]$remoteHost,
        [switch]$simpleCheck  # Parameter to control the output type
    )

    try {
        # Log the start of the operation
        $logMessage = "Retrieving active sessions from $remoteHost..."
        if (Test-ExecutionContext -ConsoleCheck) {
            Add-LogMessage -message $logMessage -logLevel "Info" -logCorePath $logCorePath
        }
        else {
            Add-LogMessage -message $logMessage -logLevel "Info"
        }

        # Check if the host is reachable and available
        $hostUp = Test-STHostUp -HostName $remoteHost -UseDNS:$false -Silent:$true
        $logMessage = "Host $remoteHost is reachable: $hostUp"
        if (Test-ExecutionContext -ConsoleCheck) {
            Add-LogMessage -message $logMessage -logLevel "Debug" -logCorePath $logCorePath
        }
        else {
            Add-LogMessage -message $logMessage -logLevel "Debug"
        }

        if (-not $hostUp) {
            $logMessage = "Host $remoteHost is not reachable. Skipping session retrieval."
            if (Test-ExecutionContext -ConsoleCheck) {
                Add-LogMessage -message $logMessage -logLevel "Warning" -logCorePath $logCorePath
            }
            else {
                Add-LogMessage -message $logMessage -logLevel "Warning"
            }

            if ($simpleCheck) {
                return $false
            }
            else {
                return @("Host not reachable")
            }
        }

        # If reachable, log and execute the `quser` command
        $logMessage = "Host $remoteHost is reachable. Proceeding to execute 'quser'..."
        if (Test-ExecutionContext -ConsoleCheck) {
            Add-LogMessage -message $logMessage -logLevel "Info" -logCorePath $logCorePath
        }
        else {
            Add-LogMessage -message $logMessage -logLevel "Info"
        }

        #$sessions = quser /server:$remoteHost 2>&1 | ForEach-Object { $_.Trim() }
        $sessions = quser /server:$remoteHost | ForEach-Object { $_.Trim() }

        write-host "Debug: $sessions" -ForegroundColor Red
        
        # Check for active sessions
        $activeSessionFound = $sessions | Where-Object { $_ -match '\sActivo\s' }

        write-host "Debug: $activeSessionFound" -ForegroundColor Red

        if ($simpleCheck) {
            # Return true if an active session is found
            if ($activeSessionFound) {
                $logMessage = "Active sessions found on $remoteHost."
                if (Test-ExecutionContext -ConsoleCheck) {
                    Add-LogMessage -message $logMessage -logLevel "Success" -logCorePath $logCorePath
                }
                else {
                    Add-LogMessage -message $logMessage -logLevel "Success"
                }
                return $true
            }
            else {
                $logMessage = "No active users found on $remoteHost."
                if (Test-ExecutionContext -ConsoleCheck) {
                    Add-LogMessage -message $logMessage -logLevel "Info" -logCorePath $logCorePath
                }
                else {
                    Add-LogMessage -message $logMessage -logLevel "Info"
                }
                return $false
            }
        }

        # Initialize sessionDetails as an empty array
        $sessionDetails = @()

        # Process session details for non-simple mode
        $logMessage = "Processing active session data for $remoteHost..."
        if (Test-ExecutionContext -ConsoleCheck) {
            Add-LogMessage -message $logMessage -logLevel "Info" -logCorePath $logCorePath
        }
        else {
            Add-LogMessage -message $logMessage -logLevel "Info"
        }

        foreach ($line in $sessions) {
            $sessionParts = $line -split "\s{2,}"  # Split by two or more spaces

            # Validar que el número de partes sea correcto (5 o 6) antes de procesar
            if ($sessionParts.Count -lt 5) {
                Write-Host "Debug: Skipping invalid session line: $line" -ForegroundColor Yellow
                continue
            }
        
            # Debugging: Log the session parts
            Write-Host "Debug sessionParts: $sessionParts" -ForegroundColor Red

            # Handle lines with 5 parts
            if ($sessionParts.Count -eq 5) {
                $sessionType = if ($sessionParts[1] -match '^\d+$') { "waiting" } else { $sessionParts[1] }
                $sessionDetails += [PSCustomObject]@{
                    "Host"    = $remoteHost
                    "Name"    = $sessionParts[0]
                    "Session" = $sessionType
                    "State"   = $sessionParts[2]
                    "Logon"   = $sessionParts[4]
                }
            }
            # Handle lines with 6 parts
            elseif ($sessionParts.Count -eq 6) {
                $sessionDetails += [PSCustomObject]@{
                    "Host"    = $remoteHost
                    "Name"    = $sessionParts[0]
                    "Session" = $sessionParts[1]
                    "State"   = $sessionParts[3]
                    "Logon"   = $sessionParts[5]
                }
            }

            write-host "Debug sessionParts: $sessionParts" -ForegroundColor Red
        }

        # Log success if session details are processed
        $logMessage = "Successfully retrieved sessions for $remoteHost."
        if (Test-ExecutionContext -ConsoleCheck) {
            Add-LogMessage -message $logMessage -logLevel "Success" -logCorePath $logCorePath
        }
        else {
            Add-LogMessage -message $logMessage -logLevel "Success"
        }
        # Debugging: Log the session details before returning
        Write-Host "Debug sessionsDetails:" -ForegroundColor Red
        $sessionDetails | Format-Table -AutoSize

        # Elimina sesiones vacías
        $sessionDetails = $sessionDetails | Where-Object { $_.Name -and $_.Session -and $_.State -and $_.Logon }
        # Return the sessionDetails array
        return $sessionDetails
    }
    catch {
        # Log error for failed session retrieval
        $logMessage = "Failed to retrieve sessions for host ${remoteHost}: $_"
        if (Test-ExecutionContext -ConsoleCheck) {
            Add-LogMessage -message $logMessage -logLevel "Warning" -logCorePath $logCorePath
        }
        else {
            Add-LogMessage -message $logMessage -logLevel "Warning"
        }

        # Log additional error message
        $logMessage = "Error connecting to $remoteHost. Verify permissions and network availability."
        if (Test-ExecutionContext -ConsoleCheck) {
            Add-LogMessage -message $logMessage -logLevel "Error" -logCorePath $logCorePath
        }
        else {
            Add-LogMessage -message $logMessage -logLevel "Error"
        }

        # Return based on mode
        if ($simpleCheck) {
            return $false
        }
        else {
            return @("Error connecting to $remoteHost")
        }
    }
}


# Main function - executes the module's logic
function Invoke-ASCheck {
    param (
        [string]$GroupName,
        [string]$HostName,
        [switch]$export,
        [bool]$Verbose,
        [bool]$Silent
    )

    # Log the start of the function
    Add-LogMessage -functionName $MyInvocation.InvocationName -logLevel "Info" `
        -message "Starting Invoke-ASCheck with parameters: groupName='$GroupName', hostName='$HostName', export='$export'."

    # Load host groups using Get-HostsGroups
    $Script:hostsGroupsHash = Get-HostsGroups -GroupName $GroupName
    if (-not $Script:hostsGroupsHash) {
        Add-LogMessage -functionName $MyInvocation.InvocationName -logLevel "Error" `
            -message "Failed to load host groups. Ensure the configuration is correct."
        return
    }

    # Validate input parameters
    if (-not $GroupName -and -not $HostName) {
        Add-LogMessage -functionName $MyInvocation.InvocationName -logLevel "Error" `
            -message "Both 'groupName' and 'hostName' are null. At least one must be specified."
        return
    }

    # Determine the hosts to check
    
    <#
    $hostsToCheck = @()
    if ($GroupName) {
        if (-not $Script:hostsGroupsHash.ContainsKey($GroupName)) {
            Add-LogMessage -functionName $MyInvocation.InvocationName -logLevel "Error" `
                -message "Group '$GroupName' not found in the host groups."
            return
        }
        $hostsToCheck = $Script:hostsGroupsHash[$GroupName]
    }
    elseif ($HostName) {
        $hostsToCheck = @($HostName)
    }
    #>
    $hostsToCheck = @()
    if ($GroupName) {
        # Acceder directamente al grupo desde $Global:Config.hostsData.Groups.GroupName
        if ($Global:Config.hostsData.Groups.GroupName.ContainsKey($GroupName)) {
            $hostsToCheck = $Global:Config.hostsData.Groups.GroupName[$GroupName]
            Write-Host "Debug: Hosts retrieved for group '$GroupName': $($hostsToCheck -join ', ')" -ForegroundColor Yellow
        }
        else {
            Add-LogMessage -functionName $MyInvocation.InvocationName -logLevel "Error" `
                -message "Group '$GroupName' not found in the host groups."
            return
        }
    }
    elseif ($HostName) {
        $hostsToCheck = @($HostName)
    }

    write-host $hostsToCheck -ForegroundColor Red

    # Initialize containers for results and avoid duplicates
    $results = @()
    $uniqueResults = @{}
    $reachableHosts = @()

    foreach ($remoteHost in $hostsToCheck) {
        if (-not $Silent) {
            $logMessage = "Checking reachability for host: $remoteHost"
            if (Test-ExecutionContext -ConsoleCheck) {
                Add-LogMessage -message $logMessage -logLevel "Info" -logCorePath $logCorePath
            }
            else {
                Add-LogMessage -message $logMessage -logLevel "Info"
            } 
        }
        if (Test-ASHostReachability -remoteHost $remoteHost) {
            if (-not $Silent) {
                $logMessage = "Host $remoteHost is reachable. Retrieving active sessions..."
                if (Test-ExecutionContext -ConsoleCheck) {
                    Add-LogMessage -message $logMessage -logLevel "Info" -logCorePath $logCorePath
                }
                else {
                    Add-LogMessage -message $logMessage -logLevel "Info"
                } 
            }
            $sessions = Get-ASSessions -remoteHost $remoteHost
            $reachableHosts += $remoteHost

            write-host $sessions -ForegroundColor Red
        
            foreach ($session in $sessions) {
                if (-not $session.Name -or -not $session.Session -or -not $session.State -or -not $session.Logon) {
                    Write-Host "Debug: Skipping incomplete session data for host $remoteHost" -ForegroundColor Yellow
                    continue
                }

                $uniqueKey = "$($remoteHost)_$($session.Name)_$($session.Session)_$($session.Logon)"
                if (-not $uniqueResults.ContainsKey($uniqueKey)) {
                    $results += [PSCustomObject]@{
                        Host    = $remoteHost
                        Name    = $session.Name
                        Session = $session.Session
                        State   = $session.State
                        Logon   = $session.Logon
                    }
                    $uniqueResults[$uniqueKey] = $true 
                    Write-Host "Debug: Session added for host ${remoteHost}:" -ForegroundColor Green
                    Write-Host "Name: $($session.Name), Session: $($session.Session), State: $($session.State), Logon: $($session.Logon)" -ForegroundColor Green
                }
                else {
                    Write-Host "Debug: Duplicate session ignored for key $uniqueKey" -ForegroundColor Yellow
                }
            }
        }
        else {
            if (-not $Silent) {
                $logMessage = "Warning: Host $remoteHost is unreachable."
                if (Test-ExecutionContext -ConsoleCheck) {
                    Add-LogMessage -message $logMessage -logLevel "Warning" -logCorePath $logCorePath
                }
                else {
                    Add-LogMessage -message $logMessage -logLevel "Warning"
                } 
            }
        }
    }

    # Filter only reachable hosts with active sessions
    $reachableResults = $results | Where-Object { $reachableHosts -contains $_.Host }

    # Display the filtered results in the console
    if (-not $Silent) {
        $logMessage = "Active sessions found:"
        if (Test-ExecutionContext -ConsoleCheck) {
            Add-LogMessage -message $logMessage -logLevel "Success" -logCorePath $logCorePath
            # Debugging: Print the content of $reachableResults
            Write-Host "Debug: Contents of reachableResults:" -ForegroundColor Yellow
            $reachableResults | Format-List | Out-String | Write-Host
        }
        else {
            Add-LogMessage -message $logMessage -logLevel "Success"
        } 
    }
    
    Write-Host "Debug: Reachable results before display:" -ForegroundColor Yellow
    $reachableResults | Format-List

    # Format the table for output
    #if ($reachableResults.Count -gt 0) {
    if (@($reachableResults).Count -gt 0) {
        $reachableResults | Format-Table -AutoSize
    }
    else {
        Write-Host "No active sessions to display." -ForegroundColor Red
    }

    # Export filtered results to CSV if specified
    if ($export) {
        $fileNamePart = if ($GroupName) { $GroupName } else { $HostName }
        $csvFilePath = Join-Path -Path $Global:ProjectRoot -ChildPath "data/csv/sessions_${fileNamePart}.csv"
        # Define the full path of the temporary file
        $csvFilePathTemp = Join-Path -Path $Global:ProjectRoot -ChildPath "tmp/cache/backend/active_sessions.cache"
              
        # Check if the file exists
        if (-not (Test-Path -Path $csvFilePathTemp)) {
            # Create the file if it doesn't exist
            New-Item -Path $csvFilePathTemp -ItemType File -Force | Out-Null
            $logMessage = "File created: $csvFilePathTemp"
            if (Test-ExecutionContext -ConsoleCheck) {
                Add-LogMessage -message $logMessage -logLevel "Info" -logCorePath $logCorePath
            }
            else {
                Add-LogMessage -message $logMessage -logLevel "Info"
            }
        }
        else {
            $logMessage = "File already exists: $csvFilePathTemp"
            if (Test-ExecutionContext -ConsoleCheck) {
                Add-LogMessage -message $logMessage -logLevel "Info" -logCorePath $logCorePath
            }
            else {
                Add-LogMessage -message $logMessage -logLevel "Info"
            }
        }
        
        if (-not $Silent) {
            $logMessage = "Exporting results to CSV at: $csvFilePath"
            if (Test-ExecutionContext -ConsoleCheck) {
                Add-LogMessage -message $logMessage -logLevel "Info" -logCorePath $logCorePath
            }
            else {
                Add-LogMessage -message $logMessage -logLevel "Info"
            } 
        }
        if (-not $Silent) {
            $logMessage = "Exporting temporary session data to: $csvFilePathTemp"
            if (Test-ExecutionContext -ConsoleCheck) {
                Add-LogMessage -message $logMessage -logLevel "Info" -logCorePath $logCorePath
            }
            else {
                Add-LogMessage -message $logMessage -logLevel "Info"
            }
        }
        
        # Ensure temporary directory exists
        $directorytmp = Join-Path -Path $Global:ProjectRoot -ChildPath "tmp"
                
        if (-not (Test-Path -Path $directorytmp)) {
            New-Item -Path $directorytmp -ItemType Directory | Out-Null
            if (-not $Silent) {
                $logMessage = "Temporary directory created: $directorytmp"
                if (Test-ExecutionContext -ConsoleCheck) {
                    Add-LogMessage -message $logMessage -logLevel "Info" -logCorePath $logCorePath
                }
                else {
                    Add-LogMessage -message $logMessage -logLevel "Info"
                } 
            }
        }
        else {
            $logMessage = "Temporary directory already exists at: $directorytmp"
            if (Test-ExecutionContext -ConsoleCheck) {
                Add-LogMessage -message $logMessage -logLevel "Info" -logCorePath $logCorePath
            }
            else {
                Add-LogMessage -message $logMessage -logLevel "Info"
            }
        }
    
        # Export results to CSV and temporary file
        $reachableResults | Export-Csv -Path $csvFilePath -NoTypeInformation -Append
        $reachableResults | Export-Csv -Path $csvFilePathTemp -NoTypeInformation
        $logMessage = "Exported reachable hosts with active sessions to CSV at $csvFilePath"
        if (Test-ExecutionContext -ConsoleCheck) {
            Add-LogMessage -message $logMessage -logLevel "Info" -logCorePath $logCorePath
        }
        else {
            Add-LogMessage -message $logMessage -logLevel "Info"
        } 
    }
}

# Public "wrapper" function that invokes `Invoke-ASCheck` to hide it in standalone mode.
# Avoids the use of aliases and allows the function to remain hidden when calling get-command.
function Get-ActiveSessions {
    param (
        [string]$GroupName,
        [string]$HostName,
        [array]$HostsList = @(),
        [switch]$export,
        [bool]$Verbose,
        [bool]$Silent
    )

    # Handle the case where a list of hosts is provided
    #if (@($HostsList).Count -gt 0) {
    if ($HostsList.Count -gt 0) {
        $GroupName = "temporaryGroup"
        New-TemporaryGroup -GroupName $GroupName -HostsList $HostsList
    }

    # Call the core function to process active sessions
    Invoke-ASCheck -GroupName $GroupName -HostName $HostName -export -Verbose:$Verbose -Silent:$Silent
}
# Clean up old logs in standalone mode
if (Test-ExecutionContext -ConsoleCheck) {
    Remove-OldLogFiles -logDirectory $Global:Config.Paths.Log.Sessions -retainCount 10
}

# Conditional export based on execution mode
if (Test-ExecutionContext -ConsoleCheck) {
    # In standalone mode, export only the alias and Show-Help
    Export-ModuleMember -Function Get-ActiveSessions, Show-Help, Get-ASSessions
}
else {

    # In integrated mode, export Invoke-ASCheck and Get-ASSessions directly
    Export-ModuleMember -Function Get-ActiveSessions, Invoke-ASCheck, Get-ASSessions
}

