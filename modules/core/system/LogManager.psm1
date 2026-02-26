# LogManager.psm1 [OpsHostGuard Logging Module]

<#
.SYNOPSIS
Centralized logging management for the OpsHostGuard System, including initialization, rotation, and structured log writing.

.DESCRIPTION
The `LogManager` module provides a comprehensive framework for logging operations in OpsHostGuard, ensuring consistent 
and efficient log management across the application. Its features include log initialization, rotation, fallback handling, 
and structured logging with support for customizable and silent mode.

**Core Features**:
1. **Log Initialization**:
   - Creates and prepares primary log files during system startup.
   - Transfers entries from fallback logs into the main log.

2. **Log Rotation**:
   - Automatically rotates log files exceeding a predefined size (default: 10 MB).
   - Compresses rotated logs and enforces retention policies to optimize storage.

3. **Fallback Handling**:
   - Ensures continuity with a fallback log when the main log is inaccessible.
   - Reintegrates fallback logs into the primary log during initialization.

4. **Structured Logging**:
   - Logs detailed entries with timestamps, log levels, and contextual information.
   - Supports color-coded console output for various log levels (e.g., Info, Warning, Error).

5. **Customizable and Silent Mode**:
   - Allows suppression of console output for silent operations.
   - Supports alternate log paths for standalone or critical logging scenarios.

**Dependency Management**:
- `LogManager` relies on the `OpsVar` and `OpsInit` modules for global configuration and initialization. These modules must 
  be imported before using `LogManager`. Independent importation of `LogManager` is not supported and may result in 
  uninitialized dependencies or errors.

**Intended Usage**:
- This module is designed for integration within the OpsHostGuard application and assumes the sequential loading of its 
  dependencies (`OpsVar`, `OpsInit`). Standalone usage or testing requires manual initialization of these dependencies.

.FUNCTIONS
- **Initialize-Log**: Prepares the primary log file and processes fallback logs.
- **New-LogIfNeeded**: Rotates log files exceeding the size threshold.
- **Remove-OldLogFiles**: Deletes old compressed log files based on retention settings.
- **Add-LogMessage**: Adds structured log entries with optional console output.
- **Get-LogLevelColor**: Maps log levels to color codes for console display.
- **Test-LogDirectoryExists**: Validates or creates log directories.
- **New-FallbackLogsToMainLog**: Transfers fallback log entries to the primary log.

.NOTES
- `LogManager` should not be imported independently. It must be used in conjunction with the required modules `OpsVar` and 
  `OpsInit` to ensure proper initialization and functionality.
- Any attempt to bypass the module dependency chain may result in unpredictable behavior.
- For standalone use, ensure `$Global:Config` and `$Global:ProjectRoot` are initialized before importing this module.

.ORGANIZATION
Developed by: Faculty of Documentation and Communication Sciences, University of Extremadura.

.AUTHOR
© 2024 Alberto Ledo  
Faculty of Documentation and Communication Sciences, with support from OpenAI.  
IT Department: University of Extremadura - Facilities IT Services.

.VERSION
2.1.0

.HISTORY
- 2.1.1: Reduced console verbosity in Test-LogDirectoryExists by suppressing non-actionable messages.
- 2.1.0: Added audit log level and refined fallback handling.
- 2.0.0: Enhanced fallback log transfer and log rotation logic.
- 1.4.x: Consolidated temporary log functions; added entry-based rotation.
- 1.3.0: Introduced structured logging.
- 1.0.0: Implemented basic logging functionalities and log rotation.

.DATE
November 23, 2024

.DISCLAIMER
This module is provided "as-is" for internal University of Extremadura use. No warranties are provided. Unauthorized 
modifications are not supported.

.LINK
https://github.com/n7rc/OpsHostGuard
#>

<#
#Requires -Module OpsVar
#Requires -Module OpsInit
#Requires -Module OpsBase
#>

