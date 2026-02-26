@{
    # Module manifest for 'OpsDataTemplate'
    RootModule        = 'OpsDataTemplate.psm1'
    ModuleVersion     = '2.0.0'
    RequiredModules   = @()
    Author            = 'Alberto Ledo'
    CompanyName       = 'Faculty of Documentation and Communication Sciences, University of Extremadura'
    Copyright         = '© 2024 Alberto Ledo'

    # Supported PowerShell editions
    PowerShellVersion = '5.1'  
    CompatiblePSEditions = @('Core', 'Desktop')
    
    Description       = 'This module provides a centralized definition of data templates used within OpsHostGuard. 
                         These templates align with the database schema and support both internal operations 
                         and external integrations, such as a REST API.'

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
        'OpsDataTemplate.psm1'
    )

    PrivateData = @{
        PSData = @{
            Tags         = @('OpsHostGuard', 'Data Templates', 'PowerShell Module', 'Data Structures')
            ProjectUri   = 'https://github.com/n7rc/OpsHostGuard'
            LicenseUri   = 'https://github.com/n7rc/OpsHostGuard/LICENSE'
            IconUri      = 'https://github.com/n7rc/OpsHostGuard/icon.png'
            ReleaseNotes = "
                2.0.0 - Restructured templates to align with the updated database schema. 
                        Added modularity for enhanced maintainability and expansion.
                1.0.0 - Initial release of the OpsDataTemplate module.
            "
        }
    }
}
