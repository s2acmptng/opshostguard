<#
# OpsBase.psm1 [OpsHostGuard – Base Utilities and Execution Context Module]

.SYNOPSIS
Base utility module providing execution context detection, standalone mode control, and
early-stage logging support for the OpsHostGuard system.

.DESCRIPTION
OpsBase provides low-level, dependency-light utilities required during the earliest phases
of OpsHostGuard execution. Its primary responsibilities include:

- Determining whether code is running in an integrated OpsHostGuard context or in standalone mode.
- Enabling controlled switching between standalone and integrated execution for selected modules.
- Providing a minimal logging buffer mechanism for use before higher-level logging infrastructure
  is available.

OpsBase is designed to be imported early and safely within a PowerShell session, without
triggering heavy initialization or requiring prior module dependencies.

.FEATURES
- **Execution Context Detection**: Determines whether execution occurs within the OpsHostGuard
  environment or as a standalone module.
- **Standalone / Integrated Mode Control**: Allows selected modules to be reloaded dynamically
  in standalone or integrated mode.
- **Early Logging Buffer**: Captures log messages before LogManager or other logging subsystems
  are initialized.
- **Minimal Dependency Footprint**: Avoids reliance on higher-level configuration or services.

.DEPENDENCY MODEL
OpsBase operates at the lowest level of the OpsHostGuard dependency hierarchy:

- It may rely on `$Global:ProjectRoot` if standalone switching is requested.
- It does not initialize global configuration structures.
- Some functions assume the presence of higher-level services (e.g., logging or configuration)
  when executed in an integrated environment.

OpsBase does not enforce dependency resolution and assumes correct orchestration by
higher-level modules.

.PURPOSE

1. **Context-Aware Execution**
   - Allow modules to adapt behavior depending on whether they are executed standalone
     or within the OpsHostGuard core environment.
   - Provide a single, explicit mechanism for context determination.

2. **Safe Bootstrap Utilities**
   - Enable logging and diagnostics before the logging subsystem is fully initialized.
   - Avoid hard dependencies during early execution phases.

3. **Operational Flexibility**
   - Support dynamic reloading of modules for development, testing, or isolated execution.
   - Allow controlled switching between execution modes without restarting the session.

4. **Session-Level Control**
   - Operate entirely within the scope of a single PowerShell session.
   - Avoid persistence or cross-session side effects.

.VARIABLE NAMING CONVENTION
- **Global variables** use `PascalCase` (e.g., `$Global:OpsHostGuardCalling`).
- **Local variables and parameters** use `camelCase`.

.AUTHOR
© 2024 Alberto Ledo  
Faculty of Documentation and Communication Sciences  
University of Extremadura  
Contact: albertoledo@unex.es

.VERSION
1.0.0

.HISTORY
1.0.0 – Initial release providing execution context detection, standalone mode control,
        and early logging utilities.

.DATE
November 24, 2024

.NOTES
- OpsBase is a foundational utility module, not a business-logic or orchestration component.
- Some functions assume the presence of higher-level modules when used in integrated mode.
- Standalone mode switching is an advanced feature and should be used with care.

.EXAMPLE
Scenario:
- A module checks whether it is running inside OpsHostGuard or standalone:

    Test-ExecutionContext -RootCheck

Result:
- The module adapts its behavior based on the detected execution context.

.DISCLAIMER
Provided "as-is" for internal use at the University of Extremadura.
No warranties, express or implied.

.LINK
https://github.com/n7rc/OpsHostGuard
#>

$Global:OpsBaseLogBuffer = @()

function Add-OpsBaseLogMessage {
    param (
        [string]$message,
        [string]$functionName = $MyInvocation.InvocationName,
        [string]$logLevel = "Info"
    )
    $timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    $logEntry = "[$timestamp] [$logLevel] [$functionName] $message"
    $Global:OpsBaseLogBuffer += $logEntry
}

