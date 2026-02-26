# StartHosts.psm1 [OpsHostGuard Module]

<#
    .SYNOPSIS
    Sends Wake-on-LAN (WOL) packets to specified hosts within a group or individually, with readiness verification and flexible IP address configuration for multiple network interfaces.

    .DESCRIPTION
    The `Start-Hosts` module allows administrators to wake up Windows hosts using Wake-on-LAN (WOL) packets, either as part of the `OpsHostGuard` environment or as a standalone script. It enables administrators to target host groups or individual hosts as configured in a JSON file. Each host’s readiness is validated through ping responses and RPC port (135) checks, confirming full Windows initialization. Unreachable hosts or those failing readiness checks are logged for comprehensive status tracking.

    The module now supports hosts with multiple network interfaces by validating RPC connectivity across each available IPv4 address. Configuration settings allow the user to define specific IP prefixes for their network, enhancing flexibility and adapting to various network architectures.

    Enhanced configuration functions validate the JSON structure for data integrity, while additional Error handling supports complex, dynamic host configurations.

    .FUNCTIONS
    - `Invoke-STHostWakeup`: Main function for executing WOL and validating readiness across specified hosts.
    - `Send-STWOLPacket`: Dispatches WOL packets to wake up specified hosts.
    - `Test-STHostUp`: Validates host availability through ping and RPC checks, with DNS resolution and multi-interface support.
    - `Test-STWakeHost`: Sends WOL packets and verifies host readiness upon activation.
    - `Invoke-PowerOnHosts`: Entry point for power-on processes, compatible with `OpsHostGuard` or standalone execution.
    - `Get-StartHostConfig`: Loads and validates JSON configuration, ensuring structural integrity.
    - `Show-Help`: Displays usage instructions, parameters, and examples for module functions.

    .PARAMETERS
    - `useDNS` (Invoke-STHostWakeup, Test-STHostUp): Enables DNS resolution for dynamic network environments.
    - `groupName` (Invoke-STHostWakeup, Invoke-PowerOnHosts): Specifies a group of hosts to wake up.
    - `hostName` (Invoke-STHostWakeup, Invoke-PowerOnHosts): Specifies an individual host for wake-up.
    - `Debug` (Invoke-STHostWakeup, Invoke-PowerOnHosts): Enables Debug output for troubleshooting.
    - `silent` (Invoke-STHostWakeup, Invoke-PowerOnHosts): Suppresses non-critical output messages.

    .EXAMPLES
    Invoke-STHostWakeup -GroupName "lab_servers" -UseDNS -Verbose
    # Wakes up all hosts in "lab_servers" with DNS resolution and Debug enabled.

    Invoke-STHostWakeup -HostName "host01" -Silent
    # Attempts to wake up "host01" with Silent Mode enabled, suppressing non-critical output.

    Invoke-STHostWakeup -GroupName "all"
    # Sends WOL packets to all configured hosts with default settings.

    .NOTES
    Access to RPC port 135 on target hosts is required to confirm Windows readiness. If ping succeeds but RPC check fails, this may indicate incomplete initialization or network/firewall restrictions. Multiple network interfaces are supported, allowing validation across multiple IPs when DNS resolution is enabled.

    This module operates within `OpsHostGuard` or as a standalone module. In standalone mode, logs are handled in `start_hosts.log`; in integrated mode, logging is managed through `OpsHostGuard`'s central logging System.

    .ORGANIZATION
    Developed for: Faculty of Documentation and Communication Sciences, University of Extremadura.

    .AUTHOR [© 2024 Alberto Ledo]
    Alberto Ledo, Faculty of Documentation and Communication Sciences, University of Extremadura - with assistance from OpenAI.
    IT Department: University of Extremadura - IT Services for Facilities
    Contact: albertoledo@unex.es

    .VERSION
    1.2.1

    .HISTORY
    1.2.1 - Added support for multi-interface hosts with RPC validation on multiple IPs; configurable IP prefix setting.
    1.2.0 - Enhanced JSON validation and added logging for individual function execution.
    1.1.0 - Added reusability for `Test-STHostUp`, autonomous logging, and DNS support.
    1.0.1 - Integrated with `OpsHostGuard`, added Debug and silent modes.
    1.0.0 - Initial release with WOL and RPC checks.

    .USAGE
    Designed for internal use within University of Extremadura’s IT infrastructure, supporting both autonomous and integrated execution with `OpsHostGuard`.

    .DATE
    November 11, 2024

    .DISCLAIMER
    Provided "as-is" for internal University of Extremadura use. No warranties, express or implied. Modifications are not covered under this disclaimer.

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