<#
if ($Global:ProjectRoot) {
    $Script:ProjectRoot = $Global:ProjectRoot
}
else {
    try {
        if ($null -ne $PSScriptRoot -and $PSScriptRoot -ne "") {
            # $PSScriptRoot is available (executing as a module or script)
            $Script:ProjectRoot = (Resolve-Path -Path (Join-Path -Path $PSScriptRoot -ChildPath ".././../")).Path
        }
        else {
            # $PSScriptRoot is not available (imported from console)
            $scriptDirectory = (Get-Item -Path $MyInvocation.MyCommand.Definition).DirectoryName
            $Script:ProjectRoot = (Resolve-Path -Path (Join-Path -Path $scriptDirectory -ChildPath "../../../")).Path
        }
    }
    catch {
        Write-Host "[Warning] Failed to resolve ProjectRoot dynamically. Error: $_" -ForegroundColor Red
        throw
    }
}
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

if (-not (Get-Module -Name OpsBase)) {
    Add-OpsBaseLogMessage -message "OpsBase module is missing. Please ensure it is loaded." -logLevel "Error"
}

$Global:MainLogPath = Join-Path -Path $Global:Config.Paths.Log.Root -ChildPath "opshostguard.log"
$Global:FallbackLogPath = Join-Path -Path $Global:Config.Paths.Log.Root -ChildPath "fallback-log.log"

function Test-LogDirectoryExists {
    <#
.SYNOPSIS
Ensures the directory for a log file path exists, creating it if necessary.

.DESCRIPTION
Validates whether the directory for a specified log file exists. Creates the directory if it is missing. 
Throws an error if the log path is invalid or empty.

.PARAMETER logPath
The full path to the log file. The directory portion is validated or created as required.

.EXAMPLE
Ensure the directory for a log file exists:
Test-LogDirectoryExists -logPath "C:\Logs\OpsHostGuard\main.log"

.EXAMPLE
Create a missing directory for a specified log file path:
Test-LogDirectoryExists -logPath "D:\Logs\NewDirectory\logfile.log"
#>
    param (
        [string]$logPath
    )

    if (Test-ExecutionContext -ConsoleCheck) {
        #$logPath = $logCorePath
        # *** Quitar esta línea tras el debug.
        $logPath = $Global:MainLogPath
    }
    else {
        $logPath = $Global:MainLogPath
    }

    
    if (-not $logPath -or $logPath -eq "") {
        Write-Host "[Error] Log path is null or empty." -ForegroundColor Red
        throw "Invalid log path: $logPath"
    }

    $logDirectory = Split-Path -Path $logPath -ErrorAction Stop
    if (-not (Test-Path -Path $logDirectory)) {
        try {
            New-Item -Path $logDirectory -ItemType Directory -Force | Out-Null
            Write-Host "[Info] Created log directory: $logDirectory" -ForegroundColor Green
        }
        catch {
            Write-Host "[Error] Failed to create log directory: $($_.Exception.Message)" -ForegroundColor Red
            throw
        }
    }   
}

function Get-LogLevelColor {
    <#
.SYNOPSIS
Maps log levels to console text colors for consistent visual formatting.
.PARAMETER logLevel
The severity level of the log message (e.g., Info, Success, Warning).
.EXAMPLE
Get-LogLevelColor -logLevel "Info"  # Output: "White"
#>
    param (
        [string]$logLevel
    )

    switch ($logLevel) {
        "Info" { "White" }
        "Success" { "Green" }
        "Warning" { "Yellow" }
        "Error" { "Red" }
        "Debug" { "Blue" }
        "Audit" { "LightBlue" }
        default { "White" }
    }

}