function Clear-OpsBaseLogBuffer {
    param (
        [string]$logPath = $null
    )

    if ($Global:OpsBaseLogBuffer.Count -gt 0) {
        try {
            # Usar LogManager si ya está inicializado
            if (Get-Command -Name Add-OpsBaseLogMessage -ErrorAction SilentlyContinue) {
                foreach ($entry in $Global:OpsBaseLogBuffer) {
                    $parts = $entry -split "\] "
                    $timestamp = $parts[0] -replace '\[', ''
                    $logLevel = $parts[1] -replace '\[', ''
                    $message = $parts[2]

                    Add-OpsBaseLogMessage -message $message -logLevel $logLevel
                }
            }
            # Si no está inicializado, guardar en un archivo directo si `logPath` está disponible
            elseif ($logPath) {
                foreach ($entry in $Global:OpsBaseLogBuffer) {
                    $entry | Out-File -FilePath $logPath -Encoding UTF8 -Append
                }
            }

            # Limpiar el buffer después de volcar los mensajes
            $Global:OpsBaseLogBuffer = @()
        }
        catch {
            Write-Host "[Error] Failed to flush OpsBase log buffer: $_" -ForegroundColor Red
        }
    }
}


function Test-ExecutionContext {
    <#
    .SYNOPSIS
    Determines the execution context of the current script or module.

    .DESCRIPTION
    This function checks whether the current execution context is operating within the OpsHostGuard 
    root environment or as a standalone module. It supports two checks:
    - RootCheck: Verifies if the execution is initiated from the OpsHostGuard core environment.
    - ConsoleCheck: Verifies if the execution is in a standalone console mode.

    By leveraging a global variable `$Global:OpsHostGuardCalling`, this function provides a 
    robust and consistent mechanism to determine the current execution context, ensuring 
    that modules behave correctly in both core and standalone scenarios.

    .NOTES
    This function is part of the OpsBase module, designed to provide fundamental utilities for 
    OpsHostGuard and its standalone modules. It ensures minimal dependencies and is critical for 
    context-sensitive execution.

    .PARAMETER RootCheck
    Optional. Returns `$true` if the execution context is within the OpsHostGuard root environment, 
    `$false` otherwise.

    .PARAMETER ConsoleCheck
    Optional. Returns `$true` if the execution context is in a standalone console mode, `$false` 
    otherwise.

    .EXAMPLE
    Test-ExecutionContext -RootCheck
    Verifies if the script is executed from the OpsHostGuard core environment.

    .EXAMPLE
    Test-ExecutionContext -ConsoleCheck
    Checks if the script is running in a standalone console environment.

    .INPUTS
    None.

    .OUTPUTS
    [bool]
    A boolean value indicating the result of the context check.

    .NOTES
    - `$Global:OpsHostGuardCalling` must be set to a boolean value (`$true` or `$false`) to ensure 
      consistent behavior.
    - Throws an error if the global variable is undefined or set to an invalid type.
    #>
    param (
        [switch]$RootCheck, # Specify if checking for root (OpsHostGuard context)
        [switch]$ConsoleCheck  # Specify if checking for standalone console execution
    )
  
    # Ensure the global variable exists
    if (-not $Global:OpsHostGuardCalling) {
        $Global:OpsHostGuardCalling = $false  # Default to standalone if not explicitly set
    }

    # Validate type of the global variable
    if (-not ($Global:OpsHostGuardCalling -is [bool])) {
        throw "Invalid value for \$Global:OpsHostGuardCalling. Expected [bool], got [$($Global:OpsHostGuardCalling.GetType())]."
    }

    # Determine execution context
    if ($RootCheck) {
        return $Global:OpsHostGuardCalling  # True if called from OpsHostGuard, false otherwise
    }
    elseif ($ConsoleCheck) {
        return -not $Global:OpsHostGuardCalling  # True if standalone execution
    }

    # Default case if no specific check is requested
    throw "No valid context check specified. Use -RootCheck or -ConsoleCheck."
}

