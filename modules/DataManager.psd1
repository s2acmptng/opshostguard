@{
    # Module manifest for 'DataManager'
    RootModule        = 'DataManager.psm1'
    ModuleVersion     = '1.0.0'
    RequiredModules = @(
        # Add any required modules here, if applicable
    )
    Author            = 'Alberto Ledo'
    CompanyName       = 'Faculty of Documentation and Communication Sciences, University of Extremadura'
    Copyright         = '© 2024 Alberto Ledo'

    # Supported PowerShell editions
    PowerShellVersion = '5.1'
    CompatiblePSEditions = 'Core', 'Desktop'

    Description       = 'This module provides functions and utilities for data management within the OpsHostGuard system.
                        It includes features for interacting with databases, handling data imports and exports, and performing 
                        data validation and transformation operations. The module serves as a backbone for managing 
                        structured and unstructured data in various components of OpsHostGuard.'

    # Functions to export
    FunctionsToExport = '*'  # Export all functions

    # Private variables to make accessible
    VariablesToExport = '*'

    # Aliases to Export
    AliasesToExport   = '*'

    # Cmdlets to Export
    CmdletsToExport   = '*'

    # Scripts to process before or after importing the module
    ScriptsToProcess  = @()

    # External files
    FileList          = @(
        'DataManager.psm1',
        '../../config/database_config.json',
        '../../data/import_templates.json',
        '../../log/data_operations.log',
        '../../.VERSION'
    )

    PrivateData = @{
        PSData = @{
            Tags         = @('OpsHostGuard', 'Data Management', 'Database Operations', 'Data Validation', 'Data Transformation')
            ProjectUri   = 'https://github.com/n7rc/OpsHostGuard'
            LicenseUri   = 'https://github.com/n7rc/OpsHostGuard/LICENSE'
            IconUri      = 'https://github.com/n7rc/OpsHostGuard/icon.png'
            ReleaseNotes = "
                1.0.0 - Initial release of DataManager module, providing core data management functions for OpsHostGuard.
            "
        }
    }
}
