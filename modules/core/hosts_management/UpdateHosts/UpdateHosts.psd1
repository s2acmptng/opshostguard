@{
    # Module manifest for 'Start-Hosts'
    RootModule        = 'UpdateHosts.psm1'
    ModuleVersion     = '2.4.0'

    # Required modules with specified versions
    RequiredModules = @(
    #@{ ModuleName = 'OpsInit'; ModuleVersion = '2.1.0' },
    #@{ ModuleName = 'LogManager'; ModuleVersion = '1.4.1' },
    #@{ ModuleName = 'SatndaloneCoreLog'; ModuleVersion = '1.1.0' }
    )

    # Module metadata
    Author            = 'Alberto Ledo'
    CompanyName       = 'Faculty of Documentation and Communication Sciences, University of Extremadura'
    Copyright         = '© 2024 Alberto Ledo'
    PowerShellVersion = '5.1'  
    CompatiblePSEditions = 'Core', 'Desktop'
    
    # Description of the module
    Description       = 'This module provides functions for managing and verifying Windows updates on specified hosts, 
                        supporting both local and remote update operations. It allows administrators to apply critical
                        and optional updates (excluding feature updates) to hosts within the network and verify Successful
                        installations. The module can be configured to utilize either native Windows Update functionality or
                        the PSWindowsUpdate module for enhanced flexibility.

                        Key functionalities include:

                        - `Invoke-WindowsUpdateNative`: Installs updates on selected hosts using the native Windows Update service.
                        - `Invoke-WindowsUpdatePsUpdate`: Applies updates on hosts via the PSWindowsUpdate module, enabling additional control and logging.
                        - `Invoke-TestUpdates`: Verifies updates installed on hosts, focusing on updates applied within the current day.
                        - `Update-Windows`: Main entry function that manages the update process and selects between native or PSWindowsUpdate methods based
                           on user configuration.

                        This module is tailored for use within the Faculty of Documentation and Communication Sciences at the University of Extremadura, 
                        facilitating centralized update management across multiple hosts and ensuring accurate logging and status reporting. 
                        It includes silent and Debug modes for refined control over output and logging behavior, essential for maintaining a 
                        streamlined and reliable update workflow.'

    # Functions to export
    FunctionsToExport = '*'
    
    # Export variables and aliases
    VariablesToExport = '*'
    AliasesToExport   = '*'

    # Cmdlets to Export (none specified, using "*")
    CmdletsToExport   = '*'

    # Scripts to process before or after importing the module (none needed here)
    ScriptsToProcess  = @()
    
    # External files included in the module
    FileList          = @(
        'UpdateHosts.psm1'
    )

    # Private data with additional module Information
    PrivateData = @{
        PSData = @{
            Tags         = @('OpsHostGuard', 'Wake-on-LAN', 'Windows Hosts', 'Host Availability', 'RPC Check')
            ProjectUri   = 'https://github.com/n7rc/OpsHostGuard'
            LicenseUri   = 'https://github.com/n7rc/OpsHostGuard/LICENSE'
            IconUri      = 'https://github.com/n7rc/OpsHostGuard/icon.png'
            ReleaseNotes = "
                1.0.0 - Initial script by Alberto Ledo for windows update hosts.
            "
        }
    }
}