function New-FallbackLogsToMainLog {
    <#
.SYNOPSIS
Transfers log entries from the fallback log to the main log file.

.DESCRIPTION
Ensures that critical log entries in the fallback log are appended to the main log file. Deletes the fallback 
log after a successful transfer to avoid duplication.

.PARAMETER fallbackLogPath
Path to the fallback log file. Defaults to the configured fallback log path.

.PARAMETER mainLogPath
Path to the main log file. Defaults to the configured main log path.

.EXAMPLE
Transfer fallback logs to the default main log:
New-FallbackLogsToMainLog

.EXAMPLE
Transfer fallback logs to a custom main log:
New-FallbackLogsToMainLog -mainLogPath "C:\Logs\CustomMainLog.log"
#>
    param (
        [string]$fallbackLogPath = $Global:FallbackLogPath, # Default fallback log path
        [string]$mainLogPath = $Global:MainLogPath          # Main log path
    )

    # Check if the fallback log exists
    if (Test-Path -Path $Global:FallbackLogPath) {
        try {
            # Transfer content from fallback log to main log
            Get-Content -Path $fallbackLogPath | Out-File -FilePath $mainLogPath -Encoding UTF8 -Append
            # Remove the fallback log after successful transfer
            Remove-Item -Path $fallbackLogPath -Force
        }
        catch {
            Write-Host "Failed to transfer fallback logs to main log. Error: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
}

function Initialize-Log {
    <#
.SYNOPSIS
Initializes the main log file for OpsHostGuard.
.DESCRIPTION
Creates the main log file and transfers fallback logs for continuity.
.PARAMETER logPath
(Optional) Path to the main log file. Defaults to the configured log path.
.EXAMPLE
Initialize-Log
#>
    param (
        [string]$logPath = $Global:MainLogPath  # Default log path from configuration
    )

    # Define the fallback log path
    $fallbackLogPath = $Global:FallbackLogPath
    Test-LogDirectoryExists -logPath $logPath

    # Create the main log file if it doesn't exist
    if (-not (Test-Path -Path $logPath)) {
        "OpsHostGuard Execution Log - $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" | Out-File -FilePath $logPath -Encoding UTF8 -Append
        Write-Host "[Info] [Log-Manager] Log file created at $logPath"
    }

    # Transfer fallback log entries to the main log
    New-FallbackLogsToMainLog -mainLogPath $logPath -fallbackLogPath $Global:FallbackLogPath
}

function New-LogIfNeeded {
    <#
.SYNOPSIS
Rotates the log file when its size exceeds a predefined limit.

.DESCRIPTION
Checks the size of the specified log file and rotates it if it exceeds the maximum allowed size 
(default: 10 MB). Older log files are renamed, compressed, and removed as needed to maintain 
storage efficiency. Creates a new log file after rotation.

.PARAMETER logPath
(Optional) Path to the log file to monitor and rotate. Defaults to the main log file.

.EXAMPLE
Rotate the default log file if its size exceeds the limit:
New-LogIfNeeded

.EXAMPLE
Rotate a specific log file:
New-LogIfNeeded -logPath "C:\Logs\OpsHostGuard.log"
#>
    param (
        [string]$logPath = $Global:MainLogPath  # Use the general log if no other is specified
    )

    if ($null -eq $logPath) {
        try {
            throw "Error: LogFilePath is not initialized. Ensure OpsInit.psm1 is imported and Initialize-Variables is called."
        }
        catch {
            $ErrorMessage = "Caught an Error: $_"
            Add-OpsBaseLogMessage -message $ErrorMessage -functionName "New-LogIfNeeded" -logLevel "Error"
            return
        }
    }

    $maxLogSizeMB = 10
    $logFileSizeMB = (Get-Item -Path $logPath).Length / 1MB

    if ($logFileSizeMB -gt $maxLogSizeMB) {
        $oldestLog = "$logPath.3"
        if (Test-Path -Path $oldestLog) {
            Compress-Archive -Path $oldestLog -DestinationPath "$oldestLog.zip" -Update
            Remove-Item -Path $oldestLog -Force
        }

        for ($i = 2; $i -ge 1; $i--) {
            $logToRotate = "$logPath.$i"
            if (Test-Path -Path $logToRotate) {
                Rename-Item -Path $logToRotate -NewName "$logPath.$($i + 1)"
            }
        }

        # Rotate the current log to .1 and create a new log file
        Rename-Item -Path $logPath -NewName "$logPath.1"
        Initialize-Log -logPath $logPath  
    }
}


function Remove-OldLogFiles {
    <#
.SYNOPSIS
Deletes old compressed log files exceeding a specified retention count.

.DESCRIPTION
Manages log file storage by removing older compressed log files (e.g., `.log.*.gz`) 
that exceed a defined retention limit. Retains the most recent files while optimizing 
storage space. Logs the deletion process and handles any errors during file removal.

.PARAMETER logDirectory
(Optional) Directory containing the compressed log files. Defaults to the root log directory.

.PARAMETER retainCount
(Optional) Number of compressed log files to retain. Defaults to `10`.

.EXAMPLE
Remove old log files, keeping the latest 10:
Remove-OldLogFiles

.EXAMPLE
Keep only 5 recent log files in a specific directory:
Remove-OldLogFiles -logDirectory "C:\Logs\MyApp" -retainCount 5
#> 
    param (
        [string]$logDirectory = "$($Global:Config.Paths.Log.Root)",
        [int]$retainCount = 10
    )

    # Get sorted list of compressed log files by creation time
    $logFiles = Get-ChildItem -Path $logDirectory -Filter "*.log.*.gz" | Sort-Object -Property CreationTime

    # Delete old compressed log files beyond the retention count
    if ($logFiles.Count -gt $retainCount) {
        $filesToDelete = $logFiles.Count - $retainCount
        foreach ($file in $logFiles[0..($filesToDelete - 1)]) {
            try {
                Remove-Item -Path $file.FullName -Force
                $InfoMessage = "Deleted old compressed log file: $($file.Name)"
                Add-LogMessage -message $InfoMessage -functionName "Remove-OldLogFiles" -logLevel "Info"
            }
            catch {
                $ErrorMessage = "Error deleting file $($file.Name): $_"
                Add-LogMessage -message $ErrorMessage -functionName "Remove-OldLogFiles" -logLevel "Error"
            }
        }
    }
}




function Add-LogEntry {
    <#
.SYNOPSIS
Adds a structured log entry to a specified log file.

.DESCRIPTION
Writes a log entry with a timestamp, log level, and function context to a designated log file. 
Ensures consistent formatting and appends entries in UTF-8 encoding. Primarily used within 
OpsHostGuard for recording System events, errors, and debug messages.

.PARAMETER message
The content of the log message to write.

.PARAMETER functionName
(Optional) Name of the function generating the log entry. Defaults to the calling script's filename.

.PARAMETER logLevel
(Optional) Severity level of the log entry. Default is "Info".
Supported values:
- Info
- Success
- Warning
- Error
- Debug
- Audit

.PARAMETER logPath
Path to the log file. Must be accessible and writable.

.EXAMPLE
Log an informational message:
Add-LogEntry -message "Initialization complete" -logPath "C:\Logs\SystemLog.txt"

.EXAMPLE
Log a warning with a custom function name:
Add-LogEntry -message "Disk usage high" -functionName "Monitor-Disk" -logLevel "Warning" -logPath "C:\Logs\SystemLog.txt"
#>
    param (
        [string]$message,
        [string]$functionName = $([System.IO.Path]::GetFileNameWithoutExtension($MyInvocation.ScriptName)),
        [string]$logLevel = "Info",
        [string]$logPath
    )

    $timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")

    # Construct the log entry
    $logEntry = "[$timestamp] [$logLevel] [$functionName] $message"

    # Write the message to the log file
    $logEntry | Out-File -FilePath $logPath -Encoding UTF8 -Append
}

# *** -REVISAR- VALORAR LA NECESIDAD DE ESTA VARIABLE. VARIABLE ANTIGUA NO UTILIZADA
# Set a silent mode variable globally to control verbosity
$Script:globalSilentMode = $Global:SilentMode

function Add-LogMessage {
    <#
.SYNOPSIS
Writes a structured log entry to a file and optionally displays it in the console.

.DESCRIPTION
Logs a message with a timestamp, log level, and function context to a specified file. Supports 
various log levels (Info, Success, Warning, Error, Debug) and can handle fallback logging if 
the main log is unavailable. Console output is color-coded unless `-Silent` is specified.

.PARAMETER message
The content of the log message.

.PARAMETER functionName
(Optional) The name of the calling function. Defaults to the current invocation name.

.PARAMETER logLevel
(Optional) Severity level of the log message. Default is "Info". Supported values:
- Info
- Success
- Warning
- Error
- Debug
- Audit

.PARAMETER logCorePath
(Optional) Alternative log file path for critical or standalone logs.

.PARAMETER silent
(Optional) Suppresses console output while still logging to the file.

.EXAMPLE
Log an informational message:
Add-LogMessage -message "Initialization completed" -logLevel "Info"

.EXAMPLE
Log a warning to a critical log file:
Add-LogMessage -message "Disk usage high" -logLevel "Warning" -logCorePath "C:\Logs\Critical.log"

.EXAMPLE
Log an error without console output:
Add-LogMessage -message "Database connection failed" -logLevel "Error" -Silent
#>
    param (
        [string]$message, # The log message content
        [string]$functionName = $MyInvocation.InvocationName, # The name of the calling function
        [string]$logLevel = "Info", # The log level (e.g., Info, Error, Debug, etc.)
        [string]$logCorePath = $null, # Optional path for a critical/standalone log
        [switch]$Silent # Suppress console output if set
    )

    if ($functionName -eq "") {
        $functionName = "Main"
    }

    try {
        # Determine the appropriate log path
        # If a standalone log path is provided and we're running in standalone mode, use it
        # Otherwise, fall back to the main log path
        $logPath = if ($logCorePath -and (Test-ExecutionContext -ConsoleCheck)) {
            $logCorePath
        }
        else {
            $Global:MainLogPath
        }

        # Ensure the log directory exists
        Test-LogDirectoryExists -logPath $logPath

        # Add the log entry to the specified log file
        Add-LogEntry -message $message -functionName $functionName -logLevel $logLevel -logPath $logPath

        # Check if log rotation is necessary and rotate if needed
        New-LogIfNeeded -logPath $logPath

        # Display the log message in the console unless silent mode is enabled
        if (-not $Silent) {
            $timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss") # Get the current timestamp
            $consoleMessage = "[$timestamp] [$logLevel] [$functionName] $message" # Format the console message
            $color = Get-LogLevelColor -logLevel $logLevel # Get the appropriate color for the log level

            # Prevent duplicate console messages by checking the last displayed message
            if ($Global:LastConsoleMessage -ne $consoleMessage) {
                Write-Host $consoleMessage -ForegroundColor $color # Write the message to the console
                $Global:LastConsoleMessage = $consoleMessage # Update the last message variable
            }
        }
    }
    catch {
        # Handle failures to log to the primary log file by falling back to the fallback log

        # Ensure the fallback log path is ready
        New-FallbackLogsToMainLog

        # Construct the fallback message
        $fallbackMessage = "[$(Get-Date)] [Fallback] [$logLevel] [$functionName] $message"

        # Write the fallback message to the fallback log file
        $fallbackMessage | Out-File -FilePath $Global:FallbackLogPath -Encoding UTF8 -Append

        # Display the fallback message in the console unless silent mode is enabled
        if (-not $Silent) {
            Write-Host $fallbackMessage -ForegroundColor Yellow
        }
    }
}

Export-ModuleMember -Function Initialize-Log, New-LogIfNeeded, Remove-OldLogFiles, Add-LogMessage