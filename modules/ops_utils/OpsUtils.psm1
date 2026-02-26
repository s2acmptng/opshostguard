# OpsUtils.psm1 [OpsHostGuard Module]

<#
    .SYNOPSIS
    Core module for managing and automating host groups and update processes within the OpsHostGuard framework.

    .DESCRIPTION
    This module provides a comprehensive set of functions for handling host group configurations, retrieving MAC 
    address groups, validating group and host memberships, creating internal host groups, and exporting update results. 
    It integrates with the global configuration and logging Systems, ensuring seamless operation and traceability 
    across the OpsHostGuard platform.

    1. **Group Management**:
       - Retrieves host groups and MAC address groups from JSON configuration files.
       - Validates group and host memberships within the defined configuration.
       - Creates new internal host groups dynamically, updating the global configuration.

    2. **Update Results Export**:
       - Processes and displays update and verification logs for hosts.
       - Formats update results into structured tables for console display.
       - Stores results in the global configuration for later access and reporting.

    3. **Logging Integration**:
       - Logs all operations and errors using the centralized logging System.
       - Supports various log levels, including Debug, Info, Warning, and Error.
       - Ensures traceability for all actions performed within the module.

    4. **Global Configuration**:
       - Utilizes `$Global:Config` for all path, file, and group configurations.
       - Ensures compatibility with OpsHostGuard's overarching configuration framework.

    .FUNCTIONS
    - `Get-HostsGroups`: Retrieves host groups from a JSON configuration file, optionally filtering by group name.
    - `Get-HostsMacGroups`: Retrieves MAC address groups from a JSON configuration file, optionally filtering by group name.
    - `Test-HostsGroups`: Validates the existence of a group or a host within the defined configuration.
    - `New-TemporaryGroup`: Creates a new internal host group and updates the global configuration.
    - `Export-UpdateResults`: Processes and displays update and verification results for hosts.

    .PARAMETERS
    - `groupName` (Get-HostsGroups, Get-HostsMacGroups, Test-HostsGroups): Specifies the name of the group to retrieve or validate.
    - `hostName` (Test-HostsGroups, New-TemporaryGroup): Specifies a host name for validation or inclusion in a group.
    - `hostsList` (New-TemporaryGroup): Specifies a list of hosts to include in a new internal group.
    - `resultUpdate` (Export-UpdateResults): A `PSCustomObject` containing update and verification logs.

    .EXAMPLES
    Retrieve all host groups:
    $allGroups = Get-HostsGroups

    Retrieve a specific host group by name:
    $group = Get-HostsGroups -GroupName "Debug"

    Validate the existence of a specific host:
    $result = Test-HostsGroups -HostName "localhost"

    Create a new internal group with a single host:
    $group = New-TemporaryGroup -HostName "localhost"

    Export and display update results:
    Export-UpdateResults -resultUpdate $updateResults

    .NOTES
    - The module depends on `$Global:Config` for global settings and `$Global:Config.InternalConfig` for file paths.
    - Logs all operations and errors using the centralized logging System.
    - Designed for use within the OpsHostGuard framework and its associated modules.

    .ORGANIZATION
    Developed for: Faculty of Documentation and Communication Sciences at the University of Extremadura.

    .AUTHOR [© 2024 Alberto Ledo]
    Alberto Ledo [Faculty of Documentation and Communication Sciences]
    IT Department: University of Extremadura - IT Services for Facilities
    Contact: albertoledo@unex.es

    .Copyright
    © 2024 Alberto Ledo

    .VERSION
    2.0.0

    .HISTORY
    2.0.0 - Optimized compatibility with the OpsHostGuard configuration framework.
    1.2.0 - Enhanced logging integration for debugging and diagnostics.
    1.1.0 - Added update results export functionality.
    1.0.0 - Initial release with group management functions.

    .USAGE
    This module is strictly for internal use within the University of Extremadura.
    It is designed to operate within the IT infrastructure and may not function as expected in other environments.

    .DATE
    November 21, 2024

    .DISCLAIMER
    This module is provided "as-is" and is intended for internal use at the University of Extremadura.
    No warranties, express or implied, are provided. Any modifications or adaptations are not covered
    under this disclaimer.

    .LINK
    https://github.com/n7rc/OpsHostGuard
