# CreateDatabase.psm1 [OpsHostGuard - Database Initialization Utility]

<#
    .SYNOPSIS
    Utility module for initializing the OpsHostGuard database.

    .DESCRIPTION
    This module provides a function to initialize the OpsHostGuard database on a MySQL server. 
    It requires an SQL script file and MySQL credentials to create the database and its associated tables.

    .FUNCTIONS
    - Initialize-Database: Initializes the database using a specified SQL script and MySQL credentials.

    .EXAMPLES
    Initialize-Database -MySqlHost "localhost" -MySqlUser "root" -MySqlPassword "password" -SqlFilePath "C:\sql\opshostguard.sql"

    .NOTES
    This module is designed for isolated and optional use, and is not a core component of OpsHostGuard. 
    Configured for internal use at the University of Extremadura.

    .PARAMETERS
    - MySqlHost: Hostname of the MySQL server (default: localhost).
    - MySqlUser: MySQL username (default: root).
    - MySqlPassword: Password for the MySQL user (mandatory).
    - SqlFilePath: Path to the SQL file used to create the database.

    .AUTHOR [© 2024 Alberto Ledo]
    Alberto Ledo, Faculty of Documentation and Communication Sciences.
    Contact: albertoledo@unex.es

    .VERSION
    1.0.0

    .DATE
    November 16, 2024

    .DISCLAIMER
    Provided "as-is" for internal use. No warranties, express or implied. Modifications are not covered.
#>

function Initialize-Database {
    param (
        [string]$MySqlHost = "localhost",
        [string]$MySqlUser = "root",
        [string]$MySqlPassword,
        [string]$SqlFilePath = "$PSScriptRoot/../../../config/database/create_database.sql"
    )

    # Validate SQL file existence
    Write-Host "Validating SQL file: $SqlFilePath..." -ForegroundColor Yellow
    if (-not (Test-Path -Path $SqlFilePath)) {
        Write-Error "SQL file not found at $SqlFilePath"
        return
    }

    # Validate MySQL password
    if ([string]::IsNullOrWhiteSpace($MySqlPassword)) {
        Write-Error "MySQL password cannot be empty."
        return
    }

    try {
        # Construct the MySQL command
        #$arguments = "-h $MySqlHost -u $MySqlUser -p$MySqlPassword -e `SOURCE $SqlFilePath`"
        Write-Host "Executing database creation script..." -ForegroundColor Green

        # Run the MySQL command
        Start-Process -FilePath "mysql" -ArgumentList $arguments -NoNewWindow -Wait

        Write-Host "Database initialized successfully!" -ForegroundColor Green
    }
    catch {
        Write-Error "Failed to initialize the database. Error: $_"
    }
}

Export-ModuleMember -Function Initialize-Database
