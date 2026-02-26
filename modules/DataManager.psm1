# DataManager.ps1 [OpsHosGuard]

<#
    .SYNOPSIS
    Generates an HTML report, exports data to CSV, and prepares SQL queries for System load metrics, 
    session Information, update results, logs, and optional hardware inventory  via the parameter `-generateInventory`.

    .DESCRIPTION
    This script collects, organizes, and reports data for System load metrics, session data, update statuses, 
    critical logs, and hardware inventory from multiple classrooms or host groups. It produces:

    - A detailed HTML report with print preview and PDF export options.
    - CSV and log file exports of host metrics, summary data, and hardware inventory.
    - SQL queries to insert host metrics, summary data, and hardware inventory details into a MySQL database.

    The HTML report includes:
    - Summary metrics of total hosts, power-on or shutdown failures, high resource usage, critical Errors, and hardware specifications.
    - Detailed tables of System load metrics (CPU, RAM, Disk), active sessions, failed power-on/shutdown attempts, critical logs, 
      and hardware details (CPU, RAM, Network Adapter, Motherboard, BIOS, OS, and GPU - only if `-generateInventory` is specified).

    Data exported to CSV includes:
    - Host metrics (CPU, RAM, Disk usage, etc.).
    - General summary data (failed hosts, high load percentage, critical Errors, etc.).
    - Hardware inventory (CPU, RAM, Network Adapter, Motherboard, BIOS, OS, and GPU) (only if `-generateInventory` is specified)

    SQL queries are generated to facilitate data insertion into a MySQL database for:
    - Host metrics
    - Summary data
    - Hardware inventory (only if `-generateInventory` is specified)


    .MANDATORY PARAMETERS

    .PARAMETER filePath
    Specifies the path where the generated HTML report will be saved.

    .PARAMETER loadMetrics
    Array of System load metrics (CPU, RAM, Disk usage) for each host.

    .PARAMETER criticalLogs
    Array of critical System event logs from the hosts.

    .PARAMETER applicationErrorLogs
    Array of application Error logs from the hosts.

    .PARAMETER failedHostsLogs
    Array of logs for hosts that failed to power on.

    .PARAMETER activeSessionsLogs
    Array of logs showing active user sessions on the hosts.

    .PARAMETER failedShutdownLogs
    Array of logs for hosts that failed to shut down.

    .PARAMETER updateLogs
    Array of logs detailing the update results installed on the hosts.

    .PARAMETER csvFilePathHosts
    Specifies the path where the host metrics CSV will be saved or updated.

    .PARAMETER csvFilePathSummary
    Specifies the path where the summary CSV will be saved or updated.

    .PARAMETER csvFilePathHardware
    Specifies the path where the hardware inventory CSV will be saved or updated.

    .OPTIONAL PARAMETERS

    .PARAMETER generateInventory
    Boolean parameter that enables additional generation of hardware inventory report and SQL insertion if specified.

    .NOTES
    - The HTML report includes a navigation bar for easy section access.
    - Data can be exported to CSV and log files and a MySQL database.
    - Hardware inventory includes details like CPU, Network Adapter, Motherboard, BIOS, OS, and GPU.
    - Print preview and PDF export functionalities are available for easier sharing and documentation.

    .ORGANIZATION
    Developed for: Faculty of Documentation and Communication Sciences at the University of Extremadura.

    .AUTHOR [© 2024 Alberto Ledo]
    Alberto Ledo [Faculty of Documentation and Communication Sciences] - with assistance from OpenAI
    IT Department: University of Extremadura - IT Services for Facilities
    Contact: albertoledo@unex.es

    .Copyright
    © 2024 Alberto Ledo

    .VERSION
    1.2.2

    .HISTORY
    1.0.0 - Initial version by Alberto Ledo.
    1.0.1 - Bug fix in the declaration of the $totalHosts variable.
    1.1.0 - Added search filter feature.
    1.1.1 - Bug fix in the declaration of various timestamp and NULL variables for SQL.
    1.2.0 - Added parameter -generateInventory.
    1.2.1 - Added RAM capacity to HTML and CSV report and SQL data insertion in hardware inventory.
    1.2.2 - Bug fixing.

    .USAGE
    This script is strictly for internal use within University of Extremadura.
    The script is designed to operate within the IT infrastructure and environment of University of Extremadura
    and may not function as expected in other environments.

    .DATE
    November 4, 2024

    .DISCLAIMER
    This script is provided "as-is" and is intended for internal use at University of Extremadura.
    No warranties, express or implied, are provided. Any modifications or adaptations are not covered
    under this disclaimer.

    .LINK
    https://github.com/n7rc/OpsHostGuard
#>

<#
#Requires -Module OpsInit
#Requires -Module OpsUtils
#Requires -Module CredentialsManager
#>

if ($Global:ProjectRoot) {
    $Script:ProjectRoot = $Global:ProjectRoot
}
else {
    try {
        if ($null -ne $PSScriptRoot -and $PSScriptRoot -ne "") {
            # $PSScriptRoot is available (executing as a module or script)
            $Script:ProjectRoot = (Resolve-Path -Path (Join-Path -Path $PSScriptRoot -ChildPath "../")).Path
        }
        else {
            # $PSScriptRoot is not available (imported from console)
            $scriptDirectory = (Get-Item -Path $MyInvocation.MyCommand.Definition).DirectoryName
            $Script:ProjectRoot = (Resolve-Path -Path (Join-Path -Path $scriptDirectory -ChildPath "../")).Path
        }
    }
    catch {
        Write-Host "[Warning] Failed to resolve ProjectRoot dynamically. Error: $_" -ForegroundColor Red
        throw
    }
}

# Module name setup
$Script:ModuleName = if ($null -ne $MyInvocation.MyCommand.Module) { $MyInvocation.MyCommand.Module.Name } else { "DataManager" }

# Paths for OpsInit module
$opsInitPath = Join-Path -Path $Script:ProjectRoot -ChildPath "modules/core/system/OpsInit.psd1"

if (-not (Get-Module -Name OpsInit)) {
    Import-Module -Name $opsInitPath -Scope Global -Force -ErrorAction Stop
}

if ($Global:ProjectRoot) {
    $Script:ProjectRoot = $Global:ProjectRoot
}

if (Test-ExecutionContext -ConsoleCheck) {
    Add-LogMessage -message "Standalone mode detected. Initializing core dependencies with priority..." -logLevel "Info"

    # Initialize standalone configuration
    Initialize-CoreStandalone

    Clear-OpsBaseLogBuffer -logPath $Global:FallbackLogPath

    # Define CoreDependencies with Priority
    $Script:CoreDependencies = @()

    # Add CredentialsManager
    $Script:CoreDependencies += Add-StandaloneDependency -Name 'CredentialsManager' `
        -Path $Global:Config.InternalConfig.Modules.CredentialsManager.Path `
        -Priority $Global:Config.InternalConfig.Modules.CredentialsManager.Priority

    # Log CoreDependencies for debugging
    Add-LogMessage -message "Core dependencies for standalone mode: $($Script:CoreDependencies | Out-String)" -logLevel "Debug"

    # Ensure CoreDependencies is not empty before calling New-CoreStandalone
    if (-not $Script:CoreDependencies -or $Script:CoreDependencies.Count -eq 0) {
        Add-LogMessage -message "No valid core dependencies to process. Aborting standalone initialization." -logLevel "Error"
        throw "No valid core dependencies to process."
    }

    # Pass CoreDependencies to New-CoreStandalone
    New-CoreStandalone -moduleName $Script:ModuleName -coreDependencies $Script:CoreDependencies
}

# Database credentials retrieval
$dataBaseUser = Get-Credential -credentialFilePath $Global:Config.Security.Files.UserDatabase
$dataBasePasswd = Get-Credential -credentialFilePath $Global:Config.Security.Files.PasswdDatabase

#Pause

