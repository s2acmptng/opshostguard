# Create-Credentials.ps1 [OpsHostGuard]

<#
    .SYNOPSIS
    Automates the secure creation and storage of credentials for PSRemoting, database access, and dashboard access,
    encrypting them with PowerShell's Export-Clixml for safe retrieval and usage in scripts.

    .DESCRIPTION
    This script securely collects and stores three sets of credentials required for administrative tasks in a Windows environment,
    saving them as encrypted XML files for later retrieval. The script prompts the user for each set of credentials and exports them
    in a format that can be imported for automated usage in scripts that require authentication.

    1. **PSRemoting Credentials:**
       - Prompts for user credentials and exports them securely to `PsRemotingCredential.xml` for authentication in remote PowerShell sessions.
       - Uses `Get-Credential` for secure credential input and encryption with Export-Clixml.

    2. **Database Access Credentials:**
       - Prompts for database user and password, encrypts, and saves them to `user_db.xml` and `passwd_db.xml`.
       - Credentials are saved as SecureStrings for secure retrieval and integration in PowerShell scripts using Marshal and SecureStringToBSTR.

    3. **Dashboard Access Credentials:**
       - Collects user and password for dashboard access, encrypts, and stores them as `user_dashboard.xml` and `passwd_dashboard.xml`.
       - This ensures safe storage and can be retrieved in PHP using PowerShell for integration in dashboard scripts.

    .EXAMPLE:
    .\Create-Credentials.ps1
    This example will execute the script and prompt the user for credentials for PSRemoting, database access, and dashboard access,
    then save these credentials as encrypted XML files in the specified directory (`./credentials/`).

    .PARAMETER -None
    This script does not accept any parameters. It prompts the user interactively for credential input.

    .NOTES
    - Requires administrative privileges to save credentials in secure XML format.
    - Credentials are stored as SecureStrings to ensure they remain encrypted and protected within the Windows environment.
    - Uses Export-Clixml for encryption, which binds to the user profile that created it, adding an additional layer of security.
    - Example commands to import the saved credentials are provided in the output after Successful storage.

    .ORGANIZATION
    Developed for: Faculty of Documentation and Communication Sciences at the University of Extremadura.

    .AUTHOR [© 2024 Alberto Ledo]
    Alberto Ledo [Faculty of Documentation and Communication Sciences] - with assistance from OpenAI
    IT Department: University of Extremadura - IT Services for Facilities
    Contact: albertoledo@unex.es

    .@Copyright
    © 2024 Alberto Ledo

    .VERSION
    1.0.0

    .HISTORY
    1.0.0 - Initial version by Alberto Ledo.

    .USAGE
    This script is strictly for internal use within University of Extremadura.
    The script is designed to operate within the IT infrastructure and environment of University of Extremadura
    and may not function as expected in other environments.

    .DATE
    October 28, 2024 13:55

    .DISCLAIMER
    This script is provided "as-is" and is intended for internal use at University of Extremadura.
    No warranties, express or implied, are provided. Any modifications or adaptations are not covered
    under this disclaimer.

    .LINK
    https://github.com/n7rc/OpsHostGuard
    https://n7rc.gitbook.io/
#>

# Path to store credentials
$credPath = "../credentials"
if (!(Test-Path -Path $credPath)) {
    New-Item -ItemType Directory -Path $credPath | Out-Null
}

# 1. Obtain and store credentials for PSRemoting
if (-not $global:silentMode) {
    Add-LogMessage "Enter PSRemoting credentials:"
}
$psRemotingCred = Get-Credential
$psRemotingCred | Export-Clixml -Path "$credPath\ps_remoting.xml"
if (-not $global:silentMode) {
    Add-LogMessage "PSRemoting credentials have been saved."
}

# 2. Obtain and store database credentials
if (-not $global:silentMode) {
    Add-LogMessage "Enter Database credentials:"
}
$dataBaseUser = Read-Host "Database User"
$dataBasePasswd = Read-Host -AsSecureString "Database Password"

