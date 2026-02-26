# CredentialsManager.psm1 [OpsHostGuard - Centralized Credentials Management Module]

<#
.SYNOPSIS
Centralized credentials management module for OpsHostGuard.

.DESCRIPTION
This module provides a secure and consistent mechanism for managing credentials required by various components 
of the OpsHostGuard System. It supports storing, retrieving, and initializing credentials for a variety of 
use cases, such as:
- Database operations.
- Dashboard authentication.
- PowerShell remoting (PSRemoting).
- Audit logging for credential retrieval.

### Key Features:
1. **Secure Credential Management**:
   - Retrieves and decrypts credentials stored as SecureString objects in Clixml files.
   - Provides PowerShell remoting credentials (`PSCredential`) for secure operations.
   - Ensures secure cleanup of plaintext credentials from memory.

2. **Initialization and Validation**:
   - Ensures global remoting credentials are initialized and ready for use.
   - Validates credential file paths and ensures they exist before attempting retrieval.

3. **Robust Error Handling**:
   - Logs errors and warnings for missing files or invalid credentials.
   - Uses a centralized logging mechanism for all operations, integrating with OpsHostGuard's LogManager module.

4. **Audit Support**:
   - Logs credential access attempts for compliance and debugging.

### Dependencies:
This module integrates with:
- **OpsVar** and **OpsInit** for configuration and path definitions.
- **LogManager** for structured logging and error handling.

.EXPORTED FUNCTIONS
- `Get-Credential`: Retrieves plaintext credentials from secure Clixml files.
- `Get-PsRemotingCredential`: Retrieves a PowerShell `PSCredential` object for remoting operations.
- `Initialize-GlobalPsRemotingCredential`: Initializes the global remoting credential.
- `Import-ModuleIfMissing`: Ensures safe importing of dependent modules with logging.
- `Validate-Path`: Validates module paths and ensures they exist.

.NOTES
- Credentials files must be securely created using `Export-Clixml` and stored in designated paths.
- All operations are logged for debugging and audit purposes.
- The module is designed to ensure maintainability and minimize code redundancy.

.ORGANIZATION
Developed for: Faculty of Documentation and Communication Sciences, University of Extremadura.

.AUTHOR [© 2024 Alberto Ledo]
Alberto Ledo, Faculty of Documentation and Communication Sciences, with support from OpenAI.
IT Department: University of Extremadura - IT Services for Facilities.
Contact: albertoledo@unex.es

.VERSION
2.0.0

.HISTORY
2.0.0 - Added functions for module safety import and path validation.
1.1.0 - Introduced audit logging for credential access.
1.0.0 - Initial release of the CredentialsManager module with core credential retrieval functions.

.DATE
November 23, 2024

.DISCLAIMER
This module is provided "as-is" for internal use within the University of Extremadura.
No warranties, express or implied, are provided. Unauthorized modifications are not supported.

.LINK
OpsHostGuard Documentation: https://github.com/n7rc/OpsHostGuard
#>

<#
This module is not intended to be used independently.
It is a dependent module that requires the following modules to function:
OpsVar
OpsInit
LogManager
Attempting to load this module independently will result in errors if the dependencies are not loaded.
#>

<#
#Requires -Module OpsInit
#Requires -Module OpsBase
#>

