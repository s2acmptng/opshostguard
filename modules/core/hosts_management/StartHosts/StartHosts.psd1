@{
    # Module manifest for 'Start-Hosts'
    RootModule        = 'StartHosts.psm1'
    ModuleVersion     = '1.2.1'
    RequiredModules = @(
    #@{ ModuleName = 'OpsInit'; ModuleVersion = '2.1.0' },
    #@{ ModuleName = 'LogManager'; ModuleVersion = '1.4.0' },
    #@{ ModuleName = 'SantandaloneCoreLog'; ModuleVersion = '1.0.0' }
    )
    Author            = 'Alberto Ledo'
    CompanyName       = 'Faculty of Documentation and Communication Sciences, University of Extremadura'
    Copyright         = '© 2024 Alberto Ledo'

    # Supported PowerShell editions
    PowerShellVersion = '5.1'  
    CompatiblePSEditions = @('Core', 'Desktop')
    
    Description       = 'This module sends a Wake-on-LAN (WOL) packet to wake up hosts in a specified group or individual host, validating readiness with RPC port 135 checks.'

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
        'StartHosts.psm1',
        'data/hosts_mac.json'
    )

    PrivateData = @{
        PSData = @{
            Tags         = @('OpsHostGuard', 'Wake-on-LAN', 'Windows Hosts', 'Host Availability', 'RPC Check')
            ProjectUri   = 'https://github.com/n7rc/OpsHostGuard'
            LicenseUri   = 'https://github.com/n7rc/OpsHostGuard/LICENSE'
            IconUri      = 'https://github.com/n7rc/OpsHostGuard/icon.png'
            ReleaseNotes = "
                1.1.0 - Modification of the Test-STHostUp function to make it reusable in other modules.
                1.0.1 - Converted to PowerShell module with separate functions for WOL, RPC validation, and host checks.
                1.0.0 - Initial script by Alberto Ledo for waking up hosts in predefined groups or individually with WOL.
            "
        }
    }
}