# Script variable to track the current mode
$Global:StandaloneMode = $false

# Module name setup
$Script:ModuleName = if ($null -ne $MyInvocation.MyCommand.Module) { $MyInvocation.MyCommand.Module.Name } else { "StartHosts" }

$timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")

# Load OpsBase module
$opsBasePath = Join-Path -Path $Global:ProjectRoot -ChildPath "modules/core/system/OpsBase.psd1"

write-host "Debug: Punto 1" -ForegroundColor Red

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

    write-host "Debug: Punto 2" -ForegroundColor Red

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

    write-host "Debug: Punto 3" -ForegroundColor Red

    # Ensure CoreDependencies is not empty before calling New-CoreStandalone
    if (-not $Script:StandaloneDependencies -or $Script:StandaloneDependencies.Count -eq 0) {
        Add-LogMessage -message "No valid standalone dependencies to process. Aborting standalone initialization." -logLevel "Error"
        throw "No valid core dependencies to process."
    }

    # Call standalone initialization
    try {
        Import-StandaloneDependencies -standaloneDependencies $Script:StandaloneDependencies -importedByOtherModule = $true
        New-ModuleStandalone -moduleName $Script:ModuleName
        Add-LogMessage -message "Standalone mode activated for $Script:ModuleName." -logLevel "Info"
    }
    catch {
        Add-LogMessage -message "Failed to initialize standalone mode for $Script:ModuleName. Error: $_" -logLevel "Error"
        throw
    }
}

write-host "Debug: Punto 4" -ForegroundColor Red

# Display help Information for the Start-Hosts module
function Show-Help {
    param (
        [string]$functionName = "Start-Hosts"
    )

    Write-Host "`nAlias USAGE:`n" -ForegroundColor Yellow
    Write-Host "    $functionName [[-GroupName <String>] | [-HostName <String>] | [-HostsList <array>]] [-UseDNS:[1|0]]] [-Verbose:[1|0]] [-Silent:[1|0]]" -ForegroundColor White

    Write-Host "`nDESCRIPTION:`n" -ForegroundColor Yellow
    Write-Host "    The $functionName function initiates the wake-up process for a specified group of hosts or an individual host using Wake-on-LAN (WOL). This script can be executed as a standalone module or integrated within OpsHostGuard." -ForegroundColor White

    # Describe each parameter for the function in detail
    Write-Host "`nPARAMETERS:`n" -ForegroundColor Yellow
    Write-Host "
    -GroupName [Optional]
        Name of the host group to wake up. Default: 'all'." -ForegroundColor White
    Write-Host "
    -HostName [Optional]
        Name of a specific host to wake up within the group configuration." -ForegroundColor White
    Write-Host "
    -HostsList [Optional]
        Arbitrary host list to update. Format: host1, host2, host3, ..." -ForegroundColor White
    Write-Host "`nPARAMETERS:`n" -ForegroundColor Yellow   
    Write-Host "
    -UseDNS [Optional]
    Boolean to enable DNS resolution for host checks. Useful for dynamic networks. Default: false." -ForegroundColor White
    Write-Host "
    -Verbose [Optional]
    Boolean to enable Debug Mode, which provides detailed logging for troubleshooting. Default: false." -ForegroundColor White
    Write-Host "
    -Silent [Optional]
    Boolean to enable Silent Mode, suppressing non-critical output messages. Default: false." -ForegroundColor White

    # Provide example usage for different scenarios
    Write-Host "`nEXAMPLES:`n" -ForegroundColor Yellow
    Write-Host "    Start-Hosts -GroupName 'lab_servers' -UseDNS:1 -Verbose:1" -ForegroundColor White
    Write-Host "        Wakes up all hosts in the 'lab_servers' group, using DNS resolution and Debug Mode for detailed logging." -ForegroundColor White

    Write-Host "    Start-Hosts -HostName 'host01' -Silent:1" -ForegroundColor White
    Write-Host "        Attempts to wake up a specific host named 'host01' with Silent Mode enabled to suppress non-critical messages." -ForegroundColor White

    Write-Host "    Start-Hosts -GroupName 'all'" -ForegroundColor White
    Write-Host "        Wakes up all hosts defined in the configuration using default settings (no DNS, no Debug, not silent).`n" -ForegroundColor White
}

