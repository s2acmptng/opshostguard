<#
# OpsVar.psm1 [OpsHostGuard - Core Configuration Module]

.SYNOPSIS
Core module for defining and managing the project root and directory structure used by the OpsHostGuard system.

.DESCRIPTION
OpsVar provides the foundational infrastructure for OpsHostGuard by resolving the project root and defining
a centralized set of filesystem paths used across the system. Its primary responsibility is to ensure that all
modules operate against a consistent and predictable directory structure within the same PowerShell session.

The module initializes and exposes `$Global:ProjectRoot` and `$Global:Config.Paths`. Other configuration
sections under `$Global:Config` are intentionally initialized separately to avoid unintended side effects
during module import.

OpsVar is designed to be safe to import multiple times within the same session without reinitializing
critical state unnecessarily.

.FEATURES
- **Project Root Resolution**: Dynamically resolves the root directory of the OpsHostGuard project at runtime.
- **Centralized Path Definition**: Defines a structured and hierarchical set of paths for data, logs, modules,
  dashboard components, temporary files, and security-related resources.
- **Non-invasive Import Behavior**: Ensures that importing OpsVar does not reset or override existing global
  configuration unless explicitly requested.
- **Shared Session State**: Provides a common reference point for paths and configuration within a single
  PowerShell session.

.DEPENDENCY MODEL
OpsVar participates in a sequential dependency model within a single PowerShell session:

- OpsVar is expected to be loaded early, typically after or alongside `OpsInit`.
- Modules that rely on filesystem paths (e.g., logging, data management, dashboards) depend on
  `$Global:ProjectRoot` and `$Global:Config.Paths` being initialized.
- Safeguards prevent redefinition of existing global variables where possible.

This module does not enforce load order but assumes responsible usage by higher-level orchestration modules.

.PURPOSE

1. **Stable Path Infrastructure**
   - Provide a single authoritative definition of filesystem paths used throughout the system.
   - Avoid duplication and divergence of path logic across modules.

2. **Controlled Global State**
   - Populate `$Global:Config.Paths` independently of other configuration sections.
   - Allow other modules (e.g., `OpsInit`) to extend `$Global:Config` without resetting paths.

3. **Session-Level Consistency**
   - Ensure all scripts and modules executed within the same PowerShell session reference the same
     directory structure.
   - Support concurrent script execution within the same session without conflicting reinitialization.

4. **Operational Efficiency**
   - Reduce redundant path resolution and initialization overhead.
   - Enable lightweight imports of core infrastructure modules.

.DIRECTORY NAMING CONVENTION
- **Organizational directories** use `snake_case` to represent structural or grouping purposes
  (e.g., `hosts_management`).
- **Module-specific directories** use `PascalCase` where appropriate to denote functional units.

These conventions reflect the current project structure and are intended to improve navigability
rather than enforce strict stylistic rules.

.VARIABLE NAMING CONVENTION
- **Global and script-scope variables** use `PascalCase`.
- **Local variables and function parameters** use `camelCase`.

.AUTHOR
© 2024 Alberto Ledo  
Faculty of Documentation and Communication Sciences  
University of Extremadura  
Contact: albertoledo@unex.es

.VERSION
2.0.0

.HISTORY
2.0.0 - Introduced controlled initialization of `$Global:Config` and centralized path definition.
1.1.0 - Improved internal structure and extensibility of global configuration.
1.0.0 - Initial release with project root resolution and path definitions.

.DATE
November 24, 2024

.NOTES
- OpsVar is an infrastructure module, not a business-logic or orchestration module.
- Its responsibility is limited to path resolution, shared session state, and import support.
- Correct usage assumes a single PowerShell session context.

.EXAMPLE
Scenario:
- `OpsScan.ps1` imports OpsVar and relies on `$Global:Config.Paths.Data.Log`.
- `OpsDataManager.ps1` runs within the same session and accesses the same paths.

Result:
- Both scripts operate against identical directory references without reinitialization
  or path divergence.

.DISCLAIMER
Provided "as-is" for internal use at the University of Extremadura.
No warranties, express or implied.

.LINK
https://github.com/n7rc/OpsHostGuard
#>

# Ensure the resolution of ProjectRoot
function Initialize-ProjectRoot {
    try {
        if ($null -ne $PSScriptRoot -and $PSScriptRoot -ne "") {
            # $PSScriptRoot is available (executing as a module or script)
            $Global:ProjectRoot = (Resolve-Path -Path (Join-Path -Path $PSScriptRoot -ChildPath "../../../")).Path
        }
        else {
            # $PSScriptRoot is not available (imported from console)
            $scriptDirectory = (Get-Item -Path $MyInvocation.MyCommand.Definition).DirectoryName
            $Global:ProjectRoot = (Resolve-Path -Path (Join-Path -Path $scriptDirectory -ChildPath "../../../")).Path
        }
    }
    catch {
        Write-Host "[Warning] Failed to resolve ProjectRoot dynamically. Error: $_" -ForegroundColor Red
        throw
    }
}

