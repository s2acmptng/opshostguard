@{
    # Module manifest for 'LogManager'
    RootModule        = 'ModuloPrueba.psm1'
    ModuleVersion     = '2.0.0'
    RequiredModules = @(
    #@{ ModuleName = 'OpsInit'; ModuleVersion = '2.0.0' },
    )
    Author            = 'Alberto Ledo'
    CompanyName       = 'Faculty of Documentation and Communication Sciences, University of Extremadura'
    Copyright         = '© 2024 Alberto Ledo'

    # Supported PowerShell editions
    PowerShellVersion = '5.1'  
    CompatiblePSEditions = 'Core', 'Desktop'
    
    # Description of the module
    Description       = 'This module provides essential data processing functions for OPsHostGuard, categorizing results and structuring
        logs for seamless integration. Ideal for handling operation outcomes and diagnostics.'

    # Functions to export
    FunctionsToExport = @(
        'Resolve-PowerOn',
        'Get-HostsFromGroup'
    )

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
        'ModuloPrueba.psm1'
    )

    PrivateData = @{
        PSData = @{
            Tags         = @('OpsHostGuard', 'Debugging', 'Data Processing', 'System Management')
            ProjectUri   = 'https://github.com/n7rc/OpsHostGuard'
            LicenseUri   = 'https://github.com/n7rc/OpsHostGuard/LICENSE'
            IconUri      = 'https://github.com/n7rc/OpsHostGuard/icon.png'
            ReleaseNotes = "
                1.1.0 - Added logging file System.
                1.0.0 - Initial release for Debugging and logging functions, enabling configurable Debug logging.
            "
        }
    }
}