# Function to send a Wake-on-LAN (WOL) packet to a specified MAC address
function Send-STWOLPacket {
    param (
        [string]$macAddress,
        [bool]$Silent
    )

    if (Test-ExecutionContext -ConsoleCheck) {
        Add-LogMessage -message "Preparing to send WOL packet to MAC address: $macAddress" -logLevel "Info" -logCorePath $logCorePath
    }
    else {
        Add-LogMessage -message "Preparing to send WOL packet to MAC address: $macAddress" -logLevel "Info"
    }

    # Define broadcast address and port for WOL packet
    $broadcastAddress = "255.255.255.255"
    $port = 9
    $macBytes = $macAddress -split '-' | ForEach-Object { [byte]('0x' + $_) }
    $packet = ([byte[]](, 0xFF * 6 + $macBytes * 16))

    try {
        # Initialize and send UDP packet
        $udpClient = New-Object System.Net.Sockets.UdpClient
        $udpClient.Connect($broadcastAddress, $port)
        [void]$udpClient.Send($packet, $packet.Length)
        $udpClient.Close()

        # Log Successful WOL packet send
        if (Test-ExecutionContext -ConsoleCheck) {
            Add-LogMessage -message "WOL packet Successfully sent to $macAddress" -logLevel "Success" -logCorePath $logCorePath
        }
        else {
            Add-LogMessage -message "WOL packet Successfully sent to $macAddress" -logLevel "Success"
        }
        if (-not $Silent) {
            if (Test-ExecutionContext -ConsoleCheck) {
                Add-LogMessage -message "Wake-on-LAN packet sent to $macAddress" -logLevel "Info" -logCorePath $logCorePath
            }
            else {
                Add-LogMessage -message "Wake-on-LAN packet sent to $macAddress" -logLevel "Info"
            }          
        }
    }
    catch {
        # Log any Error encountered while sending WOL packet
        if (Test-ExecutionContext -ConsoleCheck) {
            Add-LogMessage -message "Error sending WOL packet to ${macAddress}: $_" -logLevel "Error" -logCorePath $logCorePath
        }
        else {
            Add-LogMessage -message "Error sending WOL packet to ${macAddress}: $_" -logLevel "Error"
        }
    }
}