function Initialize-Paths {

    $opsPaths = [PSCustomObject]@{

        # Assign values to Paths properties
        Root        = $Global:ProjectRoot
        Config      = Join-Path -Path $ProjectRoot -ChildPath "config"
        Credentials = Join-Path -Path $ProjectRoot -ChildPath "modules/security/credentials"
        Dashboard   = [PSCustomObject]@{
            Root        = Join-Path -Path $ProjectRoot -ChildPath "dashboard"
            Auth        = Join-Path -Path $ProjectRoot -ChildPath "dashboard/auth"
            Config      = Join-Path -Path $ProjectRoot -ChildPath "dashboard/config"
            Controllers = Join-Path -Path $ProjectRoot -ChildPath "dashboard/controllers"
            Core        = Join-Path -Path $ProjectRoot -ChildPath "dashboard/core"
            Modules     = Join-Path -Path $ProjectRoot -ChildPath "dashboard/modules"
            Plugins     = Join-Path -Path $ProjectRoot -ChildPath "dashboard/plugins"
            Public      = Join-Path -Path $ProjectRoot -ChildPath "dashboard/public"
            Views       = Join-Path -Path $ProjectRoot -ChildPath "dashboard/views"
        }
        Data        = [PSCustomObject]@{
            Root = Join-Path -Path $ProjectRoot -ChildPath "data"
            Csv  = Join-Path -Path $ProjectRoot -ChildPath "data/csv"
            Log  = Join-Path -Path $ProjectRoot -ChildPath "data/log"
        }
        Libraries   = Join-Path -Path $ProjectRoot -ChildPath "libraries"
        Listeners   = Join-Path -Path $ProjectRoot -ChildPath "listeners"
        Log         = [PSCustomObject]@{
            Root     = Join-Path -Path $ProjectRoot -ChildPath "log"
            Events   = Join-Path -Path $ProjectRoot -ChildPath "log/events"
            Start    = Join-Path -Path $ProjectRoot -ChildPath "log/modules/start"
            Stop     = Join-Path -Path $ProjectRoot -ChildPath "log/modules/stop"
            Sessions = Join-Path -Path $ProjectRoot -ChildPath "log/modules/sessions"
            Update   = Join-Path -Path $ProjectRoot -ChildPath "log/modules/update"
        }
        Man         = Join-Path -Path $ProjectRoot -ChildPath "man"
        Modules     = [PSCustomObject]@{
            Root             = Join-Path -Path $ProjectRoot -ChildPath "modules"
            System           = Join-Path -Path $ProjectRoot -ChildPath "modules/core/system"
            DataConstructors = Join-Path -Path $ProjectRoot -ChildPath "modules/core/DataConstructors"
            hosts_management = Join-Path -Path $ProjectRoot -ChildPath "modules/core/hosts_management"
            OpsUtils         = Join-Path -Path $ProjectRoot -ChildPath "modules/ops_utils"
            Security         = Join-Path -Path $ProjectRoot -ChildPath "modules/security"   
            Database         = Join-Path -Path $ProjectRoot -ChildPath "modules/database"       
            Plugins          = Join-Path -Path $ProjectRoot -ChildPath "modules/plugins"
        }
        Setup       = Join-Path -Path $ProjectRoot -ChildPath "setup"
        Tmp         = [PSCustomObject]@{
            Root  = Join-Path -Path $ProjectRoot -ChildPath "tmp"
            Cache = Join-Path -Path $ProjectRoot -ChildPath "tmp/cache"
        }    

    }

    if (-not $Global:Config) {
        $Global:Config = [PSCustomObject]@{}
    }

    # Initialize the Paths property if it does not exist
    $Global:Config | Add-Member -MemberType NoteProperty -Name Paths -Value $opsPaths 
}


