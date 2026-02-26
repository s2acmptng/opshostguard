@{
    # Module manifest for 'LogManager'
    # Comment: Integrated module in OpsHostGuard, not for standalone use.
    RootModule        = 'LogManager.psm1'
    ModuleVersion     = '2.1.1'
    RequiredModules   = @()
    Author            = 'Alberto Ledo'
    CompanyName       = 'Faculty of Documentation and Communication Sciences, University of Extremadura'
    Copyright         = '© 2024 Alberto Ledo'

    # Supported PowerShell editions
    PowerShellVersion = '5.1'  
    CompatiblePSEditions = 'Core', 'Desktop'
    
    # Description of the module
    Description       = 'This module provides Debugging capabilities for OpsHostGuard, with functions to log messages an log file based on global
                        Debugging settings.'

    # Functions to export
    FunctionsToExport = '*'

    # Private variables to make accessible
    VariablesToExport = '*'

    # Aliases to Export
    AliasesToExport   = '*'

    # Cmdlets to Export
    CmdletsToExport   = '*'

    # Scripts to process before or after importing the module (none needed here)
    ScriptsToProcess  = @()
    
    # External files
    FileList          = @(
        'LogManager.psm1'
    )

    PrivateData = @{
        PSData = @{
            Tags         = @('OpsHostGuard', 'Debugging', 'Logging', 'System Management')
            ProjectUri   = 'https://github.com/n7rc/OpsHostGuard'
            LicenseUri   = 'https://github.com/n7rc/OpsHostGuard/LICENSE'
            IconUri      = 'https://github.com/n7rc/OpsHostGuard/icon.png'
            ReleaseNotes = "
                2.0.0 - Refactoring and bug fixing.
                1.1.0 - Added logging file System.
                1.0.0 - Initial release for Debugging and logging functions, enabling configurable Debug logging.
            "
        }
    }
}
