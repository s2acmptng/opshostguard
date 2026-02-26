# OpsInit.psm1 [OpsHostGuard - Initialization and Core Configuration Module]

<# 
    .SYNOPSIS
    Core initialization and management module for the OpsHostGuard System, enabling dynamic configuration, dependency management,
    standalone module initialization, and plugin handling.
    
    .DESCRIPTION
This script acts as the foundation for initializing and managing the OpsHostGuard application by:
- Setting up and validating global configurations.
- Managing critical files, paths, and dependencies.
- Handling standalone module initialization.
- Importing and registering plugins dynamically.
- Ensuring secure credential management for PS Remoting and dashboard access.

It provides robust error handling, logging, and modular extensibility to accommodate different operational contexts, including:
- Full integration with OpsHostGuard's centralized dashboard.
- Standalone mode for isolated module operation.

**Core Responsibilities:**
1. **Configuration Initialization:**
   - Establishes global configurations using user-defined parameters, JSON files, and default values.
   - Verifies the existence of critical directories and files required for smooth operation.

2. **Module and Plugin Management:**
   - Dynamically imports modules and plugins based on priority and configuration files.
   - Registers and validates plugins from a designated directory structure.

3. **Standalone Mode Support:**
   - Allows individual core modules to operate independently, ensuring their required dependencies and configurations are initialized.

4. **Credential Management:**
   - Handles secure storage and retrieval of credentials for PS Remoting, database access, and dashboard logins.
   - Initializes encrypted credentials for secure operations across the application.

5. **Logging and Error Handling:**
   - Utilizes a standardized logging framework to provide detailed insights into System behavior.
   - Captures critical errors, warnings, and debug messages for effective troubleshooting.

.CMDLET NAMING CONVENTION
Cmdlets and functions in this module adhere to the standardized naming convention:
- `Verb-(ID-Module)Action`, where:
    - **Verb** indicates the action performed.
    - **ID-Module** specifies the context or module scope.
    - **Action** describes the operation.

Examples:
- `Initialize-Configuration`: Sets up the global configuration.
- `Import-Plugins`: Dynamically imports plugins from the configuration.

.EXAMPLE
.\OpsHostGuard.ps1
Initializes the OpsHostGuard System, including loading configuration files, importing modules, and detecting plugins.

.EXAMPLE
.\OpsHostGuard.ps1 -StandaloneMode
Runs the script in standalone mode, enabling individual core modules to initialize and operate independently.

.PARAMETER ModuleName
Specifies the name of the module to be initialized in standalone mode.

.PARAMETER coreDependencies
An array of core dependencies required for the specified module. Dependencies include the module name, path, and priority.

.NOTES
- Requires administrative privileges for some operations.
- Configurations are loaded dynamically from JSON files and validated against predefined default structures.
- Logging is centralized, ensuring all operations are traceable and errors are clearly reported.
- Ensures secure credential management using PowerShell's SecureString mechanism.

.ORGANIZATION
Developed for: Faculty of Documentation and Communication Sciences at the University of Extremadura.

.AUTHOR [© 2024 Alberto Ledo]
Alberto Ledo [Faculty of Documentation and Communication Sciences] - with assistance from OpenAI
IT Department: University of Extremadura - IT Services for Facilities
Contact: albertoledo@unex.es

.Copyright
© 2024 Alberto Ledo

.VERSION
3.0.0

.HISTORY
3.0.0 - Transition to PSObject-based global configuration for extensibility and compatibility.
2.5.0 - Enhanced logging framework and credential management.
2.0.0 - Introduced dynamic plugin detection and registration.
1.0.0 - Initial core module for OpsHostGuard.

.USAGE
This script is designed for internal use within the IT infrastructure of the University of Extremadura and may not function 
correctly in external environments without modifications.

.DISCLAIMER
This script is provided "as-is" and is intended solely for use at the University of Extremadura. 
No warranties, express or implied, are provided. Modifications to the script are not covered under this disclaimer.

.LINK
https://github.com/n7rc/OpsHostGuard

#>

<#
#Requires -Module OpsVar
#Requires -Module LogManager
#>


if ($Global:ProjectRoot) {
    $Script:ProjectRoot = $Global:ProjectRoot
}
else {
    try {
        if ($null -ne $PSScriptRoot -and $PSScriptRoot -ne "") {
            # $PSScriptRoot is available (executing as a module or script)
            $Script:ProjectRoot = (Resolve-Path -Path (Join-Path -Path $PSScriptRoot -ChildPath "../../../")).Path
        }
        else {
            # $PSScriptRoot is not available (imported from console)
            $scriptDirectory = (Get-Item -Path $MyInvocation.MyCommand.Definition).DirectoryName
            $Script:ProjectRoot = (Resolve-Path -Path (Join-Path -Path $scriptDirectory -ChildPath "../../../")).Path
        }
    }
    catch {
        Write-Host "[Warning] Failed to resolve ProjectRoot dynamically. Error: $_" -ForegroundColor Red
        throw
    }
}

# Dependencies tracker for dynamic imports
$Script:Dependencies = @()

# Load OpsVar module

$opsVarPath = Join-Path -Path $Script:ProjectRoot -ChildPath "modules/core/system/OpsVar.psd1"
   
Import-Module -Name $opsVarPath -Scope Global -Force -ErrorAction Stop
if (-not $Global:ProjectRoot) {
    Initialize-ProjectRoot
}

if ($Global:ProjectRoot) {
    $Script:ProjectRoot = $Global:ProjectRoot
}

if (-not $Global:Config.Paths) {
    Initialize-Paths
}
if (-not $Global:Config.InternalConfig) {
    Initialize-ConfigVar
}

if (-not $Global:Config.Paths) {
    throw "Critical Error: OpsVar did not initialize Paths."
}
# Validate essential keys in Config.Paths
if (-not $Global:Config.Paths.Log -or -not $Global:Config.Paths.Log.Root) {
    throw "Critical Error: Missing required log paths in OpsVar."
}

$Global:FallbackLogPath = Join-Path -Path $Global:Config.Paths.Log.Root -ChildPath "fallback-log.log"

# Import the LogManager module globally with Error handling
$logManagerPath = Join-Path -Path  $Global:Config.Paths.Modules.System -ChildPath "LogManager.psd1"

$opsLogManager = Get-Module -Name LogManager
if (-not $opsLogManager) {
    Import-ModuleOps -ModuleName "LogManager" -ModulePath $logManagerPath
}

Add-LogMessage -message "Starting OpsHostGuard..." -functionName $MyInvocation.InvocationName -logLevel "Info"
Add-LogMessage -message "Routes and Logs initialization completed." -functionName $MyInvocation.InvocationName -logLevel "Info"

<#
$Script:nonCriticalDirs
Purpose: This array lists the non-critical directories in the application environment. 
If these directories are missing during the validation process, execution will not halt, 
but warnings will be logged. These directories typically house optional components or 
features that do not impact core functionality.
#>
$Script:nonCriticalDirs = @(
    $Global:Config.Paths.Dashboard.Root,
    $Global:Config.Paths.Data.Root,
    $Global:Config.Paths.Log.Root,
    $Global:Config.Paths.Man,
    $Global:Config.Paths.Modules.Plugins,
    $Global:Config.Paths.Setup
)