<#
Function: Set-Standalone
.SYNOPSIS
Enables standalone mode for executing standalone-specific commands.
.DESCRIPTION
This function activates standalone mode, which allows the use of standalone-specific commands and 
features. It ensures that the System transitions to standalone mode only if it is not already active, 
preventing unnecessary changes.
.PARAMETER on
Switch to enable standalone mode. If already in standalone mode, no changes are applied.
.OUTPUTS
Console messages indicating the activation of standalone mode or that no changes were needed.
.EXAMPLE
Enable standalone mode:
Set-Standalone -on
.NOTES
Standalone mode allows the execution of commands and functions that are designed to work 
independently of higher-level scripts or integrated environments.
#>
function Set-Standalone {

    param (
        [Parameter(Mandatory = $true)]
        [string]$moduleName, # Nombre del módulo
        [switch]$on, # Activar standalone
        [switch]$off          # Desactivar standalone
    )

    # Validación de parámetros
    if (-not ($on -xor $off)) {
        Write-Host "Error: Please specify either '-on' or '-off'." -ForegroundColor Red
        return
    }
   
    # Determinar la ruta del módulo
    $modulePath = Join-Path -Path $Global:ProjectRoot -ChildPath "modules/core/hosts_management/$moduleName/$moduleName.psd1"

    if (-not (Test-Path -Path $modulePath -PathType Leaf)) {
        Write-Host "Error: Module path does not exist: $modulePath" -ForegroundColor Red
        return
    }

    try {
        if ($on) {
            Write-Host "Switching $moduleName to standalone mode..." -ForegroundColor Cyan
            # Configuración de standalone
            $Global:OpsHostGuardCalling = $false
            $Global:StandaloneMode = $true
            Test-ExecutionContext -ConsoleCheck

            # Recargar el módulo
            if (Get-Module -Name $moduleName) {
                Write-Host "Removing existing instance of the $moduleName module..." -ForegroundColor Cyan
                Remove-Module -Name $moduleName -Force -ErrorAction Stop
                Start-Sleep -Seconds 2
                Get-Command -Module StartHosts | ForEach-Object { Remove-Item -Path "function:\$($_.Name)" -Force }
                if (Get-Module -Name $moduleName) {
                    Write-Host "Error: Module 'StartHosts' is still loaded. Force unloading..."
                    [System.AppDomain]::CurrentDomain.GetAssemblies() | 
                    Where-Object { $_.Location -like "*StartHosts*" } | 
                    ForEach-Object { [System.GC]::Collect() ; [System.GC]::WaitForPendingFinalizers() }
                    throw "Failed to unload module $moduleName."
                }
            }
            write-host $modulePath
            
            Import-Module -Name .\modules\core\hosts_management\StartHosts\StartHosts.psm1 -Scope Global -Force -ErrorAction Stop
            #$Global:OpsHostGuardCalling = $false
            #Test-ExecutionContext -ConsoleCheck
            
            if (-not (Get-Module -Name $moduleName)) {
                throw "Failed to load module $moduleName after import."
            }
            $commands = Get-Command -Module $moduleName
            if (-not $commands) {
                throw "Module $moduleName loaded, but no commands are available."
            }

            Write-Host "Standalone mode successfully activated for the $moduleName module." -ForegroundColor Green
        }
        elseif ($off) {
            Write-Host "Switching $moduleName to integrated mode..." -ForegroundColor Cyan
            # Configuración de modo integrado
            $Global:OpsHostGuardCalling = $true
            $Global:StandaloneMode = $false
            Test-ExecutionContext -RootCheck

            # Recargar el módulo
            if (Get-Module -Name $moduleName) {
                Write-Host "Removing existing instance of the $moduleName module..." -ForegroundColor Cyan
                Remove-Module -Name $moduleName -Force -ErrorAction Stop
                Start-Sleep -Seconds 2
                Get-Command -Module StartHosts | ForEach-Object { Remove-Item -Path "function:\$($_.Name)" -Force }
                if (Get-Module -Name $moduleName) {
                    Write-Host "Error: Module 'StartHosts' is still loaded. Force unloading..."
                    [System.AppDomain]::CurrentDomain.GetAssemblies() | 
                    Where-Object { $_.Location -like "*StartHosts*" } | 
                    ForEach-Object { [System.GC]::Collect() ; [System.GC]::WaitForPendingFinalizers() }
                    throw "Failed to unload module $moduleName."
                }
            }
            write-host $modulePath
          
            Import-Module -Name .\modules\core\hosts_management\StartHosts\StartHosts.psm1 -Scope Global -Force -ErrorAction Stop
            #$Global:OpsHostGuardCalling = $true
            #Test-ExecutionContext -RootCheck
          
            if (-not (Get-Module -Name $moduleName)) {
                throw "Failed to load module $moduleName after import."
            }
            $commands = Get-Command -Module $moduleName
            if (-not $commands) {
                throw "Module $moduleName loaded, but no commands are available."
            }

            Write-Host "Integrated mode successfully activated for the $moduleName module." -ForegroundColor Green
        }
    }
    catch {
        Write-Host "Error toggling standalone mode for the $moduleName module: $_" -ForegroundColor Red
    }
    
    
    
}