write-host "Debug: Punto 5" -ForegroundColor Red
# Function to check if a host is online by verifying RPC port (135) availability in addition to ping
function Test-STHostUp {
    param (
        [string]$HostName,
        [bool]$UseDNS,
        [bool]$Silent
    )

    # Log that the host availability check is starting
    if (Test-ExecutionContext -ConsoleCheck) {
        Add-LogMessage -message "Checking host availability and RPC status for: $HostName" -logLevel "Info" -logCorePath $logCorePath
    }
    else {
        Add-LogMessage -message "Checking host availability and RPC status for: $HostName" -logLevel "Info"
    }
    
    # Initial ping test to verify basic connectivity before attempting RPC connection
    if (-not (Test-Connection -ComputerName $HostName -Count 1 -Quiet)) {
        # Log failure if ping test fails
        if (Test-ExecutionContext -ConsoleCheck) {
            Add-LogMessage -message "Ping failed for $HostName." -logLevel "Error" -logCorePath $logCorePath
        }
        else {
            Add-LogMessage -message "Ping failed for $HostName." -logLevel "Error"
        }
        return $false
    }

    try {
        if ($UseDNS) {
            # Resolve all IPv4 addresses for the host
            $ipv4Addresses = [System.Net.Dns]::GetHostAddresses($HostName) | Where-Object { $_.AddressFamily -eq 'InterNetwork' }
    
            # Check RPC connection on each IPv4 address until a valid one is found
            foreach ($ip in $ipv4Addresses) {
                try {
                    # Test the RPC connection on this IP
                    $rpcTest = Test-NetConnection -ComputerName $ip.IPAddressToString -Port 135 -ErrorAction Stop
                    if ($rpcTest.TcpTestSucceeded) {
                        if (Test-ExecutionContext -ConsoleCheck) {
                            Add-LogMessage -message "RPC check succeeded for IP $($ip.IPAddressToString) on host $HostName" -logLevel "Success" -logCorePath $logCorePath
                        }
                        else {
                            Add-LogMessage -message "RPC check succeeded for IP $($ip.IPAddressToString) on host $HostName" -logLevel "Success"
                        }
                        return $true
                    }
                }
                catch {
                    # If the connection fails on this IP, continue to the next one
                    if (Test-ExecutionContext -ConsoleCheck) {
                        Add-LogMessage -message "RPC check failed for IP $($ip.IPAddressToString) on host ${hostName}: $_" -logLevel "Warning" -logCorePath $logCorePath
                    }
                    else {
                        Add-LogMessage -message "RPC check failed for IP $($ip.IPAddressToString) on host ${hostName}: $_" -logLevel "Warning"
                    }
                    continue
                }
            }
    
            # If none of the IPs succeeded in allowing an RPC connection
            if (Test-ExecutionContext -ConsoleCheck) {
                Add-LogMessage -message "All RPC checks failed for host $HostName." -logLevel "Error" -logCorePath $logCorePath
            }
            else {
                Add-LogMessage -message "All RPC checks failed for host $HostName." -logLevel "Error"
            }
            return $false
        }
        else {
            # Direct RPC check without DNS resolution
            $tcpClient = New-Object System.Net.Sockets.TcpClient
            $tcpClient.Connect($HostName, 135)
            $tcpClient.Close()
            if (Test-ExecutionContext -ConsoleCheck) {
                Add-LogMessage -message "RPC check succeeded for $HostName" -logLevel "Success" -logCorePath $logCorePath
            }
            else {
                Add-LogMessage -message "RPC check succeeded for $HostName" -logLevel "Success"
            }
            return $true
        }
    }
    catch {
        # Log an Error if all RPC connection attempts fail
        if (Test-ExecutionContext -ConsoleCheck) {
            Add-LogMessage -message "RPC check failed for ${hostName}: $_" -logLevel "Error" -logCorePath $logCorePath
        }
        else {
            Add-LogMessage -message "RPC check failed for ${hostName}: $_" -logLevel "Error"
        }
        return $false
    }

    <# 
    # Commented code. Valid for a single network interface on hosts.
    try { 
        if ($UseDNS) {
            # Attempt DNS resolution to IPv4 address for the specified hostname
            $ipv4Address = [System.Net.Dns]::GetHostAddresses($HostName) | Where-Object { $_.AddressFamily -eq 'InterNetwork' }
            if (-not $ipv4Address) {
                write-host "Aquí si"
                # Log if DNS resolution fails
                if (Test-ExecutionContext -ConsoleCheck) {
                    Add-LogMessage -message "DNS resolution failed for host $HostName." -logLevel "Error" -logCorePath $logCorePath
                }
                else {
                    Add-LogMessage -message "DNS resolution failed for host $HostName." -logLevel "Error"
                }
                return $false
            }
            # Use Test-NetConnection to verify RPC port status on the resolved IPv4 address
            $rpcTest = Test-NetConnection -ComputerName $ipv4Address.IPAddressToString -Port 135 -ErrorAction Stop
            if ($rpcTest.TcpTestSucceeded) {
                Add-LogMessage -message "RPC check succeeded for $HostName" -logLevel "Success"
            }
            return $rpcTest.TcpTestSucceeded
        }
        else {
            # Direct RPC test without DNS resolution
            write-host "Degub start-hosts off dns"
            $tcpClient = New-Object System.Net.Sockets.TcpClient
            $tcpClient.Connect($HostName, 135)
            $tcpClient.Close()
            Add-LogMessage -message "RPC check succeeded for $HostName" -logLevel "Success"
            return $true
        }
    }
    catch {
        write-Host $UseDNS
        # Log Error if RPC connection test fails
        if (Test-ExecutionContext -ConsoleCheck) {
            Add-LogMessage -message "RPC check failed for ${hostName}: $_" -logLevel "Error" -logCorePath $logCorePath
        }
        else {
            Add-LogMessage -message "RPC check failed for ${hostName}: $_" -logLevel "Error"
        }
        return $false
    }
    #>
}