<#
$Script:criticalSourceFiles
Purpose: This hashtable maps critical files required for the application to function correctly 
to their respective paths. These files are validated during initialization, and execution halts 
if any of them are missing or invalid. The keys represent logical file identifiers, while the 
values contain the full paths to the corresponding files.
#>
$Script:criticalSourceFiles = @{
    "JsonUserConfig"       = Join-Path -Path $Global:ProjectRoot -ChildPath "config/user_config.json"
    "JsonOpsConfig"        = Join-Path -Path $Global:ProjectRoot -ChildPath "config/ops_config.json"
    "JsonHostsGroups"      = Join-Path -Path $Global:ProjectRoot -ChildPath "config/host_groups.json"
    "JsonMacGroups"        = Join-Path -Path $Global:ProjectRoot -ChildPath "config/hosts_mac.json"
    "PsRemotingCredential" = Join-Path -Path $Global:ProjectRoot -ChildPath "modules/security/credentials/ps_remoting.xml"
    "UserDatabase"         = Join-Path -Path $Global:ProjectRoot -ChildPath "modules/security/credentials/user_db.xml"
    "PasswdDatabase"       = Join-Path -Path $Global:ProjectRoot -ChildPath "modules/security/credentials/passwd_db.xml"
}

# Function to verify critical directories and files
function Test-SourcePathsAndFiles {
    param (
        [hashtable]$CriticalFiles
    )
    Add-LogMessage -message "Starting validation of source paths and files." -functionName $MyInvocation.InvocationName -logLevel "Info"

    # Step 1: Verify the existence of all directories in $Global:Config.Paths.
    # The following function automatically adapts to changes in $Global:Config.Paths.
    function Validate-Paths {
        Add-LogMessage -message "Starting validation of all directories in Config.Paths." -functionName $MyInvocation.InvocationName -logLevel "Info"

        # Recursive function to extract all directories from nested PSCustomObject structures
        function Extract-Paths {
            param ([PSCustomObject]$object)
            $paths = @()

            foreach ($key in $object.PSObject.Properties) {
                $value = $object.$key

                if ($value -is [PSCustomObject]) {
                    # Recursively extract paths from nested objects
                    $paths += Extract-Paths -object $value
                }
                elseif ($value -is [string] -and (Test-Path -Path $value -PathType Container)) {
                    # Add valid directory paths
                    $paths += $value
                }
            }

            return $paths
        }

        # Extract all paths from $Global:Config.Paths
        $allDirs = Extract-Paths -object $Global:Config.Paths

        # Validate the existence of each directory
        foreach ($dir in $allDirs) {
            try {
                if (-not (Test-Path -Path $dir -PathType Container)) {
                    if ($dir -in $Script:nonCriticalDirs) {
                        # Log warning for non-critical directories
                        Add-LogMessage -message "Non-critical directory missing: $dir. Some features may not work." -functionName $MyInvocation.InvocationName -logLevel "Warning"
                    }
                    else {
                        # Log error for critical directories and throw exception
                        Add-LogMessage -message "Missing critical directory: $dir" -functionName $MyInvocation.InvocationName -logLevel "Error"
                        throw "Critical directory '$dir' is missing."
                    }
                }
                else {
                    Add-LogMessage -message "Verified directory: $dir" -functionName $MyInvocation.InvocationName -logLevel "Debug"
                }
            }
            catch {
                Add-LogMessage -message "Error validating directory ${dir}: $($_.Exception.Message)" -functionName $MyInvocation.InvocationName -logLevel "Error"
                if ($dir -notin $Script:nonCriticalDirs) {
                    throw
                }
            }
        }

        Add-LogMessage -message "Directory validation completed successfully." -functionName $MyInvocation.InvocationName -logLevel "Success"
    }

    # Step 2: Verify the existence of critical files
    # Critical file keys as defined in $criticalSourceFiles

    # Loop through each file in the CriticalFiles hashtable
    foreach ($fileKey in $CriticalFiles.Keys) {
        $filePath = $CriticalFiles[$fileKey]

        try {
            # Validate file path
            if (-not $filePath -or -not ($filePath -is [string])) {
                Add-LogMessage -message "Invalid file entry for ${fileKey}: $filePath" -functionName $MyInvocation.InvocationName -logLevel "Error"
                throw "Critical file entry for '$fileKey' is invalid."
            }

            # Resolve and check existence
            $resolvedPath = Resolve-Path -Path $filePath -ErrorAction SilentlyContinue
            if (-not $resolvedPath -or -not (Test-Path -Path $resolvedPath)) {
                Add-LogMessage -message "Critical file not found: $filePath" -functionName $MyInvocation.InvocationName -logLevel "Error"
                throw "Critical file '$filePath' is missing."
            }

            # Log success
            Add-LogMessage -message "Verified existence of critical file: $resolvedPath" -functionName $MyInvocation.InvocationName -logLevel "Debug"
        }
        catch {
            Add-LogMessage -message "Error validating critical file ${fileKey}: $($_.Exception.Message)" -functionName $MyInvocation.InvocationName -logLevel "Error"
            throw
        }
    }

    Add-LogMessage -message "Validation of source paths and files completed successfully." -functionName $MyInvocation.InvocationName -logLevel "Success"
}

# Load data into UserConfigData

function Initialize-InternalConfig {
    param (
        [string]$opsConfigPath = $(Join-Path -Path $Global:Config.Paths.Config -ChildPath "ops_config.json")
    )

    Add-LogMessage -message "Starting initialization of InternalConfig" -functionName $MyInvocation.InvocationName -logLevel "Info"

    try {
        # Validate if the ops_config.json file exists
        if (-not (Test-Path -Path $opsConfigPath)) {
            Add-LogMessage -message "Ops configuration file not found at path: $opsConfigPath." -functionName $MyInvocation.InvocationName -logLevel "Error"
            throw "Ops configuration file is missing."
        }

        # Read the content of the JSON file and convert it to a PowerShell object
        $jsonContent = Get-Content -Path $opsConfigPath -Raw | ConvertFrom-Json

        # Map JSON properties to the corresponding properties in InternalConfig
        # Assign configuration metadata
        $Global:Config.InternalConfig.Config = $jsonContent.Config

        # Assign file paths (e.g., logs, JSON configuration files)
        $Global:Config.InternalConfig.Files = $jsonContent.Files

        # Assign core log paths for standalone modules
        $Global:Config.InternalConfig.LogCore = $jsonContent.LogCore

        # Assign module definitions and priorities
        $Global:Config.InternalConfig.Modules = $jsonContent.Modules

        # Assign plugin paths for additional features
        $Global:Config.InternalConfig.Plugins = $jsonContent.Plugins

        Add-LogMessage -message "InternalConfig initialized successfully." -functionName $MyInvocation.InvocationName -logLevel "Success"
    }
    catch {
        # Log any error that occurs during initialization
        Add-LogMessage -message "Error initializing InternalConfig: $($_.Exception.Message)" -functionName $MyInvocation.InvocationName -logLevel "Error"
        throw $_.Exception
    }
}