#>
function Get-HostsGroups {
    param (
        [string]$GroupName  # Optional: specific group to retrieve
    )

    try {
        # Log the start of the function
        Add-LogMessage -functionName $MyInvocation.InvocationName -logLevel "Debug" `
            -message "Attempting to retrieve host groups. GroupName: $GroupName"

        # Ensure the global groups structure exists
        if (-not $Global:Config.hostsData.Groups) {
            $Global:Config.hostsData.Groups = @{
                groupName = @{}  # Initialize the groupName property as a hashtable
            }

            # Load static groups from JSON only once
            $groupsFilePath = Join-Path -Path $Global:Config.Paths.Config -ChildPath "host_groups.json"
            if (Test-Path -Path $groupsFilePath) {
                $jsonContent = Get-Content -Path $groupsFilePath -Raw | ConvertFrom-Json
                foreach ($property in $jsonContent.PSObject.Properties) {
                    $Global:Config.hostsData.Groups.GroupName[$property.Name] = @($property.Value)  # Convert to array explicitly
                }

                Add-LogMessage -functionName $MyInvocation.InvocationName -logLevel "Info" `
                    -message "Static groups loaded from JSON: $($jsonContent.PSObject.Properties.Name -join ', ')"
            } else {
                Add-LogMessage -functionName $MyInvocation.InvocationName -logLevel "Warning" `
                    -message "JSON groups file not found at $groupsFilePath. Static groups not loaded."
            }
        }

        # Access the combined groups from $Global:Config.hostsData.Groups.GroupName
        $allGroups = $Global:Config.hostsData.Groups.GroupName

        # If a specific group is requested
        if ($GroupName) {
            if ($allGroups.ContainsKey($GroupName)) {
                Add-LogMessage -functionName $MyInvocation.InvocationName -logLevel "Info" `
                    -message "Successfully retrieved group '$GroupName'."
                return @{ $GroupName = $allGroups[$GroupName] }
            } else {
                Add-LogMessage -functionName $MyInvocation.InvocationName -logLevel "Warning" `
                    -message "Group '$GroupName' not found."
                return $null
            }
        }

        # Return all groups if no specific group is requested
        Add-LogMessage -functionName $MyInvocation.InvocationName -logLevel "Success" `
            -message "Successfully retrieved all host groups."
        return $allGroups
    }
    catch {
        Add-LogMessage -functionName $MyInvocation.InvocationName -logLevel "Error" `
            -message "Failed to retrieve host groups: $($_.Exception.Message)"
        return $null
    }
}

<#
Function: Get-HostsGroups
.SYNOPSIS
Retrieves host groups from a JSON configuration file, either by specific group or all available groups.
.DESCRIPTION
This function loads host group data from a JSON file located in the configuration directory. 
It converts the data into a PowerShell `PSCustomObject` for structured access. If a group name 
is provided, the function returns only the hosts within that group. Otherwise, it returns all 
groups. The function also logs its operations for debugging and diagnostic purposes.
.PARAMETER groupName
(Optional) Specifies the name of the group to retrieve. If not provided, all groups are returned.
.OUTPUTS
A `PSCustomObject` containing:
- If a specific group is requested: A single property with the group name as the key and its hosts as the value.
- If no group name is provided: All groups with their corresponding hosts.
.EXAMPLE
Retrieve all host groups:
$allGroups = Get-HostsGroups
.EXAMPLE
Retrieve a specific host group by name:
$group = Get-HostsGroups -GroupName "Debug"
.NOTES
- The JSON file containing the host groups must be located in the configuration path defined by `$Global:Config.Paths.Config`.
- The function logs errors and successful retrievals to the System's logging mechanism.
- Returns `$null` if the specified group name is not found or if the file cannot be loaded.
- Designed for use within OpsHostGuard's configuration framework.

function Get-HostsGroups {
    param (
        [string]$GroupName  # Optional: specific group to retrieve
    )

    try {
        # Log the start of the function
        Add-LogMessage -functionName $MyInvocation.InvocationName -logLevel "Debug" `
            -message "Attempting to retrieve host groups. GroupName: $GroupName"

        # Build the path to the host groups JSON file
        $groupsFilePath = Join-Path -Path $Global:Config.Paths.Config -ChildPath "host_groups.json"
        if (-not (Test-Path -Path $groupsFilePath)) {
            Add-LogMessage -functionName $MyInvocation.InvocationName -logLevel "Error" `
                -message "Host groups file not found at $groupsFilePath."
            return $null
        }

        # Load JSON content and convert to PSObject for structured use
        $jsonContent = Get-Content -Path $groupsFilePath -Raw | ConvertFrom-Json
        $hostGroups = [PSCustomObject]@{}

        # Populate $hostGroups from the JSON content
        foreach ($property in $jsonContent.PSObject.Properties) {
            $hostGroups | Add-Member -MemberType NoteProperty -Name $property.Name -Value $property.Value
        }

        # Handle specific group retrieval
        if ($GroupName) {
            if ($hostGroups.PSObject.Properties.Name -contains $GroupName) {
                Add-LogMessage -functionName $MyInvocation.InvocationName -logLevel "Info" `
                    -message "Successfully retrieved group '$GroupName'."
                return [PSCustomObject]@{
                    $GroupName = $hostGroups.$GroupName
                }
            }
            else {
                Add-LogMessage -functionName $MyInvocation.InvocationName -logLevel "Warning" `
                    -message "Group '$GroupName' not found in host groups."
                return $null
            }
        }

        # Return all groups as a PSObject
        Add-LogMessage -functionName $MyInvocation.InvocationName -logLevel "Success" `
            -message "Successfully retrieved all host groups."
        return $hostGroups
    }
    catch {
        # Log any exceptions
        Add-LogMessage -functionName $MyInvocation.InvocationName -logLevel "Error" `
            -message "Failed to retrieve host groups: $($_.Exception.Message)"
        return $null
    }
}
#>

<#
Function: Get-HostsMacGroups
.SYNOPSIS
Retrieves host MAC address groups from a JSON configuration file, optionally filtering by a specific group name.
.DESCRIPTION
This function loads MAC address groups from a JSON file located in the configuration directory. 
The data is converted into a PowerShell `PSCustomObject` for structured access. If a group name is 
provided, the function retrieves only the hosts and their MAC addresses for that group. If no group 
name is provided, it returns all available groups and their respective hosts.
.PARAMETER groupName
(Optional) Specifies the name of the group to retrieve. If omitted, all groups are returned.
.OUTPUTS
A `PSCustomObject` containing:
- If a specific group is requested: A single property with the group name as the key and its hosts as the value.
- If no group name is provided: All groups with their corresponding hosts and MAC addresses.
.EXAMPLE
Retrieve all MAC address groups:
$allMacGroups = Get-HostsMacGroups
.EXAMPLE
Retrieve a specific MAC address group by name:
$macGroup = Get-HostsMacGroups -GroupName "Debug"
.NOTES
- The JSON file containing MAC address groups must be located in the path defined by `$Global:Config.InternalConfig.Files.JsonMacGroups`.
- Logs successful retrievals, warnings, and errors to the System's logging mechanism.
- Returns an empty object if the specified group name is not found or if the file cannot be loaded.
- Designed for use within OpsHostGuard's configuration and operational framework.

function Get-HostsMacGroups {
    param (
        [string]$GroupName  # Optional: specific group to retrieve hosts with MAC addresses from
    )

    # Retrieve the MAC groups file path from the global configuration
    $macGroupsFile = $Global:Config.InternalConfig.Files.JsonMacGroups  

    try {
        # Load the JSON data and convert it into a PowerShell object
        $macGroups = Get-Content -Path $macGroupsFile -Raw | ConvertFrom-Json

        # Convert JSON data into a PSCustomObject for structured access
        $hostsMACObject = [PSCustomObject]@{}
        #$hostsMACObject = @{}

        foreach ($property in $macGroups.PSObject.Properties) {
            $hostsMACObject | Add-Member -MemberType NoteProperty -Name $property.Name -Value $property.Value
        }

        # Log successful loading of MAC groups
        Add-LogMessage -functionName $MyInvocation.InvocationName `
            -message "Successfully loaded and converted MAC groups from $macGroupsFile." `
            -logLevel "Success"

        # If a specific group is requested, validate and return it as a PSCustomObject
        if ($GroupName) {
            if ($hostsMACObject.PSObject.Properties.Name -contains $GroupName) {
                # Log group retrieval
                Add-LogMessage -functionName $MyInvocation.InvocationName `
                    -message "Successfully retrieved MAC group '$GroupName'." `
                    -logLevel "Info"
                return [PSCustomObject]@{
                    $GroupName = $hostsMACObject.$GroupName
                }
            }
            else {
                # Log a warning if the group is not found
                Add-LogMessage -functionName $MyInvocation.InvocationName `
                    -message "MAC group '$GroupName' not found in $macGroupsFile." `
                    -logLevel "Warning"
                return [PSCustomObject]@{}
            }
        }

        # If no specific group is requested, return the entire MAC groups object
        Add-LogMessage -functionName $MyInvocation.InvocationName `
            -message "Returning all MAC groups." `
            -logLevel "Info"
        return $hostsMACObject
    }
    catch {
        # Log an error if JSON loading or conversion fails
        Add-LogMessage -functionName $MyInvocation.InvocationName `
            -message "Failed to load MAC groups from JSON file: $($_.Exception.Message)" `
            -logLevel "Error"
        return [PSCustomObject]@{}  # Return an empty PSCustomObject on error
    }
}
#>
function Get-HostsMacGroups {
    param (
        [string]$GroupName  # Optional: specific group to retrieve hosts with MAC addresses from
    )

    # Retrieve the MAC groups file path from the global configuration
    $macGroupsFile = $Global:Config.InternalConfig.Files.JsonMacGroups  

    try {
        # Load the JSON data and convert it into the $Global:Config.hostsData.Macs.groupMac structure if not already loaded
        if (-not $Global:Config.hostsData.Macs.groupMac) {
            $Global:Config.hostsData.Macs.groupMac = @{}
            $macGroups = Get-Content -Path $macGroupsFile -Raw | ConvertFrom-Json
            foreach ($property in $macGroups.PSObject.Properties) {
                $Global:Config.hostsData.Macs.groupMac[$property.Name] = $property.Value
            }
        }

        # Handle specific group request
        if ($GroupName) {
            if ($Global:Config.hostsData.Macs.groupMac.ContainsKey($GroupName)) {
                Add-LogMessage -functionName $MyInvocation.InvocationName `
                    -message "Successfully retrieved MAC group '$GroupName'." `
                    -logLevel "Info"
                return [PSCustomObject]@{
                    $GroupName = $Global:Config.hostsData.Macs.groupMac[$GroupName]
                }
            } else {
                Add-LogMessage -functionName $MyInvocation.InvocationName `
                    -message "MAC group '$GroupName' not found." `
                    -logLevel "Warning"
                return $null
            }
        }

        # Return all groups if no specific group is requested
        Add-LogMessage -functionName $MyInvocation.InvocationName `
            -message "Returning all MAC groups." `
            -logLevel "Info"
        return $Global:Config.hostsData.Macs.groupMac
    }
    catch {
        Add-LogMessage -functionName $MyInvocation.InvocationName `
            -message "Failed to load MAC groups from JSON file: $($_.Exception.Message)" `
            -logLevel "Error"
        return $null
    }
}

function Test-HostsGroups {
    param (
        [string]$GroupName,
        [string]$HostName,
        [string]$HelpFunction = "Show-Help",
        [array]$altGroupParam = $null
    )

    # Log the function call with parameters
    Add-LogMessage -functionName $MyInvocation.InvocationName -logLevel "Debug" `
        -message "Test-HostsGroups Parameters: GroupName='$GroupName', HostName='$HostName', AltGroupParam='$altGroupParam'"

    try {
        # Ensure the global groups structure exists
        if (-not $Global:Config.hostsData.Groups) {
            $Global:Config.hostsData.Groups = @{
                groupName = @{}  # Initialize the groupName property as a hashtable
            }

            # Load static groups from JSON only once
            $groupsFilePath = Join-Path -Path $Global:Config.Paths.Config -ChildPath "host_groups.json"
            if (Test-Path -Path $groupsFilePath) {
                $jsonContent = Get-Content -Path $groupsFilePath -Raw | ConvertFrom-Json
                foreach ($property in $jsonContent.PSObject.Properties) {
                    $Global:Config.hostsData.Groups.GroupName[$property.Name] = @($property.Value)  # Convert to array explicitly
                }

                Add-LogMessage -functionName $MyInvocation.InvocationName -logLevel "Info" `
                    -message "Static groups loaded from JSON: $($jsonContent.PSObject.Properties.Name -join ', ')"
            } else {
                Add-LogMessage -functionName $MyInvocation.InvocationName -logLevel "Warning" `
                    -message "JSON groups file not found at $groupsFilePath. Static groups not loaded."
            }
        }

        # Access the combined groups from $Global:Config.hostsData.Groups.GroupName
        $allGroups = $Global:Config.hostsData.Groups.GroupName

        # Validate groupName if provided
        if ($GroupName) {
            if ($allGroups.ContainsKey($GroupName)) {
                Add-LogMessage -functionName $MyInvocation.InvocationName -logLevel "Success" `
                    -message "Group '$GroupName' exists in the configuration."
                return $true
            } else {
                Add-LogMessage -functionName $MyInvocation.InvocationName -logLevel "Error" `
                    -message "Group '$GroupName' does not exist in the configuration."
                return $false
            }
        }

        # Validate hostName if provided
        if ($HostName) {
            $allHosts = $allGroups.Values | ForEach-Object { $_ } | Select-Object -Unique
            if ($allHosts -contains $HostName) {
                Add-LogMessage -functionName $MyInvocation.InvocationName -logLevel "Success" `
                    -message "Host '$HostName' exists in the configuration."
                return $true
            } else {
                Add-LogMessage -functionName $MyInvocation.InvocationName -logLevel "Warning" `
                    -message "Host '$HostName' does not exist in any group."
                return $false
            }
        }

        # Validate alternative group parameters if provided
        if ($altGroupParam -and $altGroupParam.Count -gt 0) {
            foreach ($altGroup in $altGroupParam) {
                if ($allGroups.ContainsKey($altGroup)) {
                    Add-LogMessage -functionName $MyInvocation.InvocationName -logLevel "Success" `
                        -message "Alternative group '$altGroup' exists in the configuration."
                    return $true
                }
            }

            Add-LogMessage -functionName $MyInvocation.InvocationName -logLevel "Error" `
                -message "None of the alternative groups provided exist in the configuration."
            return $false
        }

        # If no valid parameters are provided, show help and return false
        Add-LogMessage -functionName $MyInvocation.InvocationName -logLevel "Error" `
            -message "Invalid parameters. Either a group or a host must be provided."
        if (Test-ExecutionContext -ConsoleCheck) {
            & $HelpFunction
        }
        return $false
    }
    catch {
        # Log the exception details
        Add-LogMessage -functionName $MyInvocation.InvocationName -logLevel "Error" `
            -message "Failed to validate host groups: $($_.Exception.Message)"
        return $false
    }
}

<#
Function: Test-HostsGroups
.SYNOPSIS
Validates the existence of a host group or a specific host within the configured host groups.
.DESCRIPTION
This function checks the global configuration for defined host groups and validates whether a specified 
group or host exists. If a group name is provided, the function ensures that the group is defined. 
If a host name is provided, it checks if the host belongs to any group. Additionally, the function 
supports alternative parameters for group validation and can invoke a help function when invalid 
parameters are provided. Detailed logs are generated for all validation attempts.
.PARAMETER groupName
(Optional) Specifies the name of the group to validate. If not provided, the function relies on `hostName` 
or `altGroupParam` for validation.
.PARAMETER hostName
(Optional) Specifies the host to validate across all groups. If not provided, validation is based on 
`groupName` or `altGroupParam`.
.PARAMETER helpFunction
(Optional) Specifies the name of a help function to invoke when validation parameters are invalid. 
Defaults to `Show-Help`.
.PARAMETER altGroupParam
(Optional) An alternative parameter containing a list of group names to validate. Used when `groupName` 
and `hostName` are not provided.
.OUTPUTS
Returns `$true` if the validation succeeds, or `$false` if the validation fails due to missing or 
invalid parameters, or if the specified group or host does not exist.
.EXAMPLE
Validate the existence of a specific group:
$result = Test-HostsGroups -GroupName "Debug"
.EXAMPLE
Validate the existence of a specific host:
$result = Test-HostsGroups -HostName "localhost"
.EXAMPLE
Invoke the help function when invalid parameters are provided:
Test-HostsGroups -altGroupParam @() -HelpFunction "Show-Usage"
.NOTES
- The function relies on `$Global:Config.Groups` for group definitions. Ensure the global configuration 
  is initialized before calling this function.
- Logs all validation steps and outcomes for diagnostic purposes.
- Returns `$false` if no valid parameters are provided or if the validation fails.
- Designed for use within OpsHostGuard's configuration and validation framework.
#>

<#
Function: New-TemporaryGroup
.SYNOPSIS
Creates a new internal group in the global configuration, containing a single host or a list of hosts.
.DESCRIPTION
This function initializes a new internal group and stores it in the global configuration. The group can 
contain either a single hostname or a list of hosts. It ensures that the global configuration for groups 
exists and is properly structured as a `PSCustomObject`. Detailed logs are generated to trace the 
function's operations, including validation and error handling.
.PARAMETER hostName
(Optional) Specifies a single hostname to include in the group. If provided, it takes precedence over `hostsList`.
.PARAMETER hostsList
(Optional) Specifies a list of hostnames to include in the group. If `hostName` is also provided, this parameter is ignored.
.OUTPUTS
A `PSCustomObject` representing the created group, structured as:
- `internalGroup`: Contains an array of hostnames added to the group.
.EXAMPLE
Create a group with a single host:
$group = New-TemporaryGroup -HostName "localhost"
.EXAMPLE
Create a group with a list of hosts:
$group = New-TemporaryGroup -HostsList @("host1", "host2", "host3")
.EXAMPLE
Handle missing parameters gracefully:
$group = New-TemporaryGroup
# Logs a warning and returns `$null`.
.NOTES
- The function ensures the global configuration `$Global:Config.Groups` exists before adding the new group.
- Logs operations, including successful group creation and any errors encountered.
- Returns `$null` if no valid `hostName` or `hostsList` is provided.
- Designed for use within OpsHostGuard's configuration framework.
#>

function New-TemporaryGroup {
    param (
        [string]$GroupName, # Name of the group to create
        [array]$HostsList   # List of hosts to include in the group
    )

    try {
        # Validate input parameters
        if (-not $GroupName -or -not $HostsList) {
            throw "GroupName and HostsList are required parameters."
        }

        # Initialize the dynamic groups structure if not already initialized
        if (-not $Global:Config.hostsData.Groups.GroupName) {
            $Global:Config.hostsData.Groups.GroupName = @{}
        }

        # Assign the hosts list to the group name
        $Global:Config.hostsData.Groups.GroupName[$GroupName] = $HostsList

        # Log the creation of the group
        Add-LogMessage -functionName $MyInvocation.InvocationName -logLevel "Debug" `
            -message "Created group '$GroupName' with hosts: $($HostsList -join ', ')"

        # Validate the group creation
        if ($Global:Config.hostsData.Groups.GroupName[$GroupName] -is [array]) {
            Add-LogMessage -functionName $MyInvocation.InvocationName -logLevel "Info" `
                -message "Group '$GroupName' successfully created and contains: $($Global:Config.hostsData.Groups.GroupName[$GroupName] -join ', ')"
        } else {
            Add-LogMessage -functionName $MyInvocation.InvocationName -logLevel "Warning" `
                -message "Group '$GroupName' created but its content is not an array. Type: $($Global:Config.hostsData.Groups.GroupName[$GroupName].GetType())"
        }

        return $true
    }
    catch {
        Add-LogMessage -functionName $MyInvocation.InvocationName -logLevel "Error" `
            -message "Failed to create group '$GroupName': $($_.Exception.Message)"
        return $false
    }
}

function New-TemporaryGroupMac {
    param (
        [string]$GroupName, # Name of the group to create
        [array]$HostsList   # List of host names to include in the group
    )

    try {
        # Validar entrada
        if (-not $GroupName -or -not $HostsList) {
            throw "GroupName and HostsList are required parameters."
        }

        # Cargar el archivo JSON
        $macGroupsFile = $Global:Config.InternalConfig.Files.JsonMacGroups
        if (-not (Test-Path -Path $macGroupsFile)) {
            throw "The MAC groups JSON file '$macGroupsFile' does not exist."
        }

        $macGroups = Get-Content -Path $macGroupsFile -Raw | ConvertFrom-Json

        # Procesar los hosts de la lista
        $processedHosts = @()
        foreach ($HostName in $HostsList) {
            $foundHost = $null

            # Buscar el host en las propiedades del JSON
            foreach ($group in $macGroups.PSObject.Properties) {
                $foundHost = $group.Value | Where-Object { $_.Name -eq $HostName }
                if ($foundHost) { break }
            }

            if ($foundHost) {
                $processedHosts += $foundHost
            } else {
                Add-LogMessage -functionName $MyInvocation.InvocationName -logLevel "Warning" `
                    -message "Host '$HostName' not found in the MAC groups JSON. Ignoring."
            }
        }

        # Validar que se encontraron hosts válidos
        if ($processedHosts.Count -eq 0) {
            throw "No valid hosts found in the MAC groups JSON for the provided hostsList."
        }

        # Inicializar la estructura dinámica si no existe
        if (-not $Global:Config.hostsData.Macs.groupMac) {
            $Global:Config.hostsData.Macs.groupMac = @{ }
        }

        # Asignar los hosts procesados al grupo temporal
        $Global:Config.hostsData.Macs.groupMac[$GroupName] = $processedHosts

        # Log de nombres de hosts procesados
        $HostNames = $processedHosts | ForEach-Object { $_.Name } | Where-Object { $_ }
        Add-LogMessage -functionName $MyInvocation.InvocationName -logLevel "Info" `
            -message "Created MAC group '$GroupName' with hosts: $($HostNames -join ', ')"

        return $true
    }
    catch {
        Add-LogMessage -functionName $MyInvocation.InvocationName -logLevel "Error" `
            -message "Failed to create MAC group '$GroupName': $($_.Exception.Message)"
        return $false
    }
}

# Function to shut down hosts and handle logs for shutdown failures and in-session hosts
function Stop-MGHosts {
    param (
        [string]$GroupName, # All hosts to shut down
        [array]$successfulHosts,
        [bool]$Verbose,
        [bool]$Silent 
    )
    
    $failedShutdowns = @()  # Array to store hosts that failed to shut down
    $hostsInSession = @()   # Array to store hosts with active sessions

    # Verify if there are hosts to shut down
    #if (@($effectiveGroupName).Count -gt 0) {
    #if ($effectiveGroupName) {
        Add-LogMessage -logLevel "" -functionName $MyInvocation.InvocationName -message "Shutting down hosts in the group..."
        try {
            $shutdownResult = Invoke-STHHostShutdown -GroupName $GroupName -Verbose:$Verbose -Silent:$Silent
            
            # Process each shutdown result entry
            foreach ($hostEntry in $shutdownResult) {
                if ($hostEntry.Status -ne "Success") {
                    Add-LogMessage -logLevel "" -functionName $MyInvocation.InvocationName -message "Shutdown failed for host: $($hostEntry.Name)"
                    if ($successfulHosts -contains $hostEntry.Name) {
                        # Add to the list of shutdown failures
                        $failedShutdowns += New-Object PSObject -Property @{
                            HostName  = $hostEntry.Name
                            Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                            Status    = "Shutdown Failed"
                        }
                    }
                }
                elseif ($hostEntry.HasSessionActive) {
                    # Condition to detect active sessions
                    Add-LogMessage -logLevel "" -functionName $MyInvocation.InvocationName -message "Host $($hostEntry.Name) has an active session. Skipping shutdown."
                    $hostsInSession += "Host in Session"
                }
                else {
                    Add-LogMessage -logLevel "" -functionName $MyInvocation.InvocationName -message "Shutdown succeeded for host: $($hostEntry.Name)"
                }
            }
        }
        catch {
            if (-not $Silent) {
                Add-LogMessage -logLevel "" -functionName $MyInvocation.InvocationName -message "Error executing Invoke-HostShutdown: $_" -ForegroundColor Red 
            }
        }
    #}
    #else {
    #    Add-LogMessage -logLevel "" -functionName $MyInvocation.InvocationName -message "No hosts to shutdown."
    #}

    # Return the results of shutdown failures and hosts in session
    return @($failedShutdowns, $hostsInSession)
}

Export-ModuleMember -Function Get-HostsGroups, Get-HostsMacGroups, Test-HostsGroups, New-TemporaryGroup, New-TemporaryGroupMac, Stop-MGHosts