function Test-STWakeHost {
    param (
        [string]$HostName,
        [string]$macAddress,
        [bool]$UseDNS,
        [bool]$Silent
    )

    # Log initiation of the check to see if the host is already up
    if (Test-ExecutionContext -ConsoleCheck) {
        Add-LogMessage "Verifying if host $HostName is already up." -logLevel "Info" -logCorePath $logCorePath
    }
    else {
        Add-LogMessage "Verifying if host $HostName is already up." -logLevel "Info"
    }
    
    # First, check if the host is already up using Test-STHostUp; if it is, return "Success"
    if (Test-STHostUp -HostName $HostName -UseDNS:$UseDNS) {
        if (Test-ExecutionContext -ConsoleCheck) {
            Add-LogMessage "Host $HostName is already up." -logLevel "Info" -logCorePath $logCorePath
        }
        else {
            Add-LogMessage "Host $HostName is already up." -logLevel "Info"
        }
        return "Success"
    }
    
    # Log that the host appears to be down and will receive a WOL packet
    if (Test-ExecutionContext -ConsoleCheck) {
        Add-LogMessage "Host $HostName appears down; sending WOL packet." -logLevel "Info" -logCorePath $logCorePath
    }
    else {
        Add-LogMessage "Host $HostName appears down; sending WOL packet." -logLevel "Info"
    }
    
    # Send the WOL packet to the host's MAC address
    Send-STWOLPacket -macAddress $macAddress
    return "PendingVerification"  # Return status indicating further verification will be needed
}