# Load data into UserConfigData
function Initialize-UserConfigData {
    param (
        [string]$UserConfigPath = $(Join-Path -Path $Global:Config.Paths.Config -ChildPath "user_config.json")
    )

    Add-LogMessage -message "Starting initialization of UserConfigData" -functionName $MyInvocation.InvocationName -logLevel "Info"

    try {
        # Step 1: Validate the existence of the user_config.json file
        if (-not (Test-Path -Path $UserConfigPath)) {
            Add-LogMessage -message "User configuration file not found at path: $UserConfigPath." -functionName $MyInvocation.InvocationName -logLevel "Error"
            throw "User configuration file is missing."
        }

        # Step 2: Read the content of the JSON file and convert it into a PowerShell object
        $jsonContent = Get-Content -Path $UserConfigPath -Raw | ConvertFrom-Json

        # Step 3: Map JSON properties to corresponding properties in UserConfigData
        # Assign general settings
        $Global:Config.UserConfigData.Settings = $jsonContent.Settings

        # Assign host settings
        $Global:Config.UserConfigData.HostSettings = $jsonContent.HostSettings

        # Assign network settings
        $Global:Config.UserConfigData.NetworkSettings = $jsonContent.NetworkSettings

        # Assign dashboard settings
        $Global:Config.UserConfigData.DashboardSettings = $jsonContent.DashboardSettings

        # Assign session configuration
        $Global:Config.UserConfigData.SessionConfig = $jsonContent.SessionConfig

        # Assign GPO configuration
        $Global:Config.UserConfigData.GPOConfiguration = $jsonContent.GPOConfiguration

        # Assign database connection details
        $Global:Config.UserConfigData.DatabaseConnection = $jsonContent.DatabaseConnection

        # Assign HTML report metadata
        $Global:Config.UserConfigData.HTMLReport = $jsonContent.HTMLReport

        # Assign email notification settings
        $Global:Config.UserConfigData.EmailNotification = $jsonContent.EmailNotification

        Add-LogMessage -message "UserConfigData initialized successfully." -functionName $MyInvocation.InvocationName -logLevel "Success"
    }
    catch {
        # Log any error that occurs during initialization
        Add-LogMessage -message "Error initializing UserConfigData: $($_.Exception.Message)" -functionName $MyInvocation.InvocationName -logLevel "Error"
        throw $_.Exception
    }
}

# Load data into HostData
function Initialize-HostsData {
    param (
        [string]$GroupsJsonPath = $(Join-Path -Path $Global:Config.Paths.Config -ChildPath "host_groups.json"),
        [string]$MacsJsonPath = $(Join-Path -Path $Global:Config.Paths.Config -ChildPath "hosts_mac.json")
    )

    Add-LogMessage -message "Initializing HostData..." -functionName $MyInvocation.InvocationName -logLevel "Info"

    # Initialize HostData
    try {
        # Load Groups data
        if (Test-Path -Path $GroupsJsonPath) {
            # Read and convert JSON file
            $groupsData = Get-Content -Path $GroupsJsonPath -Raw | ConvertFrom-Json
            # Ensure groupName is initialized as a hashtable
            $Global:Config.HostsData.Groups.GroupName = @{}
        
            # Populate groupName from JSON
            foreach ($group in $groupsData.PSObject.Properties) {
                # $group.Name is the group name (e.g., "Debug")
                # $group.Value is the array of hosts (e.g., ["localhost", "i2-ca-29", ...])
                $Global:Config.HostsData.Groups.GroupName[$group.Name] = $group.Value
            }
       
            Add-LogMessage -message "Groups data successfully loaded from: $GroupsJsonPath" -functionName $MyInvocation.InvocationName -logLevel "Success"
        }
        else {
            Add-LogMessage -message "Groups JSON file not found: $GroupsJsonPath" -functionName $MyInvocation.InvocationName -logLevel "Warning"
        }

        # Load MACs data
        if (Test-Path -Path $MacsJsonPath) {
            $macsData = Get-Content -Path $MacsJsonPath -Raw | ConvertFrom-Json
            $Global:Config.HostsData.Macs.groupMac = @{}
            
            foreach ($group in $macsData.PSObject.Properties) {
                # Initialize an empty array for each group
                $Global:Config.HostsData.Macs.groupMac[$group.Name] = @()
        
                # Add hosts to the group
                foreach ($item in $group.Value) {
                    $Global:Config.HostsData.Macs.groupMac[$group.Name] += @{
                        Name = $item.Name
                        MAC  = $item.MAC
                    }
                }
            }
            Add-LogMessage -message "MACs data successfully loaded from: $MacsJsonPath" -functionName $MyInvocation.InvocationName -logLevel "Success"
        }
        else {
            Add-LogMessage -message "MACs JSON file not found: $MacsJsonPath" -functionName $MyInvocation.InvocationName -logLevel "Warning"
        }
    }
    catch {
        Add-LogMessage -message "Error initializing HostData: $($_.Exception.Message)" -functionName $MyInvocation.InvocationName -logLevel "Error"
        throw
    }
}
# Load data into Security
function Initialize-SecurityData {
    param (
        [string]$opsConfigPath = $(Join-Path -Path $Global:Config.Paths.Config -ChildPath "ops_config.json")
    )

    Add-LogMessage -message "Starting initialization of Security Data" -functionName $MyInvocation.InvocationName -logLevel "Info"

    try {
        # Validate if the ops_config.json file exists
        if (-not (Test-Path -Path $opsConfigPath)) {
            Add-LogMessage -message "Ops configuration file not found at path: $opsConfigPath." -functionName $MyInvocation.InvocationName -logLevel "Error"
            throw "Ops configuration file is missing."
        }

        # Read the content of the JSON file and convert it to a PowerShell object
        $jsonContent = Get-Content -Path $opsConfigPath -Raw | ConvertFrom-Json

        # Map JSON properties to the corresponding properties in InternalConfig
       
        # Assign plugin paths for additional features
        $Global:Config.Security.Files = $jsonContent.Security

        Add-LogMessage -message "Security Data initialized successfully." -functionName $MyInvocation.InvocationName -logLevel "Success"
    }
    catch {
        # Log any error that occurs during initialization
        Add-LogMessage -message "Error initializing Security Data: $($_.Exception.Message)" -functionName $MyInvocation.InvocationName -logLevel "Error"
        throw $_.Exception
    }
}



# Function to initialize modules from the configuration
function Initialize-Modules {
    Add-LogMessage -message "Starting Initialize-Modules" -functionName $MyInvocation.InvocationName -logLevel "Info"

    # Define the configuration JSON file path
    $configFilePath = Join-Path -Path $Global:Config.Paths.Config -ChildPath "ops_config.json"

    # Load the JSON configuration
    try {
        $configData = Get-Content -Path $configFilePath -Raw | ConvertFrom-Json
        Add-LogMessage -message "Configuration file loaded successfully from $configFilePath." -functionName $MyInvocation.InvocationName -logLevel "Info"
    }
    catch {
        Add-LogMessage -message "Failed to load module configuration file: $($_.Exception.Message)" -functionName $MyInvocation.InvocationName -logLevel "Error"
        throw "Error loading module configuration file: $configFilePath"
    }

    # Initialize $Global:Config.InternalConfig.Modules if not already defined
    if (-not ($Global:Config.InternalConfig.Modules -is [PSCustomObject])) {
        $Global:Config.InternalConfig.Modules = [PSCustomObject]@{}
        Add-LogMessage -message "Initialized Modules as a PSObject in Global:Config.InternalConfig." -functionName $MyInvocation.InvocationName -logLevel "Debug"
    }

    # Process modules from the configuration
    foreach ($module in $configData.Modules) {
        try {
            $moduleName = $module.Name
            $modulePath = if (-not (Test-Path -Path $module.Path -PathType Container)) {
                Join-Path -Path $Global:Config.Paths.Root -ChildPath $module.Path
            }
            else {
                $module.Path
            }
            $modulePriority = $module.Priority
    
            # Add module as a nested PSCustomObject
            if (-not ($Global:Config.InternalConfig.Modules.PSObject.Properties.Name -contains $moduleName)) {
                $Global:Config.InternalConfig.Modules | Add-Member -MemberType NoteProperty -Name $moduleName -Value ([PSCustomObject]@{
                        Path     = $modulePath
                        Priority = $modulePriority
                    }) -Force
                Add-LogMessage -message "Added module: $moduleName with path $modulePath and priority $modulePriority" -functionName $MyInvocation.InvocationName -logLevel "Info"
            }
            else {
                throw "Module '$moduleName' already exists in InternalConfig.Modules during initialization. This should not happen."
            }
        }
        catch {
            Add-LogMessage -message "Error adding module $moduleName. Exception: $($_.Exception.Message)" -functionName $MyInvocation.InvocationName -logLevel "Error"
            throw "Failed to add module $moduleName with path $modulePath"
        }
    }

    Add-LogMessage -message "Completed Initialize-Modules Successfully" -functionName $MyInvocation.InvocationName -logLevel "Success"
}