# Function to initialize the structure for a host's data object
function Initialize-OpsHostRecord {
    param (
        [string]$HostName, # Host name for which data will be tracked
        [int]$totalHosts   # Total number of hosts in the group
    )
    return @{
        host_name                   = $HostName
        cpu_usage                   = $null
        ram_usage                   = $null
        disk1_usage                 = $null
        disk2_usage                 = $null
        disk3_usage                 = $null
        timestamp                   = $null
        update_names                = $null
        update_status               = $null
        session_active              = $false
        session_name                = 'N/A'
        shutdown_status             = "NULL"
        power_on_failure_time       = $null
        shutdown_failure_time       = $null
        boot_time                   = $null
        total_hosts                 = $totalHosts
        failed_hosts_count          = 0
        failed_percentage           = 0
        total_updates_installed     = 0
        total_critical_logs         = 0
        total_Error_logs            = 0
        total_active_sessions       = 0
        total_hosts_shutdown_failed = 0
        overall_status              = "NULL"
        cpu_model                   = "NULL"
        cpu_cores                   = "NULL"
        network_adapter             = "NULL"
        motherboard                 = "NULL"
        bios_version                = "NULL"
        bios_release_date           = "NULL"
        os_caption                  = "NULL"
        os_build_number             = "NULL"
        gpu_model                   = "NULL"
        gpu_driver_version          = "NULL"
        inventory_datestamp         = $null
    }
}

