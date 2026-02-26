@{
    # Module manifest for 'OpsBase'
    RootModule        = 'OpsBase.psm1'
    ModuleVersion     = '1.0.0'
    Author            = 'Alberto Ledo'
    CompanyName       = 'Faculty of Documentation and Communication Sciences, University of Extremadura'
    Copyright         = '© 2024 Alberto Ledo'

    # Supported PowerShell editions
    PowerShellVersion = '5.1'
    CompatiblePSEditions = 'Core', 'Desktop'

    Description       = 'OpsBase provides fundamental utilities and checks for the OpsHostGuard System, 
                         including execution context determination and minimal dependency utilities 
                         to support core and standalone operations.'

    # Functions to export
    FunctionsToExport = '*'

    # Private variables to make accessible
    VariablesToExport = @()

    # Aliases to Export
    AliasesToExport   = '*'

    # Cmdlets to Export
    CmdletsToExport   = '*'

    # Scripts to process before or after importing the module (none needed here)
    ScriptsToProcess  = @()

    # External files (adjust paths relative to your project structure)
    FileList          = @(
        'OpsBase.psm1'
    )

    PrivateData = @{
        PSData = @{
            Tags         = @('OpsHostGuard', 'Execution Context', 'PowerShell Module', 'Standalone Mode', 'Utilities')
            ProjectUri   = 'https://github.com/n7rc/OpsHostGuard'
            LicenseUri   = 'https://github.com/n7rc/OpsHostGuard/LICENSE'
            IconUri      = 'https://github.com/n7rc/OpsHostGuard/icon.png'
            ReleaseNotes = "
                1.0.0 - Initial release of OpsBase module, including the Test-ExecutionContext function to 
                        determine execution context in OpsHostGuard environments.
            "
        }
    }
}
