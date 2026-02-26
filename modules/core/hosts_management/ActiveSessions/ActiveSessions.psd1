@{
    # Module manifest for module 'ActiveSessions'
    RootModule        = 'ActiveSessions.psm1'
    ModuleVersion     = '1.4.0'
    RequiredModules = @(
    #@{ ModuleName = 'OpsInit'; ModuleVersion = '2.0.0' },
    #@{ ModuleName = 'LogManager'; ModuleVersion = '2.0.0' },
    #@{ ModuleName = 'SantandaloneCoreLog'; ModuleVersion = '1.0.0' }
    )
    Author            = 'Alberto Ledo'
    CompanyName       = 'Faculty of Documentation and Communication Sciences, University of Extremadura'
    Copyright         = '© 2024 Alberto Ledo'

    # PowerShell Version
    PowerShellVersion = '5.1'  
    CompatiblePSEditions = 'Core', 'Desktop'

    # Description of the module
    Description = 'ActiveSessions module for OpsHostGuard. Collects and exports active session data from specified Windows hosts.'
    
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
        'ActiveSessions.psm1',
         '../../../config/host_groups.json'
    )

    PrivateData     = @{
        PSData = @{
            Tags         = @('Active Sessions', 'Windows Hosts', 'OpsHostGuard', 'CSV Export')
            ProjectUri   = 'https://github.com/n7rc/OpsHostGuard'
            LicenseUri   = 'https://github.com/n7rc/OpsHostGuard/LICENSE'
            IconUri      = 'https://github.com/n7rc/OpsHostGuard/icon.png'
            ReleaseNotes = "
                1.4.0 - Modification of the Get-ASSessions function to make it reusable in other modules.
                1.3.1 - Bug fixes and enhanced Debug Information.
                1.3.0 - Added Invoke-ASCheck as the primary function, refactored to avoid duplicates.
                1.2.0 - Introduced Error handling and Debug parameter.
                1.1.0 - Refactored for readability.
                1.0.0 - Initial release.
            "
        }
    }   
}