# Main function to wake up hosts from a specified group or an individual host
function Invoke-STHostWakeup {
    param (
        [string]$GroupName,
        [string]$HostName = $null,
        [array]$HostsList = @(),
        [bool]$UseDNS,
        [bool]$Verbose,
        [bool]$Silent
    )

    # Log the initiation of the wake-up process
    Add-LogMessage -message "Host wake-up process initialized." -logLevel "Info"

    # Handle dynamic list of hosts
    if ($HostsList.Count -gt 0) {
        $GroupName = "temporaryGroupMac"
        New-TemporaryGroupMac -GroupName $GroupName -HostsList $HostsList
    }

    # Ensure MAC groups are loaded
    if (-not $Global:Config.hostsData.Macs.groupMac) {
        $Global:Config.hostsData.Macs.groupMac = @{}
        $Script:hostsMACHash = Get-HostsMacGroups
        if (-not $Script:hostsMACHash) {
            Add-LogMessage -functionName $MyInvocation.InvocationName `
                -message "Error: Failed to load MAC groups." -logLevel "Error"
            return
        }
    }

    $hostStatus = @() # Array to store the status results for each host

    # Handle group wake-up
    if ($GroupName) {
        if (-not $Global:Config.hostsData.Macs.groupMac.ContainsKey($GroupName)) {
            Add-LogMessage -functionName $MyInvocation.InvocationName -logLevel "Error" `
                -message "Group '$GroupName' does not exist in the loaded MAC groups."
            return
        }

        Add-LogMessage -message "Initiating wake-up process for group: $GroupName" -logLevel "Info"

        $hostsToCheck = $Global:Config.hostsData.Macs.groupMac[$GroupName]
        foreach ($hostEntry in $hostsToCheck) {
            try {
                $status = Test-STWakeHost -HostName $hostEntry.Name -macAddress $hostEntry.MAC -UseDNS:$UseDNS -Silent:$Silent
                $hostStatus += [pscustomobject]@{ Name = $hostEntry.Name; Status = $status }
            }
            catch {
                Add-LogMessage -message "Error processing host $($hostEntry.Name): $_" -logLevel "Error"
                $hostStatus += [pscustomobject]@{ Name = $hostEntry.Name; Status = "Error" }
            }
        }
    }

    # Handle single host wake-up
    if ($HostName) {
        Add-LogMessage -message "Initiating wake-up process for host: $HostName" -logLevel "Info"

        # Try to locate the host in all groups
        $targetHost = $null
        foreach ($group in $Global:Config.hostsData.Macs.groupMac.Values) {
            $targetHost = $group | Where-Object { $_.Name -eq $HostName }
            if ($targetHost) { break }
        }

        if (-not $targetHost) {
            Add-LogMessage -message "Error: Host '$HostName' not found in any configured groups." -logLevel "Error"
            return
        }

        try {
            $status = Test-STWakeHost -HostName $targetHost.Name -macAddress $targetHost.MAC -UseDNS:$UseDNS -Silent:$Silent
            $hostStatus += [pscustomobject]@{ Name = $targetHost.Name; Status = $status }
        }
        catch {
            Add-LogMessage -message "Error processing host ${hostName}: $_" -logLevel "Error"
            $hostStatus += [pscustomobject]@{ Name = $targetHost.Name; Status = "Error" }
        }
    }

    # Pause to allow time for hosts to wake up
    Start-Sleep -Seconds ($Global:Config.UserConfigData.HostSettings.recheckIntervalStart -or 60)

    # Verify each host that is pending verification
    foreach ($hostEntry in $hostStatus) {
        if ($hostEntry.Status -eq "PendingVerification") {
            Add-LogMessage -message "Re-verifying status for host $($hostEntry.Name)" -logLevel "Info"
            $hostEntry.Status = if (Test-STHostUp -HostName $hostEntry.Name -UseDNS:$UseDNS) { "Success" } else { "Failed" }
        }
    }

    Add-LogMessage -message "Host wake-up process completed." -logLevel "Info"
    return $hostStatus  # Return the results for each host processed
}