# Save database credentials as SecureString in XML files
$dataBaseUser | ConvertTo-SecureString -AsPlainText -Force | Export-Clixml -Path "$credPath\user_db.xml"
$dataBasePasswd | Export-Clixml -Path "$credPath\passwd_db.xml"
if (-not $global:silentMode) {
    Add-LogMessage "Database credentials have been saved."
}

# 3. Obtain and store credentials for the dashboard
if (-not $global:silentMode) {
    Add-LogMessage "Enter Dashboard credentials:"
}
$dashboardUser = Read-Host "Dashboard User"
$dashboardPasswd = Read-Host -AsSecureString "Dashboard Password"

# Save dashboard credentials as SecureString in XML files
$dashboardUser | ConvertTo-SecureString -AsPlainText -Force | Export-Clixml -Path "$credPath\user_dashboard.xml"
$dashboardPasswd | Export-Clixml -Path "$credPath\passwd_dashboard.xml"
if (-not $global:silentMode) {
    Add-LogMessage "Dashboard credentials have been saved."
}
if (-not $global:silentMode) {
    Add-LogMessage "Process completed."
}

<#
# Additional instructions for importing each group of credentials
if (-not $global:silentMode) {
    Add-LogMessage "Credentials saved. To import, use the following commands:"
}

if (-not $global:silentMode) {
    Add-LogMessage "1. PSRemoting credentials:"
}
if (-not $global:silentMode) {
    Add-LogMessage "`$psRemotingCred = Import-Clixml -Path './credentials/PsRemotingCredential.xml'"
}

if (-not $global:silentMode) {
    Add-LogMessage "2. Database credentials:"
}
if (-not $global:silentMode) {
    Add-LogMessage "`$dataBaseUser = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto("
}
if (-not $global:silentMode) {
    Add-LogMessage "    [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR("
}
if (-not $global:silentMode) {
    Add-LogMessage "        (Import-Clixml -Path './credentials/user_db.xml')"
}
if (-not $global:silentMode) {
    Add-LogMessage "    )"
}
if (-not $global:silentMode) {
    Add-LogMessage ")"
}

if (-not $global:silentMode) {
    Add-LogMessage "`$dataBasePasswd = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto("
}
if (-not $global:silentMode) {
    Add-LogMessage "    [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR("
}
if (-not $global:silentMode) {
    Add-LogMessage "        (Import-Clixml -Path './credentials/passwd_db.xml')"
}
if (-not $global:silentMode) {
    Add-LogMessage "    )"
}
if (-not $global:silentMode) {
    Add-LogMessage ")"
}

if (-not $global:silentMode) {
    Add-LogMessage "3. Dashboard credentials:"
}
if (-not $global:silentMode) {
    Add-LogMessage "`$getDashboardUser = 'powershell.exe -ExecutionPolicy Bypass -Command \"
}`"
if (-not $global:silentMode) {
    Add-LogMessage "    `[System.Runtime.InteropServices.Marshal]::PtrToStringAuto(`"
}
if (-not $global:silentMode) {
    Add-LogMessage "        [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR(`"
}
if (-not $global:silentMode) {
    Add-LogMessage "            (Import-Clixml -Path \"
}`.\\cred\\user_dashboard.xml\"`)`"
if (-not $global:silentMode) {
    Add-LogMessage "        )`"
}
if (-not $global:silentMode) {
    Add-LogMessage "    )\"
};`'"

if (-not $global:silentMode) {
    Add-LogMessage "`$getDashboardPasswd = 'powershell.exe -ExecutionPolicy Bypass -Command \"
}`"
if (-not $global:silentMode) {
    Add-LogMessage "    `[System.Runtime.InteropServices.Marshal]::PtrToStringAuto(`"
}
if (-not $global:silentMode) {
    Add-LogMessage "        [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR(`"
}
if (-not $global:silentMode) {
    Add-LogMessage "            (Import-Clixml -Path \"
}`.\\cred\\passwd_dashboard.xml\"`)`"
if (-not $global:silentMode) {
    Add-LogMessage "        )`"
}
if (-not $global:silentMode) {
    Add-LogMessage "    )\"
};`'"
#>