param(
<#
.PARAMETER $Global:PsRemotingCredential
.SYNOPSIS
Global variable storing PowerShell remoting credentials.
.DESCRIPTION
The `$Global:PsRemotingCredential` variable is a global PowerShell `PSCredential` object 
used to authenticate and execute remote operations securely within the OpsHostGuard framework. 
It ensures a centralized and consistent way to access remoting credentials across different 
modules and functions.

### Key Features:
1. **Centralized Management**:
   - All remoting operations retrieve credentials from this variable, ensuring consistency.
   - Initialized once and reused, avoiding redundant credential file parsing.

2. **Security Considerations**:
   - The variable is initialized using the `Initialize-GlobalPsRemotingCredential` function.
   - It must always store a valid `PSCredential` object to prevent runtime errors.
   - Designed to avoid storing plaintext credentials in memory.

.NOTES
- The credential file used to initialize this variable must be created using `Export-Clixml`.
- This variable is null until explicitly initialized.

.EXAMPLES
Example: Use `$Global:PsRemotingCredential` for a remote command.
```powershell
Invoke-Command -ComputerName "Server01" -Credential $Global:PsRemotingCredential -ScriptBlock { Get-Service }
#>
    [pscredential]$Global:PsRemotingCredential
)

write-host $Global:ProjectRoot


#$scriptDirectory = (Get-Item -Path $MyInvocation.MyCommand.Definition).DirectoryName
#$Global:ProjectRoot = (Resolve-Path -Path (Join-Path -Path $scriptDirectory -ChildPath "../../")).Path

<#
#if ($Global:ProjectRoot) {
#    $Script:ProjectRoot = $Global:ProjectRoot
#}
#else {
    try {
        if ($null -ne $PSScriptRoot -and $PSScriptRoot -ne "") {
            # $PSScriptRoot is available (executing as a module or script)
            $Script:ProjectRoot = (Resolve-Path -Path (Join-Path -Path $PSScriptRoot -ChildPath "../../")).Path
        }
        else {
            # $PSScriptRoot is not available (imported from console)
            $scriptDirectory = (Get-Item -Path $MyInvocation.MyCommand.Definition).DirectoryName
            $Global:ProjectRoot = (Resolve-Path -Path (Join-Path -Path $scriptDirectory -ChildPath "../../")).Path
        }
    }
    catch {
        Write-Host "[Warning] Failed to resolve ProjectRoot dynamically. Error: $_" -ForegroundColor Red
        throw
    }
#}
#>
# Load OpsBase module
$opsBasePath = Join-Path -Path $Global:ProjectRoot -ChildPath "modules/core/system/OpsBase.psd1"

if (-not $Global:Config.Paths) {
    throw "Critical Error: OpsVar did not initialize Paths."
}
# Validate essential keys in Config.Paths
if (-not $Global:Config.Paths.Log -or -not $Global:Config.Paths.Log.Root) {
    throw "Critical Error: Missing required log paths in OpsVar."
}

# Import the OpsBase module globally with Error handling
if (-not (Get-Module -Name OpsBase)) {
    Import-ModuleOps -ModuleName "OpsBase" -ModulePath $opsBasePath
}

# Validate core modules
if (-not (Get-Module -Name OpsVar)) {
    Add-OpsBaseLogMessage -message "OpsVar module is missing. Please ensure it is loaded." -logLevel "Error"
}

if (-not (Get-Module -Name OpsInit)) {
    Add-OpsBaseLogMessage -message "OpsInit module is missing. Please ensure it is loaded." -logLevel "Error"
}

if (-not (Get-Module -Name LogManager)) {
    Add-OpsBaseLogMessage -message "LogManager module is missing. Please ensure it is loaded." -logLevel "Error"
}

if (-not (Get-Module -Name OpsBase)) {
    Add-OpsBaseLogMessage -message "OpsBase module is missing. Please ensure it is loaded." -logLevel "Error"
}

# Initialize security configuration data
Initialize-SecurityData

Write-host $Global:Config.Security
Write-host $Global:Config.Security.Files
Write-host $Global:Config.Security.Files.PsRemotingCredential

# Validate the existence of critical global variables
if (-not $Global:Config.Paths.Credentials) {
    throw "Credentials path is not defined. Ensure that OpsVar or the initialization module has been executed."
}

if (-not $Global:Config.Security.Files.PsRemotingCredential) {
    throw "PSRemoting credential path is not defined in OpsVar or the configuration file."
}

# Initialize the global credential variable if not already defined
if (-not $Global:PsRemotingCredential) {
    $Global:PsRemotingCredential = $null
}

function Get-Credential {
    <#
    .SYNOPSIS
    Retrieves and decrypts a secure credential from a file.
    .DESCRIPTION
    Retrieves a credential stored as a serialized SecureString in a Clixml file.
    Converts the SecureString to plaintext for use. Logs operations and errors.
    #>
    param (
        [string]$credentialFilePath
    )

    # Validate that the input is not null or empty
    if ([string]::IsNullOrWhiteSpace($credentialFilePath)) {
        Add-LogMessage -message "Credential file path is null or empty." -functionName $MyInvocation.InvocationName -logLevel "Error"
        throw "Error: Credential file path is required and cannot be null or empty."
    }

    # Log the start of the operation
    Add-LogMessage -message "Attempting to retrieve credential from file: $credentialFilePath" -functionName $MyInvocation.InvocationName -logLevel "Info"

    # Validate the existence of the file
    if (-not (Test-Path -Path (Join-Path $Global:ProjectRoot -ChildPath $credentialFilePath))) {
        Add-LogMessage -message "Credential file not found at path: $credentialFilePath" -functionName $MyInvocation.InvocationName -logLevel "Error"
        throw "Error: Credential file not found at $credentialFilePath"
    }

    try {
        # Import and decrypt the credential securely
        $SecureString = Import-Clixml -Path (Join-Path $Global:ProjectRoot -ChildPath $credentialFilePath)
        $Credential = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto( `
            [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecureString) `
        )

        # Log success
        Add-LogMessage -message "Successfully retrieved credential from file: $credentialFilePath" -functionName $MyInvocation.InvocationName -logLevel "Success"
        Add-LogMessage -message "Credential retrieved for file: $credentialFilePath at $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -logLevel "Audit"
        return $Credential

    }
    finally {
        # Clean up memory used by the plaintext
        if ($Credential) {
            [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecureString))
        }
    }
    catch {
        Add-LogMessage -message "Failed to retrieve credential from file: $credentialFilePath. Error: $_" -functionName $MyInvocation.InvocationName -logLevel "Error"
        throw "Error retrieving credential from file: $_"
    }
}

function Get-PsRemotingCredential {
    <#
    .SYNOPSIS
    Retrieves a `PSCredential` object for remoting.
    .DESCRIPTION
    Retrieves a PowerShell remoting credential from a Clixml file.
    Validates file existence and ensures it contains a valid PSCredential.
    #>
    param (
        [string]$credentialFilePath = 
        (Join-Path -Path $Global:ProjectRoot -ChildPath $Global:Config.Security.Files.PsRemotingCredential)
    )

    write-host $Global:ProjectRoot
    write-host $Global:Config.Security.Files.PsRemotingCredential
    write-host $credentialFilePath

    # Log the start of the operation
    Add-LogMessage -message "Attempting to retrieve PSRemoting credentials from file: $credentialFilePath" -functionName $MyInvocation.InvocationName -logLevel "Info"


    # Validate the existence of the file
    if (-not (Test-Path -Path $credentialFilePath)) {
        Add-LogMessage -message "PSRemoting credential file not found at $credentialFilePath" -functionName $MyInvocation.InvocationName -logLevel "Error"
        throw "PSRemoting credential file not found at $credentialFilePath"
    }

    try {
        # Import the credential file and ensure it is a single PSCredential object
        $PSCredential = Import-Clixml -Path $credentialFilePath | Select-Object -First 1

        # Validate that the result is a PSCredential object
        if (-not ($PSCredential -is [System.Management.Automation.PSCredential])) {
            Add-LogMessage -message "Invalid format: The file does not contain a valid PSCredential object." -functionName $MyInvocation.InvocationName -logLevel "Error"
            throw "Invalid format: The file does not contain a valid PSCredential object."
        }

        # Log and return the credential
        Add-LogMessage -message "Successfully retrieved PSRemoting credentials from file" -functionName $MyInvocation.InvocationName -logLevel "Success"
        return $PSCredential
    }
    catch {
        Add-LogMessage -message "Failed to retrieve PSRemoting credentials from file: $credentialFilePath. Error: $_" -functionName $MyInvocation.InvocationName -logLevel "Error"
        throw "Error retrieving PSRemoting credentials: $_"
    }
}

function Initialize-GlobalPsRemotingCredential {
    <#
    .SYNOPSIS
    Initializes `$Global:PsRemotingCredential` from a secure file.
    .DESCRIPTION
    Ensures `$Global:PsRemotingCredential` is populated with a valid `PSCredential`.
    Uses `Get-PsRemotingCredential` for retrieval.
    #>
    param (
        [string]$credentialFilePath = 
        (Join-Path -Path $Global:ProjectRoot -ChildPath $Global:Config.Security.Files.PsRemotingCredential)
    )
    if (-not $Global:PsRemotingCredential) {
        $Global:PsRemotingCredential = Get-PsRemotingCredential -credentialFilePath $credentialFilePath
    }
}

Export-ModuleMember -Function Get-Credential, Initialize-GlobalPsRemotingCredential
