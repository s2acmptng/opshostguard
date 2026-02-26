@{
    # Module manifest for module 'Stop-Hosts'
    RootModule        = 'StopHosts.psm1'
    ModuleVersion     = '1.3.0'
    RequiredModules = @(
    #@{ ModuleName = 'OpsInit'; ModuleVersion = '2.0.0' },
    #@{ ModuleName = 'LogManager'; ModuleVersion = '2.0.0' },
    #@{ ModuleName = 'ActiveSessions'; ModuleVersion = '2.0.0' },
    #@{ ModuleName = 'StartHosts'; ModuleVersion = '2.0.0' }
    )
    
    Author            = 'Alberto Ledo'
    CompanyName       = 'Faculty of Documentation and Communication Sciences, University of Extremadura'
    Copyright         = '© 2024 Alberto Ledo'

    # PowerShell Version
    PowerShellVersion = '5.1'
    CompatiblePSEditions = 'Core', 'Desktop'

    # Description of the module
    Description = 'Stop-Hosts module for OpsHostGuard. Automates the shutdown process for hosts, checking active sessions and verifying shutdown status via ping and RPC port.'

    # Functions to Export
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
        'StopHosts.psm1',
        '../../../config/host_groups.json'
    )

    PrivateData     = @{
        PSData = @{
            Tags         = @('Host Management', 'Shutdown Automation', 'OpsHostGuard', 'RPC Check')
            ProjectUri   = 'https://github.com/n7rc/OpsHostGuard'
            LicenseUri   = 'https://github.com/n7rc/OpsHostGuard/LICENSE'
            IconUri      = 'https://github.com/n7rc/OpsHostGuard/icon.png'
            ReleaseNotes = "
                1.3.0 - Incorporated functions Get-ASSessions and Test-STHostUp as replacements and added necessary module imports.
                1.2.3 - PowerShell standards adaptation and main logic improvement.
                1.2.0 - Added RPC port 135 verification for reliable shutdown confirmation.
                1.1.0 - Introduced Debug parameter and enhanced Error handling.
                1.0.0 - Initial release.
            "
        }
    }
}
