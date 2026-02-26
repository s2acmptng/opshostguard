@{
    # Module manifest for 'CredentialsManager'
    RootModule        = 'CredentialsManager.psm1'
    ModuleVersion     = '2.0.0'
    RequiredModules   = @(
        #@{ ModuleName = 'OpsVar'; ModuleVersion = '' },
        #@{ ModuleName = 'OpsInit'; ModuleVersion = '' },
        #@{ ModuleName = 'LogManager'; ModuleVersion = '1.4.0' }
    )
    Author            = 'Alberto Ledo'
    CompanyName       = 'Faculty of Documentation and Communication Sciences, University of Extremadura'
    Copyright         = '© 2024 Alberto Ledo'

    # Supported PowerShell editions
    PowerShellVersion = '5.1'
    CompatiblePSEditions = 'Core', 'Desktop'

    Description       = 'This module provides centralized credential management for OpsHostGuard, including secure retrieval of credentials for database operations and PSRemoting sessions.
                         It ensures consistency and security through the use of encrypted credential files.'

    # Functions to export
    FunctionsToExport = '*'

    # Variables to export (none required in this module)
    VariablesToExport = @()

    # Aliases to export (none defined in this module)
    AliasesToExport   = @()

    # Cmdlets to export (none defined in this module)
    CmdletsToExport   = @()

    # Scripts to process before or after importing the module (none required)
    ScriptsToProcess  = @()

    # External files referenced or required by the module
    FileList          = @(
        'CredentialsManager.psm1',
        '../../../config/ops_config.json',
        './credentials/ps_remoting.xml',   
        './credentials/user_db.xml',
        './credentials/passwd_db.xml',
        './credentials/user_dashboard.xml',
        './credentials/passwd_dashboard.xml'
        )
        

    PrivateData = @{
        PSData = @{
            Tags         = @('OpsHostGuard', 'Credentials Management', 'Security', 'PowerShell', 'Database', 'PSRemoting')
            ProjectUri   = 'https://github.com/n7rc/OpsHostGuard'
            LicenseUri   = 'https://github.com/n7rc/OpsHostGuard/LICENSE'
            IconUri      = 'https://github.com/n7rc/OpsHostGuard/icon.png'
            ReleaseNotes = "
                1.0.0 - Initial release of CredentialsManager module, providing secure credential management for database and PSRemoting.
            "
        }
    }
}