<#
$Script:LoadedModules
Purpose: This array contains the names of modules that should be excluded from the import process
during the module initialization phase. These modules are considered already loaded as they are 
critical to the core functionality of the application and are imported earlier in the execution.
Adding a module to this list ensures it won't be re-imported or removed unnecessarily.
#>
$Script:LoadedModules = @(
    'OpsVar', 
    'OpsInit', 
    'LogManager',
    'OpsBase'
)

<#
$Script:ExcludedModules
Purpose: This array defines the list of modules that are excluded from the unloading process 
during the module import phase. These modules are critical to the application's operation 
and must remain loaded throughout the execution. 
By maintaining a centralized list, the exclusion logic becomes more manageable and 
maintainable, avoiding hard-coded conditions in the import function. Adding a module 
to this list ensures it will not be unloaded or re-imported unnecessarily, preserving 
the application's stability and reducing potential errors caused by dependency issues.
#>

if($Global:StandaloneMode){
$Script:ExcludedModules = @(
    'OpsUtils'
)
}else{
    $Script:ExcludedModules = @()
}

function Import-Modules {
    param (
        [array]$dependencies = $null
    )

    Add-LogMessage -message "Starting module import process..." -functionName $MyInvocation.InvocationName -logLevel "Info"

    # Retrieve dependencies from $Global:Config if not explicitly provided
    if (-not $dependencies) {
        if (-not ($Global:Config.InternalConfig.Modules -is [PSCustomObject])) {
            Add-LogMessage -message "Modules configuration is not properly initialized." -functionName $MyInvocation.InvocationName -logLevel "Error"
            throw "Critical Error: Modules configuration is not a PSCustomObject."
        }

        # Convert PSObject modules to array
        $dependencies = $Global:Config.InternalConfig.Modules.PSObject.Properties | ForEach-Object {
            [PSCustomObject]@{
                Name     = $_.Name
                Path     = $_.Value.Path
                Priority = $_.Value.Priority
            }
        } | Where-Object { $_.Name -and $_.Path -and $_.Priority -is [int] }
    }

    # Log raw dependencies
    Add-LogMessage -message "Raw dependencies: $($dependencies | Out-String)" -functionName $MyInvocation.InvocationName -logLevel "Debug"

    # Exclude specific modules
    $dependencies = $dependencies | Where-Object { $_.Name -notin $Script:LoadedModules }

    # Validate and filter dependencies
    $validDependencies = $dependencies | Where-Object {
        $_.PSObject.Properties.Name -contains "Name" -and
        $_.PSObject.Properties.Name -contains "Path" -and
        $_.PSObject.Properties.Name -contains "Priority" -and
        -not [string]::IsNullOrWhiteSpace($_.Name) -and
        -not [string]::IsNullOrWhiteSpace($_.Path)
    }

    if (-not $validDependencies -or $validDependencies.Count -eq 0) {
        Add-LogMessage -message "No valid dependencies to process after filtering." -functionName $MyInvocation.InvocationName -logLevel "Error"
        throw "No valid dependencies to process."
    }

    # Sort dependencies by priority
    $sortedDependencies = $validDependencies | Sort-Object -Property Priority

    # Log sorted dependencies
    Add-LogMessage -message "Dependencies after filtering and sorting: $($sortedDependencies | Out-String)" -functionName $MyInvocation.InvocationName -logLevel "Debug"

    # Import modules
    foreach ($dependency in $sortedDependencies) {
        try {
            $moduleName = $dependency.Name
            $modulePath = $dependency.Path

            Add-LogMessage -message "Processing module: $moduleName from path: $modulePath" -functionName $MyInvocation.InvocationName -logLevel "Debug"

            # Skip unloading for excluded modules
            if ($moduleName -in $Script:ExcludedModules) {
                Add-LogMessage -message "Skipping unload for excluded module: $moduleName" -functionName $MyInvocation.InvocationName -logLevel "Debug"
                continue
            }

            # Validate module path
            if (-not (Test-Path -Path $modulePath -PathType Leaf)) {
                Add-LogMessage -message "Invalid module path: $modulePath" -functionName $MyInvocation.InvocationName -logLevel "Error"
                throw "Critical Error: Module path '$modulePath' is invalid."
            }

            # Remove module if already loaded
            if (Get-Module -Name $moduleName -ErrorAction SilentlyContinue) {
                Remove-Module -Name $moduleName -Force -ErrorAction SilentlyContinue
                Add-LogMessage -message "Removed previously loaded module: $moduleName" -functionName $MyInvocation.InvocationName -logLevel "Debug"
            }

            # Import the module
            Import-Module -Name $modulePath -Scope Global -Force -ErrorAction Stop
            Add-LogMessage -message "Module '$moduleName' imported successfully." -functionName $MyInvocation.InvocationName -logLevel "Success"
        }
        catch {
            Add-LogMessage -message "Failed to import module: $moduleName. Error: $($_.Exception | Out-String)" -functionName $MyInvocation.InvocationName -logLevel "Error"
            throw "Critical Error: Unable to import module '$moduleName'."
        }
    }

    Add-LogMessage -message "Module import process completed successfully." -functionName $MyInvocation.InvocationName -logLevel "Success"
}

# Function to detect available plugins in the specified directory
function Get-Plugins {
    param (
        [string]$PluginFolderPath = "$($Global:Config.Paths.Modules.Plugins)"
    )

    Add-LogMessage -message "Starting plugin detection in folder: $PluginFolderPath" -functionName $MyInvocation.InvocationName -logLevel "Info"

    # Verify the plugin folder path
    if (-not (Test-Path -Path $PluginFolderPath)) {
        Add-LogMessage -message "Plugin folder not found at $PluginFolderPath" -functionName $MyInvocation.InvocationName -logLevel "Error"
        throw "Error: Plugin folder not found at $PluginFolderPath"
    }

    # Initialize Plugins as PSObject if not already defined
    if (-not ($Global:Config.InternalConfig.Plugins -is [PSCustomObject])) {
        $Global:Config.InternalConfig.Plugins = [PSCustomObject]@{}
        Add-LogMessage -message "Initialized Plugins as a PSObject in Global:Config.Files.InternalConfig." -functionName $MyInvocation.InvocationName -logLevel "Debug"
    }

    # Initialize an array to store detected plugins
    $pluginFiles = @()

    try {
        # Retrieve all .psd1 files within the plugin directory recursively
        $pluginFiles = Get-ChildItem -Path $PluginFolderPath -Filter "*.psd1" -File -Recurse | ForEach-Object {
            [PSCustomObject]@{
                Name = $_.BaseName
                Path = $_.FullName
            }
        }

        if ($pluginFiles.Count -eq 0) {
            Add-LogMessage -message "No plugins found in folder: $PluginFolderPath" -functionName $MyInvocation.InvocationName -logLevel "Warning"
        }
        else {
            foreach ($plugin in $pluginFiles) {
                $pluginName = $plugin.Name
                $pluginPath = $plugin.Path

                # Check if the plugin is already registered
                if (-not ($Global:Config.InternalConfig.Plugins.PSObject.Properties.Name -contains $pluginName)) {
                    # Add plugin to Plugins as a PSObject
                    $Global:Config.InternalConfig.Plugins | Add-Member -MemberType NoteProperty -Name $pluginName -Value $pluginPath
                    Add-LogMessage -message "Registered plugin: $pluginName at path $pluginPath" -functionName $MyInvocation.InvocationName -logLevel "Info"
                }
                else {
                    Add-LogMessage -message "Plugin $pluginName already exists in Global:Config.Files.InternalConfig.Plugins. Skipping." -functionName $MyInvocation.InvocationName -logLevel "Debug"
                }
            }
            Add-LogMessage -message "Detected and registered $($pluginFiles.Count) plugin(s) in folder $PluginFolderPath" -functionName $MyInvocation.InvocationName -logLevel "Info"
        }
    }
    catch {
        Add-LogMessage -message "Failed to retrieve plugins from folder: $PluginFolderPath. Error: $($_.Exception.Message)" -functionName $MyInvocation.InvocationName -logLevel "Error"
        throw "Error retrieving plugins from $PluginFolderPath"
    }

    Add-LogMessage -message "Completed plugin detection successfully" -functionName $MyInvocation.InvocationName -logLevel "Success"

    # Return the array of detected plugins
    return $pluginFiles
}