# Function to initiate the power-on process, handling either a group or a specific host
function Invoke-PowerOnHosts {
    param (
        [string]$GroupName = $null, # Optional: Group of hosts
        [string]$HostName = $null, # Optional: Specific host
        [array]$HostsList = @(),
        [bool]$UseDNS = $false,
        [bool]$Verbose = $false,
        [bool]$Silent = $false
    )

    # Log function start
    Add-LogMessage -functionName $MyInvocation.InvocationName -logLevel "Info" `
        -message "Starting Invoke-PowerOnHosts with parameters: groupName='$GroupName', hostName='$HostName', useDNS='$UseDNS'."

    # Handle dynamic list of hosts
    if ($HostsList.Count -gt 0) {
        $GroupName = "temporaryGroupMac"
        New-TemporaryGroupMac -GroupName $GroupName -HostsList $HostsList
    }

    # Ensure MAC groups are loaded
    if (-not $Global:Config.hostsData.Macs.groupMac) {
        $Global:Config.hostsData.Macs.groupMac = @{}
        $Script:hostsMACHash = Get-HostsMacGroups
        if (-not $Script:hostsMACHash) {
            Add-LogMessage -functionName $MyInvocation.InvocationName -logLevel "Error" `
                -message "Failed to load MAC groups. Ensure JSON data is correctly configured."
            return
        }
    }

    # Validate parameters
    if (-not $GroupName -and -not $HostName) {
        Add-LogMessage -functionName $MyInvocation.InvocationName -logLevel "Error" `
            -message "Both groupName and hostName are null. At least one must be specified."
        Show-Help -functionName "Start-Hosts"
        return
    }

    # Handle single host
    if ($HostName) {
        Add-LogMessage -functionName $MyInvocation.InvocationName -logLevel "Info" `
            -message "Initiating power-on process for host '$HostName'."

        $targetHost = $null
        foreach ($group in $Global:Config.hostsData.Macs.groupMac.Values) {
            $targetHost = $group | Where-Object { $_.Name -eq $HostName }
            if ($targetHost) { break }
        }

        if (-not $targetHost) {
            Add-LogMessage -functionName $MyInvocation.InvocationName -logLevel "Error" `
                -message "Host '$HostName' not found in any configured groups."
            return
        }

        try {
            $result = Invoke-STHostWakeup -HostName $HostName -UseDNS:$UseDNS -Silent:$Silent
            Add-LogMessage -functionName $MyInvocation.InvocationName -logLevel "Success" `
                -message "Successfully powered on host '$HostName'."
            return $result
        }
        catch {
            Add-LogMessage -functionName $MyInvocation.InvocationName -logLevel "Error" `
                -message "Failed to power on host '$HostName'. Error: $($_.Exception.Message)"
            return
        }
    }

    # Handle group of hosts
    if ($GroupName) {
        if (-not $Global:Config.hostsData.Macs.groupMac.ContainsKey($GroupName)) {
            Add-LogMessage -functionName $MyInvocation.InvocationName -logLevel "Error" `
                -message "Group '$GroupName' does not exist in the loaded MAC groups."
            return
        }

        Add-LogMessage -functionName $MyInvocation.InvocationName -logLevel "Info" `
            -message "Initiating power-on process for group '$GroupName'."

        try {
            $result = Invoke-STHostWakeup -GroupName $GroupName -UseDNS:$UseDNS -Silent:$Silent
            Add-LogMessage -functionName $MyInvocation.InvocationName -logLevel "Success" `
                -message "Successfully powered on group '$GroupName'."
            return $result
        }
        catch {
            Add-LogMessage -functionName $MyInvocation.InvocationName -logLevel "Error" `
                -message "Failed to power on group '$GroupName'. Error: $($_.Exception.Message)"
            return
        }
    }
}

# Public "wrapper" function that invokes `Invoke-ASCheck` to hide it in standalone mode.
# Avoids the use of aliases and allows the function to remain hidden when calling get-command.
function Start-Hosts {
    param (
        [string]$GroupName,
        [string]$HostName = $null,
        [array]$HostsList = @(),
        [bool]$UseDNS,
        [bool]$Verbose,
        [bool]$Silent
    )

    # Manejar la creación de un grupo temporal basado en hostsList
    if ($HostsList.Count -gt 0) {
        $GroupName = "temporaryGroupMac"
        New-TemporaryGroupMac -GroupName $GroupName -HostsList $HostsList
    }

    # Delegar a Invoke-PowerOnHosts
    Invoke-PowerOnHosts -GroupName $GroupName -HostName $HostName -Verbose:$Verbose -Silent:$Silent -UseDNS:$UseDNS
}

# Clean up old logs in standalone mode
if (Test-ExecutionContext -ConsoleCheck) {
    Remove-OldLogFiles -logDirectory $Global:Config.Paths.Log.Start -retainCount 10
}
write-host "Debug: Punto 6" -ForegroundColor Red

# Conditional export based on execution mode
if (Test-ExecutionContext -ConsoleCheck) {
    # In standalone mode, export only Start-Hosts and Show-Help
    Export-ModuleMember -Function Start-Hosts, Show-Help, Test-STHostUp
    write-host "Debug: Punto 7" -ForegroundColor Red
} else {
    # In integrated mode, export additional functions
    Export-ModuleMember -Function Start-Hosts, Invoke-PowerOnHosts, Test-STHostUp
    write-host "Debug: Punto Final" -ForegroundColor Red
}
