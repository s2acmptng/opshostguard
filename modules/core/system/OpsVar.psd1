@{
    # Module manifest for 'OpsVar'
    RootModule        = 'OpsVar.psm1'
    ModuleVersion     = '2.0.0'
    Author            = 'Alberto Ledo'
    CompanyName       = 'Faculty of Documentation and Communication Sciences, University of Extremadura'
    Copyright         = '© 2024 Alberto Ledo'

    # Supported PowerShell editions
    PowerShellVersion = '5.1'
    CompatiblePSEditions = 'Core', 'Desktop'

    Description       = 'This module defines and manages the core path configurations for the OpsHostGuard System, including
                         project root, data directories, credentials, dashboard paths, and log structures. It serves as a centralized
                         resource for retrieving and updating System paths dynamically, ensuring consistency across all modules.'

    # Functions to export
    FunctionsToExport = '*'

    # Private variables to make accessible
    VariablesToExport = @(
        'Config'
    )

    # Aliases to Export
    AliasesToExport   = '*'

    # Cmdlets to Export
    CmdletsToExport   = '*'

    # Scripts to process before or after importing the module (none needed here)
    ScriptsToProcess  = @()
    
    # External files (adjust paths relative to your project structure)
    FileList          = @(
        'OpsVar.psm1'
    )

    PrivateData = @{
        PSData = @{
            Tags         = @('OpsHostGuard', 'Configuration Paths', 'PowerShell Module', 'System Paths', 'Configuration Management')
            ProjectUri   = 'https://github.com/n7rc/OpsHostGuard'
            LicenseUri   = 'https://github.com/n7rc/OpsHostGuard/LICENSE'
            IconUri      = 'https://github.com/n7rc/OpsHostGuard/icon.png'
            ReleaseNotes = "
                1.0.0 - Initial release of OpsVar module, providing centralized management for core System paths and configurations within OpsHostGuard.
                1.1.0 - Improved internal structure and extensibility of global configuration.
                2.0.0 - Introduced controlled initialization of `$Global:Config` and centralized path definition.
            "
        }
    }
}