# Function to update the plugin configuration with detected plugins
function Update-PluginsInConfig {
    param (
        [array]$DetectedPlugins,
        [string]$ConfigFilePath = (Join-Path -Path $Global:Config.Paths.Config -ChildPath "ops_config.json")
    )

    Add-LogMessage -message "Starting update of plugin list in configuration file: $ConfigFilePath" -functionName $MyInvocation.InvocationName -logLevel "Info"

    # Verify the existence of the configuration file
    if (-not (Test-Path -Path $ConfigFilePath)) {
        Add-LogMessage -message "Configuration file not found at $ConfigFilePath" -functionName $MyInvocation.InvocationName -logLevel "Error"
        throw "Error: Configuration file not found at $ConfigFilePath"
    }

    # Load the configuration file
    try {
        $configData = Get-Content -Path $ConfigFilePath -Raw | ConvertFrom-Json
        if (-not $configData) {
            throw "Configuration file is empty or invalid."
        }
        Add-LogMessage -message "Configuration file loaded successfully." -functionName $MyInvocation.InvocationName -logLevel "Info"
    }
    catch {
        Add-LogMessage -message "Error loading configuration file at ${ConfigFilePath}: $($_.Exception.Message)" -functionName $MyInvocation.InvocationName -logLevel "Error"
        throw "Failed to load configuration file."
    }

    # Ensure Plugins structure exists in configuration file and Global:Config
    try {
        if (-not ($configData.PSObject.Properties.Name -contains "Plugins") -or -not ($configData.Plugins -is [PSCustomObject])) {
            $configData.Plugins = [PSCustomObject]@{}
            Add-LogMessage -message "Initialized Plugins section in configuration file data." -functionName $MyInvocation.InvocationName -logLevel "Debug"
        }

        if (-not ($Global:Config.InternalConfig.Plugins -is [PSCustomObject])) {
            $Global:Config.InternalConfig.Plugins = [PSCustomObject]@{}
            Add-LogMessage -message "Initialized Plugins section in Global configuration." -functionName $MyInvocation.InvocationName -logLevel "Debug"
        }

        # Update the Plugins section with detected plugins
        foreach ($plugin in $DetectedPlugins) {
            # Update both Global:Config and the config file data
            $configData.Plugins | Add-Member -MemberType NoteProperty -Name $plugin.Name -Value $plugin.Path -Force
            $Global:Config.InternalConfig.Plugins | Add-Member -MemberType NoteProperty -Name $plugin.Name -Value $plugin.Path -Force
            Add-LogMessage -message "Added or updated plugin '$($plugin.Name)' with path '$($plugin.Path)'." -functionName $MyInvocation.InvocationName -logLevel "Info"
        }

        # Save the updated configuration file
        $configData | ConvertTo-Json -Depth 5 | Set-Content -Path $ConfigFilePath -Force
        Add-LogMessage -message "Updated configuration file saved successfully at $ConfigFilePath." -functionName $MyInvocation.InvocationName -logLevel "Success"
    }
    catch {
        Add-LogMessage -message "Failed to update Plugins in configuration. Error: $($_.Exception.Message)" -functionName $MyInvocation.InvocationName -logLevel "Error"
        throw "Error updating Plugins in configuration file."
    }
}




# Function to import plugin modules dynamically
function Import-Plugins {
    Add-LogMessage -message "Starting plugin import process..." -functionName $MyInvocation.InvocationName -logLevel "Info"

    # Ensure Plugins are defined in the configuration
    if ($Global:Config.InternalConfig.Plugins -and $Global:Config.InternalConfig.Plugins.PSObject.Properties.Count -gt 0) {
        foreach ($plugin in $Global:Config.InternalConfig.Plugins.PSObject.Properties) {
            $pluginName = $plugin.Name
            $pluginPath = $plugin.Value

            Add-LogMessage -message "Attempting to import plugin: $pluginName from path: $pluginPath" -functionName $MyInvocation.InvocationName -logLevel "Debug"

            # Verify if the plugin path exists
            if (-not (Test-Path -Path $pluginPath)) {
                Add-LogMessage -message "Plugin '$pluginName' not found at path '$pluginPath'." -functionName $MyInvocation.InvocationName -logLevel "Error"
                continue
            }

            # Remove plugin module if it is already loaded
            if (Get-Module -Name $pluginName -ErrorAction SilentlyContinue) {
                try {
                    Remove-Module -Name $pluginName -Force -ErrorAction Stop
                    Add-LogMessage -message "Removed previously loaded plugin: $pluginName" -functionName $MyInvocation.InvocationName -logLevel "Debug"
                }
                catch {
                    Add-LogMessage -message "Failed to remove plugin '$pluginName'. Error: $($_.Exception.Message)" -functionName $MyInvocation.InvocationName -logLevel "Error"
                    continue
                }
            }

            # Import the plugin module
            try {
                Import-Module -Name $pluginPath -Scope Global -Force -ErrorAction Stop
                Add-LogMessage -message "Plugin '$pluginName' imported successfully." -functionName $MyInvocation.InvocationName -logLevel "Success"
            }
            catch {
                Add-LogMessage -message "Failed to import plugin '$pluginName'. Error: $($_.Exception.Message)" -functionName $MyInvocation.InvocationName -logLevel "Error"
            }
        }

        Add-LogMessage -message "Plugin import process completed successfully." -functionName $MyInvocation.InvocationName -logLevel "Success"
    }
    else {
        Add-LogMessage -message "No plugins found in configuration to import." -functionName $MyInvocation.InvocationName -logLevel "Warning"
    }
}


# Define all supported parameters with types and default values
function Initialize-DefaultParameters {
    Add-LogMessage -message "Initializing default parameters..." -functionName $MyInvocation.InvocationName -logLevel "Info"

    # Define all supported parameters dynamically from UserConfigData.Settings
    $Global:DefaultParameters = @{}

    # Define parameter types and default values, linked to UserConfigData.Settings
    $parameterDefinitions = @{
        #hostName          = @{ Type = [string]; Default = $null }
        #groupName         = @{ Type = [string]; Default = $null }
        #hostsList         = @{ Type = [array]; Default = @() }
        updateHosts       = @{ Type = [bool]; Default = $Global:Config.UserConfigData.Settings.UpdateHosts }
        usePsUpdate       = @{ Type = [bool]; Default = $Global:Config.UserConfigData.Settings.UsePsUpdate }
        forceUpdate       = @{ Type = [bool]; Default = $Global:Config.UserConfigData.Settings.ForceUpdate }
        updateHistoryDays = @{ Type = [int]; Default = $Global:Config.UserConfigData.Settings.UpdateHistoryDays }
        inventory         = @{ Type = [bool]; Default = $Global:Config.UserConfigData.Settings.Inventory }
        useDNS            = @{ Type = [bool]; Default = $Global:Config.UserConfigData.Settings.UseDNS }
        debug             = @{ Type = [bool]; Default = $Global:Config.UserConfigData.Settings.Verbose }
        silent            = @{ Type = [bool]; Default = $Global:Config.UserConfigData.Settings.Silent }
    }

    # Populate DefaultParameters with definitions
    foreach ($param in $parameterDefinitions.Keys) {
        $Global:DefaultParameters | Add-Member -MemberType NoteProperty -Name $param -Value $parameterDefinitions[$param]
    }

    Add-LogMessage -message "Default parameters initialized successfully." -functionName $MyInvocation.InvocationName -logLevel "Success"
}

