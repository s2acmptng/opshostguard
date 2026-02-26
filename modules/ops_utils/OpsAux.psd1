@{
    # Module manifest for 'OpsAux'
    RootModule        = 'OpsAux.psm1'
    ModuleVersion     = '1.0.0'
    RequiredModules   = @()
    Author            = 'Alberto Ledo'
    CompanyName       = 'Faculty of Documentation and Communication Sciences, University of Extremadura'
    Copyright         = '© 2024 Alberto Ledo'

    # Supported PowerShell editions
    PowerShellVersion = '5.1'
    CompatiblePSEditions = 'Core', 'Desktop'

    # Description of the module
    Description       = 'This module provides auxiliary functions for OpsHostGuard, focusing on intermediate data processing 
        tasks such as resolving power-on results, managing diagnostics, and enabling smooth integration with main scripts.'

    # Functions to export
    FunctionsToExport = '*'

    # Private variables to make accessible
    VariablesToExport = @()

    # Aliases to Export
    AliasesToExport   = @()

    # Cmdlets to Export
    CmdletsToExport   = @()

    # Scripts to process before or after importing the module (none needed here)
    ScriptsToProcess  = @()

    # External files
    FileList          = @(
        'OpsAux.psm1'
    )

    PrivateData = @{
        PSData = @{
            Tags         = @('OpsHostGuard', 'Auxiliary Functions', 'Diagnostics', 'System Management')
            ProjectUri   = 'https://github.com/n7rc/OpsHostGuard'
            LicenseUri   = 'https://github.com/n7rc/OpsHostGuard/LICENSE'
            IconUri      = 'https://github.com/n7rc/OpsHostGuard/icon.png'
            ReleaseNotes = "
                1.0.0 - Initial release including the Resolve-PowerOn function for processing power-on diagnostics.
            "
        }
    }
}