# Initialize-ConfigVar: Adding other properties incrementally
function Initialize-ConfigVar {
    <#
    .SYNOPSIS
    Encapsulation of global configuration initialization for modular flexibility.
    
    .DESCRIPTION
    This design encapsulates the `$Global:Config` variable within a function (`Initialize-ConfigVar`) to enable controlled 
    initialization of the application's global configuration. This approach ensures that `$Global:Config` is reset only when 
    explicitly desired, preventing unnecessary reinitialization when importing modules like OpsVar. By isolating the 
    initialization process, we maintain the current system state unless an explicit reinitialization is triggered.
    
    Furthermore, `$Global:Config.Paths` is deliberately excluded from the encapsulated function and is instead defined 
    independently. This ensures that paths remain consistent across modules and are not reset inadvertently. Paths are 
    a critical aspect of the application and should always reflect the intended project structure, irrespective of whether 
    other parts of the configuration are reset. This separation enhances modularity and robustness in scenarios where 
    certain modules rely solely on paths without requiring full configuration reinitialization.
    
    By adopting this approach:
    1. The import of core modules like OpsVar remains lightweight and non-invasive unless explicitly required.
    2. `$Global:Config.Paths` is always available and reliable, avoiding unnecessary disruptions.
    3. Initialization of `$Global:Config` can be invoked selectively in modules that truly require it, such as OpsInit.
    
    This modular and approach enhances the maintainability and reliability of the application.
    #>

    $criticalPaths = @()
    $internalConfig = [PSCustomObject]@{
        Config  = [PSCustomObject]@{}
        Files   = [PSCustomObject]@{}
        LogCore = [PSCustomObject]@{}
        Modules = [PSCustomObject]@{}
        Plugins = [PSCustomObject]@{}
    }
    $userConfigData = [PSCustomObject]@{
        Settings           = [PSCustomObject]@{}
        HostSettings       = [PSCustomObject]@{}
        NetworkSettings    = [PSCustomObject]@{}
        DashboardSettings  = [PSCustomObject]@{}
        SessionConfig      = [PSCustomObject]@{}
        GPOConfiguration   = [PSCustomObject]@{}
        DatabaseConnection = [PSCustomObject]@{}
        HTMLReport         = [PSCustomObject]@{}
        EmailNotification  = [PSCustomObject]@{}
    }
    $hostsData = [PSCustomObject]@{
        Groups = [PSCustomObject]@{
            groupName = @{}
        }
        Macs   = [PSCustomObject]@{
            groupMac = @{}
        }
    }
    $security = [PSCustomObject]@{
        Files = [PSCustomObject]@{}
    }

    $Global:Config | Add-Member -MemberType NoteProperty -Name CriticalPaths -Value $criticalPaths
    $Global:Config | Add-Member -MemberType NoteProperty -Name InternalConfig -Value $internalConfig
    $Global:Config | Add-Member -MemberType NoteProperty -Name UserConfigData -Value $userConfigData
    $Global:Config | Add-Member -MemberType NoteProperty -Name HostsData -Value $hostsData
    $Global:Config | Add-Member -MemberType NoteProperty -Name Security -Value $security          
}

# Auxuliary function
function Import-ModuleOps {
    <#
.SYNOPSIS
Centralized module import management function.

.DESCRIPTION
The `Import-ModuleOps` function is designed to simplify and standardize the initialization 
and import process for all core and dependent modules within OpsHostGuard. By centralizing 
this logic in `OpsVar`, it ensures that all modules follow the same validation, re-import, 
and initialization process, improving consistency and reducing redundancy.

This approach allows:
- Seamless management of module interdependencies.
- Automatic re-import when modules are already loaded.
- Validation of module paths before import to avoid runtime errors.

By including this function in `OpsVar`, it becomes immediately available to all modules 
that import `OpsVar`. This design ensures that critical variables and import logic coexist 
and remain consistent throughout the application.

.LIMITATIONS
While this function simplifies the import process, it assumes that `OpsVar` is loaded first 
and successfully initialized. Misuse or over-reliance on this function could lead to tightly 
coupled dependencies between modules if not used responsibly.

.USAGE
The function is intended for core and dependent modules only. It should not be used as 
a general-purpose import function for external or third-party modules.
#>
    param (
        [string]$moduleName,
        [string]$modulePath
    )

    try {
        # Validate that the module path exists before importing
        try {
            if (-not (Test-Path -Path $modulePath -PathType Leaf)) {
                throw "Error: Module '$moduleName' not found at path '$modulePath'."
            }
        }
        catch {
            Write-Error "Error validating the module path for '$moduleName': $_"
            throw
        }
    
        # Attempt to import the module
        try {
            Import-Module -Name $modulePath -Scope Global -Force -ErrorAction Stop
        }
        catch {
            Write-Error "Error importing the module '$moduleName': $_"
            throw
        }
    
        # Validate that the module was imported successfully
        try {
            if (-not (Get-Module -Name $moduleName)) {
                throw "Error: Failed to import module '$moduleName' from '$modulePath'."
            }
        }
        catch {
            Write-Error "Error validating the imported module '$moduleName': $_"
            throw
        }
    }
    catch {
        Write-Error "Error managing the module '$moduleName': $_"
        throw
    }
}

# Export variables and functions to be accessible outside the module
Export-ModuleMember -Variable ProjectRoot, Config -Function Initialize-ProjectRoot, Initialize-Paths, Initialize-ConfigVar, Import-ModuleOps