# Function to set or update global configuration based on provided parameters
function Set-GlobalConfig {
    param (
        [hashtable]$SourceHash, # Parameters provided by the user or other sources
        [hashtable]$DefaultParameters   # Default parameter definitions (type and value)
    )

    Add-LogMessage -message "Starting to set global configuration parameters." -functionName $MyInvocation.InvocationName -logLevel "Info"

    # Iterate through each default parameter and set its value
    foreach ($key in $DefaultParameters.Keys) {
        $paramDefinition = $DefaultParameters[$key]
        $type = $paramDefinition.Type
        $defaultValue = $paramDefinition.Default

        # Determine the value: priority is SourceHash > Default value
        $value = if ($SourceHash.ContainsKey($key) -and ($null -ne $SourceHash[$key])) {
            try {
                [System.Management.Automation.LanguagePrimitives]::ConvertTo($SourceHash[$key], $type)
            }
            catch {
                Add-LogMessage -message "Invalid type for key '$key'. Expected type: $type. Using default value." -functionName $MyInvocation.InvocationName -logLevel "Warning"
                $defaultValue
            }
        }
        else {
            $defaultValue
        }

        # Add or update the value in Global:Config.UserConfigData.Settings
        if (-not ($Global:Config.UserConfigData.Settings.PSObject.Properties.Name -contains $key)) {
            $Global:Config.UserConfigData.Settings | Add-Member -MemberType NoteProperty -Name $key -Value $value
        }
        else {
            $Global:Config.UserConfigData.Settings.$key = $value
        }

        Add-LogMessage -message "Set key '$key' to value '$value'." -functionName $MyInvocation.InvocationName -logLevel "Debug"
    }

    Add-LogMessage -message "Global configuration parameters set successfully." -functionName $MyInvocation.InvocationName -logLevel "Success"
}



# Function to initialize global settings with prioritized user-defined parameters
function Initialize-GlobalSettings {
    param (
        [hashtable]$ParameterHash    # Parameters explicitly provided by the user
    )

    Add-LogMessage -message "Starting global settings initialization..." -functionName $MyInvocation.InvocationName -logLevel "Info"

    # Ensure UserConfigData.Settings exists
    if (-not ($Global:Config.UserConfigData.PSObject.Properties.Name -contains "Settings")) {
        $Global:Config.UserConfigData | Add-Member -MemberType NoteProperty -Name "Settings" -Value ([PSCustomObject]@{})
    }

    try {
        # Load JSON configuration file
        $jsonFilePath = $Global:Config.InternalConfig.Files.JsonUserConfig
        Add-LogMessage -message "Loading JSON configuration from: $jsonFilePath" -functionName $MyInvocation.InvocationName -logLevel "Info"
        $jsonConfig = Get-Content -Path $jsonFilePath -Raw | ConvertFrom-Json

        # Process sections of the JSON file
        foreach ($sectionName in $jsonConfig.PSObject.Properties.Name) {
            $sectionContent = $jsonConfig.$sectionName

            if ($sectionName -eq "Settings") {
                Add-LogMessage -message "Processing 'Settings' section with parameter priority." -functionName $MyInvocation.InvocationName -logLevel "Debug"

                # Ensure Settings exists in UserConfigData
                if (-not ($Global:Config.UserConfigData.PSObject.Properties.Name -contains "Settings")) {
                    $Global:Config.UserConfigData | Add-Member -MemberType NoteProperty -Name "Settings" -Value ([PSCustomObject]@{})
                }

                $authorizedKeys = $Global:DefaultParameters.Keys
                foreach ($key in $authorizedKeys) {
                    $value = if ($ParameterHash.ContainsKey($key) -and $null -ne $ParameterHash[$key]) {
                        # Priority 1: User-provided parameters
                        $ParameterHash[$key]
                    }
                    elseif ($sectionContent.PSObject.Properties.Name -contains $key) {
                        # Priority 2: JSON file
                        $sectionContent.$key
                    }
                    else {
                        # Priority 3: Default values
                        $Global:DefaultParameters[$key].Default
                    }

                    # Validate and set the value
                    $expectedType = $Global:DefaultParameters[$key].Type
                    try {
                        $value = [System.Management.Automation.LanguagePrimitives]::ConvertTo($value, $expectedType)
                        $Global:Config.UserConfigData.Settings | Add-Member -MemberType NoteProperty -Name $key -Value $value -Force
                        Add-LogMessage -message "Set '$key' to '$value' in Settings." -functionName $MyInvocation.InvocationName -logLevel "Debug"
                    }
                    catch {
                        Add-LogMessage -message "Failed to set '$key'. Expected type: $expectedType. Error: $($_.Exception.Message)" -functionName $MyInvocation.InvocationName -logLevel "Error"
                        throw "Invalid value for '$key'."
                    }
                }
            }
            else {
                # Process other sections
                if (-not ($Global:Config.UserConfigData.PSObject.Properties.Name -contains $sectionName)) {
                    $Global:Config.UserConfigData | Add-Member -MemberType NoteProperty -Name $sectionName -Value ([PSCustomObject]@{})
                }

                foreach ($key in $sectionContent.PSObject.Properties.Name) {
                    $Global:Config.UserConfigData.$sectionName | Add-Member -MemberType NoteProperty -Name $key -Value $sectionContent.$key -Force
                    Add-LogMessage -message "Set '$key' in section '$sectionName'." -functionName $MyInvocation.InvocationName -logLevel "Debug"
                }
            }
        }

        Add-LogMessage -message "Global settings initialized successfully." -functionName $MyInvocation.InvocationName -logLevel "Success"
    }
    catch {
        $errorMessage = "Error during global settings initialization: $($_.Exception.Message)"
        Add-LogMessage -message $errorMessage -functionName $MyInvocation.InvocationName -logLevel "Error"
        throw $errorMessage
    }
}

