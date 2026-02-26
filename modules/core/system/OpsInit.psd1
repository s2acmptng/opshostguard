@{
    # Module manifest for 'OpsInit'
    RootModule        = 'OpsInit.psm1'
    ModuleVersion     = '3.0.0'
    RequiredModules = @(
        #@{ ModuleName = 'OpsVar'; ModuleVersion = '1.0.0' },
        #@{ ModuleName = 'LogManager'; ModuleVersion = '1.4.0' }
    )
    Author            = 'Alberto Ledo'
    CompanyName       = 'Faculty of Documentation and Communication Sciences, University of Extremadura'
    Copyright         = '© 2024 Alberto Ledo'

    # Supported PowerShell editions
    PowerShellVersion = '5.1'  
    CompatiblePSEditions = 'Core', 'Desktop'
    
    Description       = 'This module centralizes the configuration used within the OpsHostGuard System, including configuration files.
                        It provides functions to dynamically retrieve and update these paths for enhanced flexibility and organization.'

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
        'OpsInit.psm1',
        '../../config/user_config.json',
        '../../config/host_groups.json',
        '../../credentials/ps_remoting.xml',
        '../../.VERSION',
        '../../log/opshostguard.log'
    )

    PrivateData = @{
        PSData = @{
            Tags         = @('OpsHostGuard', 'Configuration Paths', 'PowerShell Module', 'System Paths', 'Configuration Management')
            ProjectUri   = 'https://github.com/n7rc/OpsHostGuard'
            LicenseUri   = 'https://github.com/n7rc/OpsHostGuard/LICENSE'
            IconUri      = 'https://github.com/n7rc/OpsHostGuard/icon.png'
            ReleaseNotes = "
                1.0.0 - Initial release of OpsInit module, providing centralized management for System paths and configurations within OpsHostGuard.
            "
        }
    }
}
