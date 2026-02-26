@{
    # Module manifest for 'HostsLoad'
    RootModule        = 'HostsLoad.psm1'
    ModuleVersion     = '1.0.0'
    RequiredModules = @(
        #@{ ModuleName = 'OpsInit'; ModuleVersion = '2.1.0' },
        #@{ ModuleName = 'LogManager'; ModuleVersion = '1.4.0' },
        #@{ ModuleName = 'OpsUtils'; ModuleVersion = '1.0.0' }
    )

    Author            = 'Alberto Ledo'
    CompanyName       = 'Faculty of Documentation and Communication Sciences, University of Extremadura'
    Copyright         = '© 2024 Alberto Ledo'

    # Supported PowerShell editions
    PowerShellVersion = '5.1'
    CompatiblePSEditions = @('Core', 'Desktop')

    Description       = 'This module monitors the CPU, memory, and disk usage of specified Windows hosts, optionally exporting results to CSV format.'

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
        'HostsLoad.psm1',
        'data/host_groups.json'
    )

    PrivateData = @{
        PSData = @{
            Tags         = @('OpsHostGuard', 'Host Monitoring', 'Windows Hosts', 'Performance Metrics', 'CSV Export')
            ProjectUri   = 'https://github.com/n7rc/OpsHostGuard'
            LicenseUri   = 'https://github.com/n7rc/OpsHostGuard/LICENSE'
            IconUri      = 'https://github.com/n7rc/OpsHostGuard/icon.png'
            ReleaseNotes = "
                1.0.0 - Initial release with support for monitoring CPU, RAM, and disk usage. Includes CSV export functionality.
            "
        }
    }
}