function Import-StandaloneDependencies {
    param (
        [array]$standaloneDependencies
    )

    Add-LogMessage -message "Starting Import-StandaloneDependencies process..." -functionName $MyInvocation.InvocationName -logLevel "Info"

    # Verifica que la configuración esté inicializada
    if (-not ($Global:Config.InternalConfig.Modules -is [PSCustomObject])) {
        $Global:Config.InternalConfig.Modules = [PSCustomObject]@{}
        Add-LogMessage -message "Initialized Modules as a PSObject in Global:Config.InternalConfig." -functionName $MyInvocation.InvocationName -logLevel "Debug"
    }

    # Cargar la configuración desde el archivo JSON
    $configFilePath = Join-Path -Path $Global:Config.Paths.Config -ChildPath "ops_config.json"
    try {
        $configData = Get-Content -Path $configFilePath -Raw | ConvertFrom-Json
        Add-LogMessage -message "Configuration file loaded successfully from $configFilePath." -functionName $MyInvocation.InvocationName -logLevel "Info"

        # Poblar los módulos en $Global:Config.InternalConfig.Modules
        foreach ($module in $configData.Modules) {
            $moduleName = $module.Name
            $modulePath = if (-not (Test-Path -Path $module.Path -PathType Leaf)) {
                Join-Path -Path $Global:Config.Paths.Root -ChildPath $module.Path
            }
            else {
                $module.Path
            }
            $modulePriority = $module.Priority

            # Agrega el módulo al PSObject global si no existe ya
            if (-not ($Global:Config.InternalConfig.Modules.PSObject.Properties.Name -contains $moduleName)) {
                $Global:Config.InternalConfig.Modules | Add-Member -MemberType NoteProperty -Name $moduleName -Value ([PSCustomObject]@{
                        Path     = $modulePath
                        Priority = $modulePriority
                    }) -Force
                Add-LogMessage -message "Added module: $moduleName with path $modulePath and priority $modulePriority." -functionName $MyInvocation.InvocationName -logLevel "Info"
            }
        }
    }
    catch {
        Add-LogMessage -message "Failed to load configuration file: $($_.Exception.Message)" -functionName $MyInvocation.InvocationName -logLevel "Error"
        throw "Error loading configuration file: $configFilePath"
    }

    # Filtrar los módulos según $standaloneDependencies
    $filteredModules = @()
    Add-LogMessage -message "$($standaloneDependencies[0]) / $($standaloneDependencies[1]) . Skipping." -functionName $MyInvocation.InvocationName -logLevel "Debug"
    foreach ($dependency in $standaloneDependencies) {
        if ($Global:Config.InternalConfig.Modules.PSObject.Properties.Name -contains $dependency) {
            $moduleData = $Global:Config.InternalConfig.Modules.$dependency
            $filteredModules += [PSCustomObject]@{
                Name     = $dependency
                Path     = $moduleData.Path
                Priority = $moduleData.Priority
            }
        }
        else {
            Add-LogMessage -message "Module $dependency not found in InternalConfig.Modules. Skipping." -functionName $MyInvocation.InvocationName -logLevel "Warning"
        }
    }

    # Verifica si se encontraron módulos válidos
    if (-not $filteredModules -or $filteredModules.Count -eq 0) {
        Add-LogMessage -message "No valid standalone dependencies to process." -functionName $MyInvocation.InvocationName -logLevel "Error"
        throw "No valid standalone dependencies to process."
    }

    # Ordena los módulos por prioridad
    $sortedModules = $filteredModules | Sort-Object -Property Priority
    Add-LogMessage -message "Modules to import (sorted): $($sortedModules | Out-String)" -functionName $MyInvocation.InvocationName -logLevel "Debug"

    # Import the modules
    foreach ($module in $sortedModules) {
        try {
            $moduleName = $module.Name
    
            # If the module already has an absolute path, use it directly
            if ([System.IO.Path]::IsPathRooted($module.Path)) {
                $modulePath = $module.Path
            }
            else {
                # Build the absolute path using $ProjectRoot and the relative path
                $modulePath = Join-Path -Path $ProjectRoot -ChildPath $module.Path
            }
    
            # Validate if the module path exists and is valid
            if (-not (Test-Path -Path $modulePath -PathType Leaf)) {
                Add-LogMessage -message "Invalid module path: $modulePath" -functionName $MyInvocation.InvocationName -logLevel "Error"
                throw "Module path '$modulePath' is invalid."
            }
    
            # Import the module
            Import-Module -Name $modulePath -Scope Global -Force -ErrorAction Stop
            Add-LogMessage -message "Module '$moduleName' imported successfully." -functionName $MyInvocation.InvocationName -logLevel "Success"
        }
        catch {
            Add-LogMessage -message "Failed to import module: $moduleName. Error: $($_.Exception.Message)" -functionName $MyInvocation.InvocationName -logLevel "Error"
            throw "Critical Error: Unable to import module '$moduleName'."
        }
    }
    
    Add-LogMessage -message "Standalone dependencies import process completed successfully." -functionName $MyInvocation.InvocationName -logLevel "Success"
}

<#
    # Importa los módulos
    foreach ($module in $sortedModules) {
        try {
            $moduleName = $module.Name
            #$modulePath = $module.Path
            $modulePath = Resolve-Path -Path (Join-Path -Path $ProjectRoot -ChildPath $module.Path) -ErrorAction Stop

            Add-LogMessage -message "Importing module: $moduleName from path: $modulePath" -functionName $MyInvocation.InvocationName -logLevel "Debug"

            if (-not (Test-Path -Path $modulePath -PathType Leaf)) {
                Add-LogMessage -message "Invalid module path: $modulePath" -functionName $MyInvocation.InvocationName -logLevel "Error"
                throw "Module path '$modulePath' is invalid."
            }

            Import-Module -Name $modulePath -Scope Global -Force -ErrorAction Stop
            Add-LogMessage -message "Module '$moduleName' imported successfully." -functionName $MyInvocation.InvocationName -logLevel "Success"
        }
        catch {
            Add-LogMessage -message "Failed to import module: $moduleName. Error: $($_.Exception.Message)" -functionName $MyInvocation.InvocationName -logLevel "Error"
            throw "Critical Error: Unable to import module '$moduleName'."
        }
    }

    Add-LogMessage -message "Standalone dependencies import process completed successfully." -functionName $MyInvocation.InvocationName -logLevel "Success"
}
#>

#>
# Core initialization function
function Initialize-Configuration {
    param (
        [hashtable]$UserParameters = @{} # User-defined parameters for configuration
    )

    # Prevent re-initialization if already initialized
    if ($Global:ConfigInitialized) {
        Add-LogMessage -message "Configuration already initialized. Skipping re-initialization." -functionName $MyInvocation.InvocationName -logLevel "Info"
        return
    }

    try {
        # Step 0: Verify critical directories and files
        try {
            Test-SourcePathsAndFiles -CriticalFiles $Script:criticalSourceFiles
            #Add-LogMessage -message "Environment validation passed successfully" -functionName $MyInvocation.InvocationName -logLevel "Success"
        }
        catch {
            Add-LogMessage -message "Environment validation failed: $($_.Exception.Message)" -functionName $MyInvocation.InvocationName -logLevel "Error"
            throw "Critical error: Environment validation failed. Cannot proceed."
        }

        # Step 1: Initialize InternalConfig
        #Add-LogMessage -message "Initializing Internal Config..." -functionName $MyInvocation.InvocationName -logLevel "Info"
        Initialize-InternalConfig

        # Step 2: Initialize UserConfigData
        #Add-LogMessage -message "Initializing User Config Data..." -functionName $MyInvocation.InvocationName -logLevel "Info"
        Initialize-UserConfigData 

        # Step 3: Initialize HostData
        #Add-LogMessage -message "Initializing Hosts Data..." -functionName $MyInvocation.InvocationName -logLevel "Info"
        Initialize-HostsData 

        # Step 4: Initialize SecurityData
        #Add-LogMessage -message "Initializing Security Data..." -functionName $MyInvocation.InvocationName -logLevel "Info"
        Initialize-SecurityData 

        # Step 5: Initialize and import modules
        #Add-LogMessage -message "Initializing modules..." -functionName $MyInvocation.InvocationName -logLevel "Info"
        Initialize-Modules
        Import-Modules
        
        # Step 3: Initialize logging System
        Add-LogMessage -message "Initializing logging System..." -functionName $MyInvocation.InvocationName -logLevel "Info"
        Initialize-Log

        # Flush temporary log messages (if any exist)
        foreach ($msg in $Global:tempLogMessages) {
            Add-LogMessage -message $msg
        }
        $Global:tempLogMessages = @()

        Add-LogMessage -message "Starting OpsHostGuard-Manager..." -functionName $MyInvocation.InvocationName -logLevel "Info"

        
        # Step 5: Detect plugins and update the configuration
        Add-LogMessage -message "Detecting plugins..." -functionName $MyInvocation.InvocationName -logLevel "Info"
        $detectedPlugins = Get-Plugins
        Update-PluginsInConfig -DetectedPlugins $detectedPlugins

       

        # Step 7: Import plugins
        Add-LogMessage -message "Importing plugins..." -functionName $MyInvocation.InvocationName -logLevel "Info"
        Import-Plugins

        # Step 8: Initialize user-defined parameters and global settings
        Add-LogMessage -message "Initializing default parameters..." -functionName $MyInvocation.InvocationName -logLevel "Info"
        Initialize-DefaultParameters
        Add-LogMessage -message "Initializing global settings..." -functionName $MyInvocation.InvocationName -logLevel "Info"
        Initialize-GlobalSettings -ParameterHash $UserParameters

        # Mark configuration as initialized
        Add-LogMessage -message "Configuration successfully initialized." -functionName $MyInvocation.InvocationName -logLevel "Success"
        $Global:ConfigInitialized = $true
    }
    catch {
        $errorMessage = "Configuration initialization failed: $($_.Exception.Message)"
        Add-LogMessage -message $errorMessage -functionName $MyInvocation.InvocationName -logLevel "Error"
        throw $errorMessage
    }
}