# Function to create report files
function New-ReportFiles {
    param (
        [string]$GroupName, # Group name passed as parameter, from OpsScan.ps1
        [string]$filePath, # Path where the HTML report will be saved
        [string]$filePathHardwareInventory, # Path where the hardware inventory HTML file will be saved
        [array]$loadMetrics, # Array of load metrics (CPU, RAM, Disk)
        [array]$criticalLogs, # Array of critical logs
        [array]$applicationErrorLogs, # Array of application Error logs
        [array]$failedHostsLogs, # Array of logs for failed power-on attempts
        [array]$activeSessionsLogs, # Array of logs for active user sessions
        [array]$failedShutdownLogs, # Array of logs for failed shutdown attempts
        [array]$updateLogs, # Array of update logs
        [array]$verificationUpdateLogs, # Array of verification logs for updates
        [array]$hardwareInventory, # Hardware inventory data
        [string]$dbHost, # Database host
        [string]$dbName                    # Database name
    )

    # Define the cache's path
    $cacheFrontendPath = Join-Path -Path $Global:Config.Paths.Tmp.Cache -ChildPath "frontend"
    $cacheBackendPath = Join-Path -Path $Global:Config.Paths.Tmp.Cache -ChildPath "backend"

    # Check if the directory exists; if not, create it
    if (!(Test-Path -Path $cacheFrontendPath)) {
        New-Item -ItemType Directory -Path $cacheFrontendPath -Force
        Add-LogMessage -message "Directory created: $cacheFrontendPath" -logLevel "Info"
    }
    else {
        Add-LogMessage -message "Directory already exists: $cacheFrontendPath" -logLevel "Info"
    }

    # Check if the directory exists; if not, create it
    if (!(Test-Path -Path $cacheBackendPath)) {
        New-Item -ItemType Directory -Path $cacheBackendPath -Force
        Add-LogMessage -message "Directory created: $cacheBackendPath" -logLevel "Info"
    }
    else {
        Add-LogMessage -message "Directory already exists: $cacheBackendPath" -logLevel "Info"
    }

    # Safely read the JSON file and convert it into a PowerShell object
    $configPath = Join-Path -Path $Global:Config.Paths.Config -ChildPath "host_groups.json"
    try {
        if (!(Test-Path -Path $configPath)) {
            throw "JSON configuration file not found: $configPath"
        }
        $hostGroups = Get-Content -Path $configPath | ConvertFrom-Json
        if (-not $hostGroups) {
            throw "The JSON configuration file is empty or malformed: $configPath"
        }
    }
    catch {
        Add-LogMessage -message "Error processing JSON configuration: $_" -logLevel "Error"
        exit
    }

    # Check if the specified group exists in the JSON structure
    if ($hostGroups.PSObject.Properties.Name -contains $GroupName) {
        $hosts = $hostGroups.$GroupName   # Get the hosts for the specified group
    }
    else {
        Add-LogMessage -message "Group not found: $GroupName in JSON configuration." -logLevel "Warning"
        exit
    }

    # Dynamically generate <option> elements for the <select> dropdown in the HTML report
    $htmlOptionsAllHosts = ""
    foreach ($currentHost in $hosts) {
        $htmlOptionsAllHosts += "<option value='$currentHost'>$currentHost</option>`n"   # Append each host as an option
    }

    # Save the variable $htmlOptionsAllHosts in a temporary file so PHP can retrieve it
    $htmlOptionsAllHosts | Out-File -FilePath (Join-Path -Path $cacheFrontendPath -ChildPath "html_options_all_hosts.cache") -Encoding UTF8

    # List of hosts that failed to power on
    $failedPowerOnHosts = $failedHostsLogs | Select-Object -ExpandProperty HostName

    # Filter only the hosts that did NOT fail (the ones that are powered on)
    $poweredOnHosts = $hosts | Where-Object { $failedPowerOnHosts -notcontains $_ }

    # Generate HTML dropdown with only reachable hosts
    $htmlOptionsPowerOnHosts = ""
    foreach ($currentHost in $poweredOnHosts) {
        $htmlOptionsPowerOnHosts += "<option value='$currentHost'>$currentHost</option>`n"
    }

    # Save the reachable hosts options in a cache file
    $htmlOptionsPowerOnHosts | Out-File -FilePath (Join-Path -Path $cacheFrontendPath -ChildPath "html_options_alive_hosts.cache") -Encoding UTF8

    # Safely calculate the summary statistics
    try {
        $totalHosts = ($hosts | Measure-Object).Count  # Total hosts in the group
        $failedHostsCount = $failedHostsLogs.Count + $failedShutdownLogs.Count  # Total failed hosts (power-on + shutdown)
        $failedPercentage = if ($totalHosts -gt 0) {
            [math]::Round(($failedHostsCount / $totalHosts) * 100, 2)
        }
        else {
            0
        }

        # Calculate the percentage of hosts with high resource usage (CPU, RAM, or Disk > 80%)
        $highLoadCount = 0
        foreach ($metric in $loadMetrics) {
            if ($metric.CPU -gt 80 -or $metric.RAM -gt 80 -or $metric.Disk1 -gt 80 -or $metric.Disk2 -gt 80 -or $metric.Disk3 -gt 80) {
                $highLoadCount++
            }
        }
        $highLoadPercentage = if ($totalHosts -gt 0) {
            [math]::Round(($highLoadCount / $totalHosts) * 100, 2)
        }
        else {
            0
        }

        # Calculate the percentage of hosts with critical Errors in their logs
        $hostsWithCriticalErrors = $criticalLogs | Select-Object -ExpandProperty HostName | Sort-Object -Unique
        $criticalErrorCount = $hostsWithCriticalErrors.Count
        $criticalErrorPercentage = if ($totalHosts -gt 0) {
            [math]::Round(($criticalErrorCount / $totalHosts) * 100, 2)
        }
        else {
            0
        }
    }
    catch {
        Add-LogMessage -message "Error calculating statistics: $_" -logLevel "Error"
    }

    $htmlContent = @'

<?php

// standar_report.php [OpsHostGuard - Generated by OpsHostGuard]

/**
 * @SYNOPSIS
 * Dynamically generated standard report page for the OpsHostGuard project.
 * This script loads configurations, verifies user authentication, and displays report data
 * with options for filtering by host and event type, as well as exporting data to PDF.
 * 
 * @DESCRIPTION
 * - Loads configuration settings from external files for report customization.
 * - Verifies user authentication to ensure only authorized users can access the report.
 * - Provides filtering options by host and event type, with export options for PDF generation.
 * - This file is generated automatically by the `DataManager.ps1` PowerShell script 
 *   and should not be modified manually.
 * 
 * @NOTES
 * - Ensure `config.php` and `session_manager.php` are accessible as they provide critical 
 *   settings and session control.
 * - This script is re-generated as needed by the backend and may be overwritten.
 * - Filtering and export options require JavaScript libraries (e.g., `html2pdf.js`, `jsPDF`) 
 *   for client-side functionality.
 * 
 * @ORGANIZATION
 * Developed for: Faculty of Documentation and Communication Sciences at the University of Extremadura.
 * 
 * @DEPENDENCIES
 * - `config.php`: Loads essential configuration settings, including `BASE_URL`.
 * - `session_manager.php`: Manages user authentication and session timeout policies.
 * 
 * @AUTHOR
 * Alberto Ledo [Faculty of Documentation and Communication Sciences] - with assistance from OpenAI
 * IT Department: University of Extremadura - IT Services for Facilities
 * Contact: albertoledo@unex.es
 * 
 * @VERSION
 * 2.0 - Dynamically generated by OpsHostGuard
 * 
 * @LICENSE
 * This script is strictly for internal use within the University of Extremadura.
 * It is designed for the IT infrastructure of the University of Extremadura and may not function 
 * as expected in other environments.
 * 
 * @LINK
 * https://github.com/n7rc/OpsHostGuard
 */

// Load configuration and session management modules
@require_once __DIR__ . '/../../config/config.php';
@require_once __DIR__ . '/../../auth/session_manager.php';

$version = getVersion();
$userData = getUserData();

// Ensure the user is logged in and check for session expiration
checkLogin();
checkSessionTimeout();

?>

<!DOCTYPE html>
<html lang='es'>
<head>
    <meta charset='UTF-8'>
    <meta name='viewport' content='width=device-width, initial-scale=1.0'>
    <link rel="icon" href="<?php echo BASE_URL; ?>/public/assets/images/favicon.png" type="image/png">
    <title><?php echo $userData['HTMLReport']['stdReportTitle']; ?></title>

    <!-- External resources for styling and icons -->
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.0.0-beta3/css/all.min.css">
    <link rel="stylesheet" type="text/css" href="<?php echo BASE_URL; ?>/public/assets/css/main-styles.css">

    <!-- JS Libraries for PDF export functionality -->
    <script src="https://cdnjs.cloudflare.com/ajax/libs/jspdf/2.5.1/jspdf.umd.min.js"></script>
    <script src="https://cdnjs.cloudflare.com/ajax/libs/html2canvas/0.4.1/html2canvas.min.js"></script>
    <script src="https://cdnjs.cloudflare.com/ajax/libs/html2pdf.js/0.9.3/html2pdf.bundle.min.js"></script>
    <script src="<?php echo BASE_URL; ?>/public/assets/js/main.js"></script>
</head>
<body id="top">

<!-- Navigation Bar with links to sections within the report -->
<div class="navbar">
    <div class="containernav">
        <a href="<?php echo BASE_URL; ?>/views/dashboard/dashboard.php" class="first-link"><i class="fa-solid fa-house"></i></a>
        <div class="center-links">
            <!-- Links for quick navigation to different report sections -->
            <a href="#summary">Summary</a>
            <a href="#failed-power-on">Failed Power On</a>
            <a href="#failed-shutdown">Failed Shutdown</a>
            <a href="#active-sessions">Active Sessions</a>
            <a href="#load-metrics">Load Metrics</a>
            <a href="#updates">Updates</a>
            <a href="#logs">Critical Logs</a>
            <a href="#Error-logs">Application Logs</a>
            <a href="<?php echo BASE_URL; ?>/views/reports/hardware_inventory_report.php">Hardware Inventory</a>
        </div>
        <a href="<?php echo BASE_URL; ?>/public/index.php" class="last-link"><i class="fa fa-sign-out"></i></a>
    </div>
</div>

<div class="container no-export">
    <!-- Filter Section for Host and Event Type -->
    <div class="filter-container">
        <form id="filterForm">
            <!-- Dropdown to filter the report by host -->
            <label for="hostFilter">Filter by Host:</label>
            <select id="hostFilter" name="host">
                <option value='all'>All Hosts</option>
                <?php include('../../../tmp/cache/frontend/html_options_all_hosts.cache'); ?>
            </select>
        </form>

        <!-- Dropdown to filter the report by event type -->
        <label for="eventType">Event Type:</label>
        <select id="eventType" name="eventType">
            <option value="all">All Events</option>
            <option value="highLoad">High Load</option>
            <option value="powerFailure">Power-on Failed</option>
            <option value="shutdownFailure">Shutdown Failures</option>
        </select>
        
        <!-- Buttons to apply and reset filters -->
        <button type="button" id="applyFiltersButton" onclick="applyFiltersDashboard()">Apply Filters</button>
        <button type="button" id="resetFiltersButton" onclick="resetFilters()">Reset Filters</button>
    </div>
</div>

<div class="container exportable-content">
    <!-- Header section with title and export options -->
    <div class="header">
        <h1><?php echo $userData['HTMLReport']['stdReportTitle']; ?></h1>
        <div class="filter-container button-group no-export">
            <button class="print-button" onclick="openPrintPreview()">Preview and Print Report</button>
            <button class="export-button" onclick="generatePDF()">Export to PDF</button>
        </div>
    </div>

    <!-- Content section for the standard report data (dynamically generated) -->
    <div class="exportable-content">
    <!-- Content for each report section would be dynamically inserted here -->
'@

    # Data adaptation to the host_summary table


    # Adding the summary section of the report
    $htmlContent += "<h2 id='summary'>General Summary</h2>"
    $htmlContent += "<table><tr><th>Metric</th><th>Value</th></tr>"
    $htmlContent += "<tr><td>Total Hosts</td><td>$totalHosts</td></tr>"
    $htmlContent += "<tr><td>Percentage of Failed Hosts (Power On or Shutdown)</td><td>$failedPercentage%</td></tr>"
    $htmlContent += "<tr><td>Percentage of Hosts with High Load (>80%)</td><td>$highLoadPercentage%</td></tr>"
    $htmlContent += "<tr><td>Percentage of Hosts with Critical Errors</td><td>$criticalErrorPercentage%</td></tr>"
    $htmlContent += "<tr><td>Report Execution Time</td><td>$global:formattedTimeCheck</td></tr>"
    $htmlContent += "</table>"

    # Section for hosts that failed to power on
    $htmlContent += "<h2 id='failed-power-on'>Hosts Failed to Power On</h2>"
    $htmlContent += "<table><tr><th>Host</th><th>Timestamp</th><th>Status</th></tr>"
    foreach ($log in $failedHostsLogs) {
        $statusClass = if ($log.Status -eq 'Power-on Failed') { 'Error' } elseif ($log.Status -eq 'Succeeded') { 'ok' }
        $htmlContent += "<tr><td>$($log.HostName)</td><td>$($log.Timestamp)</td><td class='$statusClass'>$($log.Status)</td></tr>"
    }
    $htmlContent += "</table>"

    # Section for hosts that failed to shut down
    $htmlContent += "<h2 id='failed-shutdown'>Hosts Failed to Shutdown</h2>"
    $htmlContent += "<table><tr><th>Host</th><th>Timestamp</th><th>Status</th></tr>"
    foreach ($log in $failedShutdownLogs) {
        $statusClass = if ($log.Status -eq 'Shutdown Failed') { 'Error' } elseif ($log.Status -eq 'Succeeded') { 'ok' }
        $htmlContent += "<tr><td>$($log.HostName)</td><td>$($log.Timestamp)</td><td class='$statusClass'>$($log.Status)</td></tr>"
    }
    $htmlContent += "</table>"

    # Section for active sessions on hosts
    $htmlContent += "<h2 id='active-sessions'>Active Sessions on Hosts</h2>"
    $htmlContent += "<table><tr><th>Host</th><th>Session Name</th><th>Timestamp</th></tr>"
    foreach ($log in $activeSessionsLogs) {
        $sessionName = ($log.Status -replace 'Host in Session \[ ', 'username: ') -replace ']', ''
        $htmlContent += "<tr><td>$($log.HostName)</td><td>$sessionName</td><td>$($log.Timestamp)</td></tr>"
    }
    $htmlContent += "</table>"

    # Section for load metrics (CPU, RAM, Disk usage)
    $htmlContent += "<h2 id='load-metrics'>Host Load Metrics</h2>"
    $htmlContent += "<table><tr><th>Host</th><th>CPU (%)</th><th>RAM (%)</th><th>Disk1 (%)</th><th>Disk2 (%)</th><th>Disk3 (%)</th></tr>"
    foreach ($metric in $loadMetrics) {
        # Determine if the load is critical (above 80%) and assign appropriate CSS class
        $cpuClass = if ($metric.CPU -gt 80) { 'Error' } else { 'ok' }
        $ramClass = if ($metric.RAM -gt 80) { 'Error' } else { 'ok' }
        $disk1Class = if ($metric.Disk1 -gt 80) { 'Error' } else { 'ok' }
        $disk2Class = if ($metric.Disk2 -gt 80) { 'Error' } else { 'ok' }
        $disk3Class = if ($metric.Disk3 -gt 80) { 'Error' } else { 'ok' }

        # Create table rows for each metric and apply the CSS class based on load percentage
        $htmlContent += "<tr><td>$($metric.HostName)</td>"
        $htmlContent += "<td>$($metric.CPU)% <div class='progress-bar'><div class='progress-bar-fill $cpuClass' style='width:$($metric.CPU)%'></div></div></td>"
        $htmlContent += "<td>$($metric.RAM)% <div class='progress-bar'><div class='progress-bar-fill $ramClass' style='width:$($metric.RAM)%'></div></div></td>"
        $htmlContent += "<td>$($metric.Disk1)% <div class='progress-bar'><div class='progress-bar-fill $disk1Class' style='width:$($metric.Disk1)%'></div></div></td>"
        $htmlContent += "<td>$($metric.Disk2)% <div class='progress-bar'><div class='progress-bar-fill $disk2Class' style='width:$($metric.Disk2)%'></div></div></td>"
        $htmlContent += "<td>$($metric.Disk3)% <div class='progress-bar'><div class='progress-bar-fill $disk3Class' style='width:$($metric.Disk3)%'></div></div></td>"
        $htmlContent += "</tr>"
    }
    $htmlContent += "</table>"

    # Section for installed updates
    $htmlContent += "<h2 id='updates'>Updates Installed</h2>"
    $htmlContent += "<table><tr><th>Host</th><th>Timestamp</th><th>Update</th><th>Result</th></tr>"
    foreach ($log in $updateLogs) {
        $resultClass = if ($log.Result -eq 'Failed') { 'Error' } elseif ($log.Result -eq 'Success') { 'ok' }
        $htmlContent += "<tr><td>$($log.HostName)</td><td>$($log.Timestamp)</td><td>$($log.Status)</td><td class='$resultClass'>$($log.Result)</td></tr>"
    }
    $htmlContent += "</table>"

    # Section for verification installed updates
    $htmlContent += "<h2 id='updates'>Verification of the latest updates installation</h2>"
    $htmlContent += "<table><tr><th>Host</th><th>Date</th><th>Update</th><th>Result</th></tr>"
    foreach ($log in $verificationUpdateLogs) {
        $resultClass = if ($log.Result -eq 'Failed') { 'Error' } elseif ($log.Result -eq 'Success') { 'ok' } else { 'pending' }
        $htmlContent += "<tr><td>$($log.HostName)</td><td>$($log.Timestamp)</td><td>$($log.Status)</td><td class='$resultClass'>$($log.Result)</td></tr>"
    }
    $htmlContent += "</table>"

    # Section for critical System logs (last 7 days)
    $htmlContent += "<h2 id='logs'>Critical Logs (Last 7 Days)</h2>"
    $htmlContent += "<table><tr><th>Time Created</th><th>Event ID</th><th>Log Type</th><th>Message</th></tr>"
    foreach ($log in $criticalLogs) {
        $htmlContent += "<tr><td>$($log.TimeCreated.ToString('yyyy-MM-dd HH:mm:ss'))</td><td>$($log.Id)</td><td>$($log.LogType)</td><td>$($log.Message.Substring(0, [Math]::Min(50, $log.Message.Length)))</td></tr>"
    }
    $htmlContent += "</table>"

    # Section for application Error logs (last 7 days)
    $htmlContent += "<h2 id='Error-logs'>Application Error Logs (Last 7 Days)</h2>"
    $htmlContent += "<table><tr><th>Time Created</th><th>Event ID</th><th>Level</th><th>Message</th></tr>"
    foreach ($log in $applicationErrorLogs) {
        $htmlContent += "<tr><td>$($log.TimeCreated.ToString('yyyy-MM-dd HH:mm'))</td><td>$($log.Id)</td><td>$($log.Level)</td><td>$($log.Message)</td></tr>"
    }
    $htmlContent += "</table>"

    # Add version Information
    $htmlContent += @'
        
    <p class="version-Info"><?php echo "Version: " . $version; ?> - 
'@
    # Add report date Information
    $htmlContent += "Date: $reportDate</p></div></body></html>"

    # Write the HTML content to a file
    Add-LogMessage "Writing report to: $filePath"
    $htmlContent | Out-File -FilePath $filePath -Force -Encoding UTF8
    if ($GroupNameenerateInventory) {
        $htmlContent = @'
<?php

// hardware_inventory_report.php [OpsHostGuard - Generated by DataManager.ps1]

/**
 * @SYNOPSIS
 * Dynamically generated hardware inventory report page for the OpsHostGuard project.
 * This script loads configurations, checks user login, and displays detailed hardware inventory data
 * with filtering and export options.
 * 
 * @DESCRIPTION
 * - Loads configuration settings from external files to customize page properties, such as the title.
 * - Ensures the user is authenticated; if not, redirects them to the login page.
 * - Provides filtering options to view specific hosts, with export options to generate a PDF report.
 * - This file is generated automatically by the `DataManager.ps1` PowerShell script 
 *   and should not be modified manually.
 * 
 * @NOTES
 * - Requires `config.php` for essential configuration settings, including `BASE_URL`.
 * - Depends on `session_manager.php` for user authentication and session management.
 * - Uses JavaScript libraries (e.g., `html2pdf.js`, `jsPDF`) for client-side PDF export functionality.
 * - Automatically regenerated by the backend as needed; any manual modifications will be overwritten.
 * 
 * @ORGANIZATION
 * Developed for: Faculty of Documentation and Communication Sciences at the University of Extremadura.
 * 
 * @DEPENDENCIES
 * - `config.php`: Loads BASE_URL and other configuration settings.
 * - `session_manager.php`: Manages user authentication and session timeout policies.
 * 
 * @AUTHOR
 * Alberto Ledo [Faculty of Documentation and Communication Sciences] - with assistance from OpenAI
 * IT Department: University of Extremadura - IT Services for Facilities
 * Contact: albertoledo@unex.es
 * 
 * @VERSION
 * 2.0 - Dynamically generated by OpsHostGuard
 * 
 * @LICENSE
 * This script is strictly for internal use within the University of Extremadura.
 * It is designed for the IT infrastructure of the University of Extremadura and may not function 
 * as expected in other environments.
 * 
 * @LINK
 * https://github.com/n7rc/OpsHostGuard
 */

// Load configuration and session management modules
@require_once __DIR__ . '/../../config/config.php';
@require_once __DIR__ . '/../../auth/session_manager.php';

$version = getVersion();
$userData = getUserData();

// Ensure the user is logged in and verify session activity
checkLogin();
checkSessionTimeout();

?>

<!DOCTYPE html>
<html lang='es'>
<head>
    <meta charset='UTF-8'>
    <meta name='viewport' content='width=device-width, initial-scale=1.0'>
    <link rel="icon" href="<?php echo BASE_URL; ?>/public/assets/images/favicon.png" type="image/png">
    <title><?php echo $userData['HTMLReport']['hardInventoryReportTitle']; ?></title>

    <!-- External resources for styling and icons -->
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.0.0-beta3/css/all.min.css">
    <link rel="stylesheet" type="text/css" href="<?php echo BASE_URL; ?>/public/assets/css/main-styles.css">

    <!-- JS Libraries for PDF export functionality -->
    <script src="https://cdnjs.cloudflare.com/ajax/libs/jspdf/2.5.1/jspdf.umd.min.js"></script>
    <script src="https://cdnjs.cloudflare.com/ajax/libs/html2canvas/0.4.1/html2canvas.min.js"></script>
    <script src="https://cdnjs.cloudflare.com/ajax/libs/html2pdf.js/0.9.3/html2pdf.bundle.min.js"></script>
    <script src="<?php echo BASE_URL; ?>/public/assets/js/main.js"></script>
</head>
<body>

<!-- Navigation Bar with links to Dashboard and Logout -->
<div class="navbar">
    <div class="containernav">
        <a href="<?php echo BASE_URL; ?>/views/dashboard/dashboard.php" class="first-link"><i class="fa-solid fa-house"></i></a>
        <a href="<?php echo BASE_URL; ?>/public/index.php" class="last-link"><i class="fa fa-sign-out"></i></a>
    </div>
</div>

<div class="container no-export">
    <!-- Filter Section for Host Selection -->
    <div class="filter-container">
        <form id="filterForm">
            <!-- Dropdown to filter hardware inventory by host -->
            <label for="hostFilter">Filter by Host:</label>
            <select id="hostFilter" name="host">
                <option value='all'>All Hosts</option>
                <?php include('../../../tmp/cache/frontend/html_options_alive_hosts.cache'); ?>
            </select>
        </form>

        <!-- Buttons to apply and reset filters -->
        <button type="button" id="applyFiltersButton" onclick="applyFiltersHardwareInventory()">Apply Filters</button>
        <button type="button" id="resetFiltersButton" onclick="resetFilters()">Reset Filters</button>
    </div>
</div>

<div class="container exportable-content">
    <!-- Header section with title and export button -->
    <div class="header">
        <h1><?php echo $userData['HTMLReport']['hardInventoryReportTitle']; ?></h1>
        <div class="button-group no-export">
            <!--<button class="print-button" onclick="openPrintPreview()">Preview and Print Report</button>-->
            <button class="export-button" onclick="generateInventoryPDF()">Export to PDF (A3)</button>
        </div>
    </div>
'@
        # Section for hardware inventory
        $htmlContent += "<h2 id='hardware-Inventory'>Hardware Inventory</h2>"
        $htmlContent += "<table id='hardwareInventoryTable'><tr><th>Host</th><th>CPU</th><th>Cores</th><th>RAM (GB)</th>
                         <th>OS Disk (GB)</th><th>Network Adapter</th><th>MAC</th><th>Motherboard</th><th>BIOS Version</th><th>BIOS Release Date</th>
                         <!--<th>OS</th>--><th>OS Build Number</th><th>GPU</th><th>GPU Driver Version</th></tr>"
        foreach ($currenthost in $successfulHosts) {
            
            # Add the total RAM capacity converted to GB in each row of the table
            $hardwareInventory = Get-HardwareInventory -HostName $currenthost -credential $PsRemotingCredential
            $ramCapacity = $hardwareInventory.RAMInfo.Capacity
            # When there is more than one memory module, it is an array of objects (multiple modules) that need to be summed.
            $ramCapacityGB = ($ramCapacity | Measure-Object -Sum).Sum / 1GB
            $ramCapacityGB = [math]::Round($ramCapacityGB, 2)
            
            $hardwareInventory = Get-HardwareInventory -HostName $currenthost -credential $PsRemotingCredential
            $htmlContent += "<tr><td>$currenthost</td>"
            $htmlContent += "<td>$($hardwareInventory.CPUInfo.Name)</td>"
            $htmlContent += "<td>$($hardwareInventory.CPUInfo.NumberOfCores)</td>"
            $htmlContent += "<td>$ramCapacityGB</td>"
            $htmlContent += "<td>$([math]::Round(($hardwareInventory.DiskInfo[0].Size / 1GB), 0))</td>"
            #$htmlContent += "<td>$([math]::Round(($hardwareInventory.DiskInfo.FreeSpace / 1GB), 2))</td>"
            $htmlContent += "<td>$($hardwareInventory.NetworkInfo.Name)</td>"
            $htmlContent += "<td>$($hardwareInventory.NetworkInfo.MACAddress)</td>"
            $htmlContent += "<td>$($hardwareInventory.MotherboardInfo.Manufacturer) - $($hardwareInventory.MotherboardInfo.Product)</td>"
            $htmlContent += "<td>$($hardwareInventory.BIOSInfo.SMBIOSBIOSVersion)</td>"
            $htmlContent += "<td>$($hardwareInventory.BIOSInfo.ReleaseDate)</td>"
            #$htmlContent += "<td>$($hardwareInventory.OSInfo.Caption)</td>"
            $htmlContent += "<td>$($hardwareInventory.OSInfo.BuildNumber)</td>"
            $htmlContent += "<td>$($hardwareInventory.GPUInfo.Name)</td>"
            $htmlContent += "<td>$($hardwareInventory.GPUInfo.DriverVersion)</td>"
            $htmlContent += "</tr>"
        }
        $htmlContent += "</table>"

        # Add version Information
        $htmlContent += @'

    <p class="version-Info"><?php echo "Version: " . $version; ?> - 
'@
        # Add report date Information
        $htmlContent += "Date: $reportDate</p></div></body></html>"

        # Write the HTML content to a file
        Add-LogMessage "Writing report to: $filePathHardwareInventory"
        $htmlContent | Out-File -FilePath $filePathHardwareInventory -Force -Encoding UTF8
    }
    # Initialize the collection of hosts data
    foreach ($metric in $loadMetrics) {
        $HostName = $metric.HostName
        # Initialize host data only if it's not already initialized in the $hostsData dictionary
        if (-not $hostsData.ContainsKey($HostName)) {
            if (-not $Silent) {
                Add-LogMessage "Initializing host: $HostName"
            }
            $hostsData[$HostName] = Initialize-OpsHostRecord -HostName $HostName -totalHosts $totalHosts
        }
    }

    if (-not $Silent) {
        Add-LogMessage "Initialized hosts: $($hostsData.Keys)"
    }

    # Process power-on failure logs and store relevant data
    foreach ($log in $failedHostsLogs) {
        $HostName = $log.HostName
        if (-not $hostsData.ContainsKey($HostName)) {
            $hostsData[$HostName] = Initialize-OpsHostRecord -HostName $HostName -totalHosts $totalHosts
        }
        $hostsData[$HostName].power_on_failure_time = $log.Timestamp
        $hostsData[$HostName].overall_status = "Power-on Failed"
    }

    # Process shutdown failure logs and store relevant data
    foreach ($log in $failedShutdownLogs) {
        $HostName = $log.HostName
        if (-not $hostsData.ContainsKey($HostName)) {
            $hostsData[$HostName] = Initialize-OpsHostRecord -HostName $HostName -totalHosts $totalHosts
        }
        $hostsData[$HostName].shutdown_failure_time = $log.Timestamp
        $hostsData[$HostName].shutdown_status = "Shutdown Failed"
        $hostsData[$HostName].total_hosts_shutdown_failed += 1
        $hostsData[$HostName].overall_status = "Shutdown Failed"
    }

    # Process active session logs and update session-related data for each host
    foreach ($log in $activeSessionsLogs) {
        $HostName = $log.HostName
        if (-not $hostsData.ContainsKey($HostName)) {
            $hostsData[$HostName] = Initialize-OpsHostRecord -HostName $HostName -totalHosts $totalHosts
        }
        $hostsData[$HostName].session_active = $true
        $hostsData[$HostName].total_active_sessions += 1
        $hostsData[$HostName].overall_status = "Session Active"
    }

    # Process load metrics for CPU, RAM, and disk usage, storing relevant data
    foreach ($metric in $loadMetrics) {
        $HostName = $metric.HostName
        $hostsData[$HostName].cpu_usage = $metric.CPU
        $hostsData[$HostName].ram_usage = $metric.RAM
        $hostsData[$HostName].disk1_usage = $metric.Disk1
        $hostsData[$HostName].disk2_usage = $metric.Disk2
        $hostsData[$HostName].disk3_usage = $metric.Disk3
    }

    # Process update logs and store update-related data
    foreach ($log in $updateLogs) {
        $HostName = $log.HostName
        if (-not $hostsData.ContainsKey($HostName)) {
            $hostsData[$HostName] = Initialize-OpsHostRecord -HostName $HostName -totalHosts $totalHosts
        }
        $hostsData[$HostName].update_status = $log.Result
        $hostsData[$HostName].total_updates_installed += 1
    }

    # Process critical logs and update host's critical log count and status
    foreach ($log in $criticalLogs) {
        $HostName = $log.HostName
        if (-not $hostsData.ContainsKey($HostName)) {
            $hostsData[$HostName] = Initialize-OpsHostRecord -HostName $HostName -totalHosts $totalHosts
        }
        $hostsData[$HostName].total_critical_logs += 1
        $hostsData[$HostName].overall_status = "Critical Logs Detected"
    }

    # Process application Error logs and update host's Error log count and status
    foreach ($log in $applicationErrorLogs) {
        $HostName = $log.HostName
        if (-not $hostsData.ContainsKey($HostName)) {
            $hostsData[$HostName] = Initialize-OpsHostRecord -HostName $HostName -totalHosts $totalHosts
        }
        $hostsData[$HostName].total_Error_logs += 1
        $hostsData[$HostName].overall_status = "Application Errors Detected"
    }

    # General summary calculation for hosts
    $failedHostsCount = $failedHostsLogs.Count + $failedShutdownLogs.Count
    # Calculate the percentage of failed hosts (hosts that failed to power on or shut down)
    $failedPercentage = if ($totalHosts -ne 0) { [math]::Round(($failedHostsCount / $totalHosts) * 100, 2) } else { 0 }

    # Calculation of percentage of hosts with high resource usage (over 80% in CPU, RAM, or disks)
    $highLoadCount = 0
    foreach ($metric in $loadMetrics) {
        if ($metric.CPU -gt 80 -or $metric.RAM -gt 80 -or $metric.Disk1 -gt 80 -or $metric.Disk2 -gt 80 -or $metric.Disk3 -gt 80) {
            $highLoadCount++
        }
    }
    $highLoadPercentage = if ($totalHosts -ne 0) { [math]::Round(($highLoadCount / $totalHosts) * 100, 2) } else { 0 }

    # Calculate percentage of hosts with critical Errors in the logs
    $criticalErrorCount = $criticalLogs | Select-Object -ExpandProperty HostName | Sort-Object -Unique | Measure-Object | Select-Object -ExpandProperty Count
    $criticalErrorPercentage = if ($totalHosts -ne 0) { [math]::Round(($criticalErrorCount / $totalHosts) * 100, 2) } else { 0 }

    # Calculate percentage of hosts with active sessions
    $activeSessionCount = $activeSessionsLogs.Count
    $activeSessionPercentage = if ($totalHosts -ne 0) { [math]::Round(($activeSessionCount / $totalHosts) * 100, 2) } else { 0 }

    # Update the general summary data collection for all hosts
    $summaryData = @{
        total_hosts                 = $totalHosts
        failed_hosts_count          = $failedHostsCount
        failed_percentage           = $failedPercentage
        high_load_percentage        = $highLoadPercentage
        critical_Error_percentage   = $criticalErrorPercentage
        active_session_percentage   = $activeSessionPercentage
        total_updates_installed     = $($updateLogs.Count)
        total_critical_logs         = $criticalErrorCount
        total_Error_logs            = $applicationErrorLogs.Count
        total_active_sessions       = $activeSessionCount
        total_hosts_shutdown_failed = $failedShutdownLogs.Count
        overall_status              = if ($failedHostsCount -eq 0 -and $criticalErrorCount -eq 0) { "Success" } else { "Partial Failures" }
    }

    # Assign the summary data to each host in the $hostsData dictionary
    foreach ($HostName in $hostsData.Keys) {
        $hostsData[$HostName].total_hosts = $summaryData.total_hosts
        $hostsData[$HostName].failed_hosts_count = $summaryData.failed_hosts_count
        $hostsData[$HostName].failed_percentage = $summaryData.failed_percentage
        $hostsData[$HostName].high_load_percentage = $summaryData.high_load_percentage
        $hostsData[$HostName].critical_Error_percentage = $summaryData.critical_Error_percentage
        $hostsData[$HostName].active_session_percentage = $summaryData.active_session_percentage
        $hostsData[$HostName].total_updates_installed = $summaryData.total_updates_installed
        $hostsData[$HostName].total_critical_logs = $summaryData.total_critical_logs
        $hostsData[$HostName].total_Error_logs = $summaryData.total_Error_logs
        $hostsData[$HostName].total_active_sessions = $summaryData.total_active_sessions
        $hostsData[$HostName].total_hosts_shutdown_failed = $summaryData.total_hosts_shutdown_failed
        $hostsData[$HostName].overall_status = $summaryData.overall_status
    }

    # Update the hardware inventory data collection for all hosts

    # Hardware data update for each host in hostsData
    foreach ($currenthost in $successfulHosts) {
        $hardwareInventory = Get-HardwareInventory -HostName $currenthost -credential $PsRemotingCredential
    
        # Check if the host is in the dictionary and assign specific hardware data to each host
        if ($hostsData.ContainsKey($currenthost)) {
            $hostsData[$currenthost].cpu_model = $hardwareInventory.CPUInfo.Name
            $hostsData[$currenthost].cpu_cores = $hardwareInventory.CPUInfo.NumberOfCores
            $hostsData[$currenthost].ram_capacity = $hardwareInventory.RAMInfo.Capacity
            $hostsData[$currenthost].network_adapter = $hardwareInventory.NetworkInfo.Name
            $hostsData[$currenthost].mac = $hardwareInventory.NetworkInfo.MACAddress
            $hostsData[$currenthost].motherboard = "$($hardwareInventory.MotherboardInfo.Manufacturer) - $($hardwareInventory.MotherboardInfo.Product)"
            $hostsData[$currenthost].bios_version = $hardwareInventory.BIOSInfo.SMBIOSBIOSVersion
            $hostsData[$currenthost].bios_release_date = $hardwareInventory.BIOSInfo.ReleaseDate
            $hostsData[$currenthost].os_caption = $hardwareInventory.OSInfo.Caption
            $hostsData[$currenthost].os_build_number = $hardwareInventory.OSInfo.BuildNumber
            $hostsData[$currenthost].gpu_model = $hardwareInventory.GPUInfo.Name
            $hostsData[$currenthost].gpu_driver_version = $hardwareInventory.GPUInfo.DriverVersion
            $hostsData[$currenthost].Inventory_datestamp = $hardwareInventory.Inventory.Datestamp
        }
        else {
            if (-not $Silent) {
                Add-LogMessage "The host $currenthost is not initialized in hostsData."
            }
        }
    }
        
    # CSV Export for hostsData and summaryData

    # Define the CSV file paths
    $csvFilePathHosts = "data/csv/host_metrics.csv"
    $csvFilePathSummary = "data/csv/summary.csv"
    $csvFilePathHardwareInventory = "data/csv/hardware_inventory.csv"

    # Check if hostsData contains values and export to CSV
    if ($hostsData -and $hostsData.Values.Count -gt 0) {
        if (-not $Silent) {
            Add-LogMessage "Processing hosts data for CSV export. Data content:"
        }

        # Prepare hostsData for export by creating a list of exportable objects
        $exportableHostsData = @()

        foreach ($key in $hostsData.Keys) {
            $hostData = $hostsData[$key]

            # Create an exportable object for each host
            $exportableHost = [PSCustomObject]@{
                HostName                 = $hostData.host_name
                CPUUsage                 = $hostData.cpu_usage
                RAMUsage                 = $hostData.ram_usage
                Disk1Usage               = $hostData.disk1_usage
                Disk2Usage               = $hostData.disk2_usage
                Disk3Usage               = $hostData.disk3_usage
                PowerOnFailureTime       = $hostData.power_on_failure_time
                ShutdownFailureTime      = $hostData.shutdown_failure_time
                OverallStatus            = $hostData.overall_status
                FailedPercentage         = $hostData.failed_percentage
                HighLoadPercentage       = $hostData.high_load_percentage
                CriticalErrorPercentage  = $hostData.critical_Error_percentage
                TotalActiveSessions      = $hostData.total_active_sessions
                TotalUpdatesInstalled    = $hostData.total_updates_installed
                TotalCriticalLogs        = $hostData.total_critical_logs
                TotalErrorLogs           = $hostData.total_Error_logs
                TotalHostsShutdownFailed = $hostData.total_hosts_shutdown_failed
                BootTime                 = $hostData.boot_time
                InventoryDatestamp       = $hostData.Inventory_datestamp  
            }

            # Add to the exportable list
            $exportableHostsData += $exportableHost
        }

        # Export to CSV if the file does not already exist; otherwise, append to the existing file
        if (-Not (Test-Path $csvFilePathHosts)) {
            if (-not $Silent) {
                Add-LogMessage "Creating new CSV file for hosts data."
            }
            $exportableHostsData | Export-Csv -Path $csvFilePathHosts -NoTypeInformation
        }
        else {
            if (-not $Silent) {
                Add-LogMessage "Hosts CSV file found. Appending data."
            }
            $exportableHostsData | Export-Csv -Path $csvFilePathHosts -NoTypeInformation -Append
        }
    }
    else {
        if (-not $Silent) {
            Add-LogMessage "No data found in hostsData."
        }
    }

    # Check if summaryData contains values and export to CSV
    if ($summaryData -ne "NULL" -and $summaryData.Count -gt 0) {
        if (-not $Silent) {
            Add-LogMessage "Processing summary data for CSV export. Data content:"
        }
    
        # Create an exportable object for the summary data
        $exportableSummaryData = [PSCustomObject]@{
            TotalHosts               = $summaryData.total_hosts
            FailedHostsCount         = $summaryData.failed_hosts_count
            FailedPercentage         = $summaryData.failed_percentage
            HighLoadPercentage       = $summaryData.high_load_percentage
            CriticalErrorPercentage  = $summaryData.critical_Error_percentage
            ActiveSessionPercentage  = $summaryData.active_session_percentage
            TotalUpdatesInstalled    = $summaryData.total_updates_installed
            TotalCriticalLogs        = $summaryData.total_critical_logs
            TotalErrorLogs           = $summaryData.total_Error_logs
            TotalActiveSessions      = $summaryData.total_active_sessions
            TotalHostsShutdownFailed = $summaryData.total_hosts_shutdown_failed
            OverallStatus            = $summaryData.overall_status
        }

        # Export to CSV if the file does not already exist; otherwise, append to the existing file
        if (-Not (Test-Path $csvFilePathSummary)) {
            if (-not $Silent) {
                Add-LogMessage "Creating new CSV file for summary data."
            }
            $exportableSummaryData | Export-Csv -Path $csvFilePathSummary -NoTypeInformation
        }
        else {
            if (-not $Silent) {
                Add-LogMessage "Summary CSV file found. Appending data."
            }
            $exportableSummaryData | Export-Csv -Path $csvFilePathSummary -NoTypeInformation -Append
        }
    }
    else {
        if (-not $Silent) {
            Add-LogMessage "No data found in summaryData."
        }
    }

    if ($GroupNameenerateInventory) {

        $exportableHardwareData = @()
        foreach ($currenthost in $successfulHosts) {
            # Retrieve powered-on host data directly from the $hostsData dictionary
            if ($hostsData.ContainsKey($currenthost)) {
                $hostData = $hostsData[$currenthost]
        
                # Create an exportable hardware inventory object for the powered-on host only
                $exportableHardware = [PSCustomObject]@{
                    HostName           = $hostData.host_name
                    CPUModel           = $hostData.cpu_model
                    CPUCores           = $hostData.cpu_cores
                    RAMCapacity        = $ramCapacityGB
                    NetworkAdapter     = $hostData.network_adapter
                    Motherboard        = $hostData.motherboard
                    BIOSVersion        = $hostData.bios_version
                    BIOSReleaseDate    = $hostData.bios_release_date
                    OS                 = $hostData.os_caption
                    OSBuildNumber      = $hostData.os_build_number
                    GPUModel           = $hostData.gpu_model
                    GPUDriverVersion   = $hostData.gpu_driver_version
                    InventoryDatestamp = $hostData.Inventory_datestamp
                }
                
                $exportableHardwareData += $exportableHardware
            }
        }
        
        if (-Not (Test-Path $csvFilePathHardwareInventory)) {
            if (-not $Silent) {
                Add-LogMessage "Creating new CSV file for hardware inventory data."
            }
            $exportableHardwareData | Export-Csv -Path $csvFilePathHardwareInventory -NoTypeInformation
        }
        else {
            if (-not $Silent) {
                Add-LogMessage "Hardware inventory CSV file found. Appending data."
            }
            $exportableHardwareData | Export-Csv -Path $csvFilePathHardwareInventory -NoTypeInformation -Append
        }
    }


    # Prepare the OpshostsRecord for database 

    # Get the names of updates applied to the hosts.

    # Initialize a dictionary to store updates by host
    $updatesByHost = @{}

    # Iterate over $updateLogs and group update names by each host
    foreach ($log in $updateLogs) {
        $HostName = $log.HostName
        $updateName = $log.Status

        # Check if the host already exists in the dictionary; if not, initialize it
        if (-not $updatesByHost.ContainsKey($HostName)) {
            $updatesByHost[$HostName] = @() # Initialize with an empty array
        }

        # Add the update name to the host's array
        $updatesByHost[$HostName] += $updateName
    }

    # Add update names to each host in the $hostsData object
    foreach ($HostName in $hostsData.Keys) {
        # Check if there are updates for the current host
        if ($updatesByHost.ContainsKey($HostName)) {
            $hostsData[$HostName].update_names = $updatesByHost[$HostName] # Store the names in the host object
        }
        else {
            $hostsData[$HostName].update_names = @() # If no updates, leave an empty array
        }
    }

    # $activeSessionsLogs contains active session data
    foreach ($log in $activeSessionsLogs) {
        $HostName = $log.HostName
        $sessionName = $log.Status

        # Check if the host in $hostsData has an entry and add the session_name
        if ($hostsData.ContainsKey($HostName)) {
            $hostsData[$HostName].session_name = $sessionName
        }
    }
   
    # First, data is inserted into hardware_inventory since host_metrics has a unique key that points to a foreign key in hardware_inventory.
    if ($generateInventory) {

        # Prepare the hardwareInventory data for database 
        
        foreach ($currenthost in $successfulHosts) {

            $hardwareInventory = Get-HardwareInventory -HostName $currenthost -credential $PsRemotingCredential
           
            $ramCapacity = $hardwareInventory.RAMInfo.Capacity
            # When there is more than one memory module, it is an array of objects (multiple modules) that need to be summed.
            $ramCapacityGB = ($ramCapacity | Measure-Object -Sum).Sum / 1GB
            $ramCapacityGB = [math]::Round($ramCapacityGB, 2)
                    
            $biosReleaseDate = [DateTime]::ParseExact($hardwareInventory.BIOSInfo.ReleaseDate, "MM/dd/yyyy HH:mm:ss", $null)
            $FormattedDateBios = $biosReleaseDate.ToString("yyyy-MM-dd HH:mm:ss")
            $InventoryDatestamp = if ($GroupNameenerateInventory) { "NOW()" -replace '"', '' } else { "NULL" -replace '"', '' } 

            # SQL insertion query for hardware inventory data
            
            $insertQueryHardware = @"
    INSERT INTO hardware_inventory 
    (host_name, cpu_model, cpu_cores, ram_capacity_gb, network_adapter, mac_adapter, motherboard, bios_version, bios_release_date, 
    os_caption, os_build_number, gpu_model, gpu_driver_version, inventory_datestamp)
        VALUES (
        '$($currenthost)', 
        '$($hardwareInventory.CPUInfo.Name)', 
        '$($hardwareInventory.CPUInfo.NumberOfCores)', 
        '$ramCapacityGB',
        '$($hardwareInventory.NetworkInfo.Name)',
        '$($hardwareInventory.NetworkInfo.MACAddress)', 
        '$($hardwareInventory.MotherboardInfo.Manufacturer) - $($hardwareInventory.MotherboardInfo.Product)', 
        '$($hardwareInventory.BIOSInfo.SMBIOSBIOSVersion)', 
        '$($FormattedDateBios)', 
        '$($hardwareInventory.OSInfo.Caption)', 
        '$($hardwareInventory.OSInfo.BuildNumber)', 
        '$($hardwareInventory.GPUInfo.Name)', 
        '$($hardwareInventory.GPUInfo.DriverVersion)',
        $InventoryDatestamp        
        );
"@

            # Show the generated SQL query for the current host's hardware inventory
            if (-not $Silent) {
                Add-LogMessage "Inserting hardware inventory for host: $currenthost"
            }
            Add-LogMessage $insertQueryHardware         
            
            mysql -h $dbHost -u $dataBaseUser -p"$dataBasePasswd" -e "$insertQueryHardware" -D $dbName
        }
    }

    # SQL insertion query for host metrics data
    foreach ($HostName in $hostsData.Keys) {
                    
        $hostData = $hostsData[$HostName]
        
        $cpuUsage = if ([string]::IsNullOrEmpty($hostData.cpu_usage)) { "NULL" -replace '"', '' } else { $hostData.cpu_usage }
        $ramUsage = if ([string]::IsNullOrEmpty($hostData.ram_usage)) { "NULL" -replace '"', '' } else { $hostData.ram_usage }
        $disk1Usage = if ([string]::IsNullOrEmpty($hostData.disk1_usage)) { "NULL" -replace '"', '' } else { $hostData.disk1_usage -replace "%", "" }
        $disk2Usage = if ([string]::IsNullOrEmpty($hostData.disk2_usage)) { "NULL" -replace '"', '' } else { $hostData.disk2_usage -replace "%", "" }
        $disk3Usage = if ([string]::IsNullOrEmpty($hostData.disk3_usage)) { "NULL" -replace '"', '' } else { $hostData.disk3_usage -replace "%", "" }
        $updateNames = if ($null -ne $hostData.update_names) { "'" + ($hostData.update_names -join ', ') + "'" } else { "NULL" -replace '"', '' }
        $updateStatus = if ([string]::IsNullOrEmpty($hostData.update_status)) { "NULL" -replace '"', '' } else { "'$($hostData.update_status)'" }
        $sessionActive = if ($hostData.session_active -eq $true) { 1 } else { 0 }
        
        # Extract users from hosts with active sessions
        if ($hostData.session_active -eq 1) {
            # Clean and prepare the session names for the SQL query
            $sessionName = foreach ($log in $activeSessionsLogs) {
                if ($log.HostName -eq $HostName) {
                    if ([string]::IsNullOrEmpty($hostData.session_name)) { 
                        'N/A'
                    }
                    else { 
                        $(($log.Status -replace 'Host in Session \[ ', '') -replace ']', ',')
                    }
                }
            }
            # Remove the last comma from the string for correct  into the SQL query.
            $sessionName = "'$($sessionName.TrimEnd(','))'"
        }
        else {
            $sessionName = ("NULL" -replace '"', '')
        }

        $shutdownStatus = if ([string]::IsNullOrEmpty($hostData.shutdown_status)) { "NULL" -replace '"', '' } else { $hostData.shutdown_status }
        $powerOnFailureTime = if ([string]::IsNullOrEmpty($hostData.power_on_failure_time)) { "NULL" -replace '"', '' } else { "'$($hostData.power_on_failure_time)'" } 
        $shutdownFailureTime = if ([string]::IsNullOrEmpty($hostData.shutdown_failure_time)) { "NULL" -replace '"', '' } else { "'$($hostData.shutdown_failure_time)'" }
        $bootTime = if ([string]::IsNullOrEmpty($hostData.boot_time)) { "NULL" -replace '"', '' } else { "'$($hostData.boot_time)'" } 
        
        # To allow records in host_metrics that are not necessarily linked to hardware_inventory. When an inventory is generated, it assigns the current
        # date and time as the value for inventoryDatestamp. When no inventory is generated it assigns NULL to the inventoryDatestamp field.
        
        #If the host is unreachable (powered off), do not associate an inventory date. This way, its record is saved in host_metrics. 
        #Otherwise, it would not be possible to establish the relationship between the hardware_inventory and host_metrics tables.
        
        if ($successfulHosts -contains $HostName) {
            $InventoryDatestamp = if ($GroupNameenerateInventory) { "NOW()" -replace '"', '' } else { "NULL" -replace '"', '' } 
        }
        else {  
            $InventoryDatestamp = ("NULL" -replace '"', '')
        }

        $insertQueryHostMetrics = @"
    INSERT INTO host_metrics 
    (host_name, cpu_usage, ram_usage, disk1_usage, disk2_usage, disk3_usage, timestamp, update_names, update_status, 
    session_active, session_name, shutdown_status, power_on_failure_time, shutdown_failure_time, boot_time, script_version, admin_comments,
    inventory_datestamp)
        VALUES (
        '$($hostData.host_name)', 
        $cpuUsage, 
        $ramUsage, 
        $disk1Usage, 
        $disk2Usage, 
        $disk3Usage, 
        NOW(), 
        $updateNames,
        $updateStatus, 
        $sessionActive,
        $sessionName, 
        $shutdownStatus, 
        $powerOnFailureTime,
        $shutdownFailureTime,
        $bootTime, 
        '$($GroupNamelobal:version)', 
        '$($adminComments)',
        $InventoryDatestamp
        ); 
"@
        if (-not $Silent) {
            Add-LogMessage "Inserting host metrics data for host: $($hostData.host_name)"
        }
        Add-LogMessage $insertQueryHostMetrics

        mysql -h $dbHost -u $dataBaseUser -p"$dataBasePasswd" -e "$insertQueryHostMetrics" -D $dbName
    }

    # SQL insertion query for summary data, with timestamps
    $insertQuerySummary = @"
    INSERT INTO host_summary 
    (total_hosts, failed_hosts_count, failed_percentage, high_load_percentage, critical_Error_percentage, 
    active_session_percentage, total_updates_installed, total_critical_logs, total_Error_logs, 
    total_active_sessions, total_hosts_shutdown_failed, overall_status, execution_start_time, execution_end_time, time_check)
        VALUES (
        $($summaryData.total_hosts), 
        $($summaryData.failed_hosts_count), 
        $($summaryData.failed_percentage), 
        $($summaryData.high_load_percentage), 
        $($summaryData.critical_Error_percentage), 
        $($summaryData.active_session_percentage), 
        $($summaryData.total_updates_installed), 
        $($summaryData.total_critical_logs), 
        $($summaryData.total_Error_logs), 
        $($summaryData.total_active_sessions), 
        $($summaryData.total_hosts_shutdown_failed),
        '$($summaryData.overall_status)', 
        '$global:formattedExecutionStartTime', 
        '$global:formattedExecutionEndTime',
        '$global:formattedTimeCheck'
        ); 
"@

    # Show the generated SQL query for summary data
    if (-not $Silent) {
        Add-LogMessage "Generated SQL query for SummaryData:"
    }
    Add-LogMessage $insertQuerySummary

    mysql -h $dbHost -u $dataBaseUser -p"$dataBasePasswd" -e "$insertQuerySummary" -D $dbName
}

Export-ModuleMember -Function Initialize-DataManager, New-ReportFiles