function Add-StandaloneDependency {
    <#
    .SYNOPSIS
    Adds a core dependency to the dependencies array with validation.

    .DESCRIPTION
    This function validates and creates a dependency object with a specified name, path, 
    and priority. The object is returned as a [PSCustomObject] for inclusion in the core 
    dependencies array. It ensures that only valid dependencies are processed, helping 
    maintain a clean and reliable configuration.

    The function performs validation to ensure that:
    - The `Name` is not null or empty.
    - The `Path` is not null or empty.
    - The `Priority` is a valid integer.

    If validation fails, the function logs a warning and skips adding the dependency.

    .NOTES
    This function is part of the OpsBase module, which provides fundamental utilities 
    for OpsHostGuard and its standalone modules. It supports modular and priority-based 
    dependency management.

    .PARAMETER Name
    The name of the core dependency.

    .PARAMETER Path
    The fully qualified path of the core dependency.

    .PARAMETER Priority
    The priority level of the dependency, used for sorting during initialization.

    .EXAMPLE
    Add-StandaloneDependency -Name 'CredentialsManager' -Path 'C:\path\to\module.psd1' -Priority 3
    Validates and returns a dependency object with the provided parameters.

    .EXAMPLE
    Add-StandaloneDependency -Name '' -Path 'C:\path\to\module.psd1' -Priority 3
    Logs a warning and returns `$null` because the `Name` is invalid.

    .INPUTS
    - [string] Name
    - [string] Path
    - [int] Priority

    .OUTPUTS
    [PSCustomObject]
    A validated dependency object with `Name`, `Path`, and `Priority` properties, or `$null` if validation fails.

    .NOTES
    - Use this function to standardize the creation of dependency objects.
    - Log messages are generated for invalid inputs for better debugging.

    #>
    param (
        [string]$Name,
        [string]$Path,
        [int]$Priority
    )

    if (-not [string]::IsNullOrWhiteSpace($Name) -and
        -not [string]::IsNullOrWhiteSpace($Path) -and
        $Priority -is [int]) {
        return [PSCustomObject]@{
            Name     = $Name
            Path     = $Path
            Priority = $Priority
        }
    }
    else {
        Add-OpsBaseLogMessage -message "Invalid dependency data for $Name. Skipping addition." -logLevel "Warning"
        return $null
    }
}

function Initialize-CoreStandalone {
    <#
    .SYNOPSIS
    Initializes the core OpsHostGuard configuration in standalone execution mode.

    .DESCRIPTION
    This function acts as a high-level initialization hook for standalone execution scenarios.
    It delegates the actual configuration setup to `Initialize-ConfigurationStandalone` and
    ensures that the process is logged using the active logging subsystem.

    This function assumes that:
    - `OpsInit` has been loaded and provides `Initialize-ConfigurationStandalone`
    - `LogManager` is available and provides `Add-LogMessage`

    It does not perform validation or reinitialization checks by design.
    #>

    Add-LogMessage -message "Initializing standalone core configuration..." -logLevel "Info"
    Initialize-ConfigurationStandalone
    Add-LogMessage -message "Standalone core configuration initialized successfully." -logLevel "Success"
}

Pause

Export-ModuleMember -Function Add-OpsBaseLogMessage, Clear-OpsBaseLogBuffer, Test-ExecutionContext, Set-Standalone, Add-StandaloneDependency, Initialize-CoreStandalone