function Initialize-ConfigurationStandalone {
    <#
    .SYNOPSIS
    Initializes minimal configurations required for Standalone mode.

    .DESCRIPTION
    This function initializes only the essential configurations required for Standalone mode. 
    It ensures that critical configurations, hosts data, security settings, and modules are set up
    without triggering a full OpsHostGuard initialization. This is useful for modules that need to 
    operate independently in a lightweight configuration.

    .NOTES
    This function is designed to work in a standalone environment and does not include plugin 
    management, full configuration imports, or unnecessary module imports.

    .PARAMETER ModuleName
    Optional. The name of the standalone module being initialized.

    .PARAMETER coreDependencies
    Optional. An array of dependencies required for the standalone module.

    .EXAMPLE
    Initialize-ConfigurationStandalone
    Initializes minimal configuration for standalone mode.
    #>
        
    Add-LogMessage -message "Starting Standalone Configuration Initialization..." -functionName $MyInvocation.InvocationName -logLevel "Info"

    try {
        # Step 1: Initialize Internal Configuration
        Add-LogMessage -message "Initializing InternalConfig for Standalone mode..." -functionName $MyInvocation.InvocationName -logLevel "Info"
        Initialize-InternalConfig

        # Step 2: Initialize User Configuration Data
        Add-LogMessage -message "Initializing UserConfigData for Standalone mode..." -functionName $MyInvocation.InvocationName -logLevel "Info"
        Initialize-UserConfigData

        # Step 3: Initialize Host Data
        Add-LogMessage -message "Initializing HostsData for Standalone mode..." -functionName $MyInvocation.InvocationName -logLevel "Info"
        Initialize-HostsData

        # Step 4: Initialize Security Data
        Add-LogMessage -message "Initializing SecurityData for Standalone mode..." -functionName $MyInvocation.InvocationName -logLevel "Info"
        Initialize-SecurityData

        Add-LogMessage -message "Standalone Configuration Initialization completed successfully." -functionName $MyInvocation.InvocationName -logLevel "Success"
    }
    catch {
        $errorMessage = "Standalone Configuration Initialization failed: $($_.Exception.Message)"
        Add-LogMessage -message $errorMessage -functionName $MyInvocation.InvocationName -logLevel "Error"
        throw $errorMessage
    }
}


# Standalone mode initialization
function New-ModuleStandalone {
    param (
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$moduleName # Name of the standalone core module being initialized
        #[string]$moduleName # Name of the standalone core module being initialized
        #[array]$standaloneDependencies    # Array of dependencies required for the core module
    )

    
    # Step 1: Determine the project root path
    try {
        if ($null -ne $PSScriptRoot -and $PSScriptRoot -ne "") {
            $Global:ProjectRoot = (Resolve-Path -Path (Join-Path -Path $PSScriptRoot -ChildPath "../../../")).Path
            Add-LogMessage -message "Project root determined as: $Global:ProjectRoot" -functionName $MyInvocation.InvocationName -logLevel "Debug"
        }
        else {
            throw "Error: PSScriptRoot is null or empty. Ensure this script is run as part of a module."
        }
    }
    catch {
        Add-LogMessage -message "Failed to determine project root. Error: $($_.Exception.Message)" -functionName $MyInvocation.InvocationName -logLevel "Error"
        throw
    }

    # Step 2: Initialize standalone configuration
    try {
        if (-not $moduleName) {
            throw "ModuleName parameter is required but was not provided."
        }
        Add-LogMessage -message "Initializing standalone configuration for module: $moduleName..." -functionName $MyInvocation.InvocationName -logLevel "Info"
        Initialize-ConfigurationStandalone
        Add-LogMessage -message "Standalone configuration initialized successfully for module: $moduleName." -functionName $MyInvocation.InvocationName -logLevel "Success"
    }
    catch {
        Add-LogMessage -message "Failed to initialize standalone configuration for module '$moduleName'. Error: $($_.Exception.Message)" -functionName $MyInvocation.InvocationName -logLevel "Error"
        throw
    }

    # Step 3: Validate logCorePath for the specified module
    try {
        $Script:logCorePath = if ($Global:Config.InternalConfig.LogCore.$moduleName) {
            $Global:Config.InternalConfig.LogCore.$moduleName
        }
        else {
            throw "logCorePath not defined for module '$moduleName' in Global configuration."
        }
        Add-LogMessage -message "logCorePath for '$moduleName': $Script:logCorePath" -functionName $MyInvocation.InvocationName -logLevel "Debug"
    }
    catch {
        Add-LogMessage -message "Failed to retrieve logCorePath for module '$moduleName'. Error: $($_.Exception.Message)" -functionName $MyInvocation.InvocationName -logLevel "Error"
        throw
    }

    # Step 4: Validate and import core dependencies
    #Initialize-Dependency -coreDependencies = $standaloneDependencies
    #Import-StandaloneDependencies -standaloneDependencies = $standaloneDependencies
    # Step 5: Initialize global PS remoting credentials
    try {
        Initialize-GlobalPsRemotingCredential
        Add-LogMessage -message "Global PS Remoting credentials initialized successfully." -functionName $MyInvocation.InvocationName -logLevel "Success"
    }
    catch {
        Add-LogMessage -message "Error initializing global PS remoting credentials. Exception: $($_.Exception.Message)" -functionName $MyInvocation.InvocationName -logLevel "Error"
        throw
    }

    # Step 6: Finalize standalone core initialization
    Add-LogMessage -message "Standalone core initialized successfully." -functionName $MyInvocation.InvocationName -logLevel "Success"
}

# Exported variables and functions
#Export-ModuleMember -Variable Config -Function Initialize-ConfigProperties, Initialize-Configuration, Import-Modules, Import-Plugins, Initialize-ConfigProperties, `
#    Initialize-GlobalSettings, New-CoreStandalone, Import-StandaloneModules

# *** Quitar tras el debug.
Export-ModuleMember -Variable Config -Function Initialize-ConfigProperties, Initialize-Configuration, Initialize-SecurityData, Initialize-ConfigurationStandalone, Import-Modules, Import-Plugins, `
    Initialize-ConfigProperties, Test-PathsAndFiles, Initialize-GlobalSettings, New-ModuleStandalone, Import-StandaloneDependencies, Update-PluginsInConfig, Initialize-Modules

