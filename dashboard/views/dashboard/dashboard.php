<?php

// dashboard.php [OpsHostGuard Module PHP]

/**
 * Renders the main Dashboard page for the OpsHostGuard project.
 * 
 * This script loads essential configurations, manages user sessions, and provides the structure for 
 * the Dashboard user interface, including navigation menus, control options, and system management 
 * tools. It also enforces user authentication and session timeout policies.
 * 
 * @notes
 * - Requires `config.php` to load essential configuration settings, including `BASE_URL`.
 * - Uses `session_manager.php` to verify user login status and manage session expiration.
 * - Displays the current version of OpsHostGuard, retrieved from the `.VERSION` file, in the footer.
 * 
 * @organization
 * Developed for: Faculty of Documentation and Communication Sciences at the University of Extremadura.
 * 
 * @dependencies
 * - `config.php`: Loads BASE_URL and other configuration settings.
 * - `session_manager.php`: Manages user authentication and session timeout policies.
 * 
 * @features
 * - Provides navigation for various panels, including Operator, Administrator, Report, and Statistics.
 * - Displays system management options, such as turning hosts on/off, checking status, and analyzing load.
 * - Includes links to various reports, logs, and inventory management pages.
 * 
 * @author
 * Alberto Ledo [Faculty of Documentation and Communication Sciences] - with assistance from OpenAI
 * IT Department: University of Extremadura - IT Services for Facilities
 * Contact: albertoledo@unex.es
 * 
 * @version 2.0 - Refactoring and Migration to Event-Driven Model
 * 
 * @date November 3, 2024
 * 
 * @license
 * This script is provided "as-is" and is intended for internal use at University of Extremadura.
 * No warranties, express or implied, are provided. Any modifications or adaptations are not covered 
 * under this disclaimer.
 * 
 * @link https://github.com/n7rc/OpsHostGuard
 */

// Load configuration and session management
require_once __DIR__ . '/../../config/config.php';
require_once __DIR__ . '/../../auth/session_manager.php';

$version = getVersion();
$userData = getUserData();

// Ensure user is logged in and check for session expiration
checkLogin();
checkSessionTimeout();

?>

<!DOCTYPE html>
<html lang="en">

<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <link rel="icon" href="<?php echo BASE_URL; ?>/public/assets/images/favicon.png" type="image/png">      
    <title>OpsHostGuard Dashboard</title>

    <!-- External resources for styling and icons -->
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.4.0/css/all.min.css">
    <link rel="stylesheet" href="<?php echo BASE_URL; ?>/public/assets/css/dashboard/dashboard.css">
    <script src="<?php echo BASE_URL; ?>/public/assets/js/dashboard/dashboard.js"></script>
</head>

<body>

    <!-- Top Navigation Menu -->
    <div class="top-menu">   
    <a href="#"><i class="fa-solid fa-house nav-icon"></i></a>
        <div class="nav-text">Operator Panel</div>
        <div class="nav-text">Administrator Panel</div>
        <div class="nav-text">Report Panel</div>
        <div class="nav-text">Statistics Panel</div>
        <a href="<?php echo BASE_URL; ?>/public/index.php"><i class="fa fa-sign-out nav-icon"></i></a>
    </div>

    <!-- Footer with logo and version Information -->
    <div class="footer-logo">
        <img src="<?php echo BASE_URL; ?>/public/assets/images/logo.png" alt="OpsHostGuard Logo" width="100">
    </div>
    <div class="footer-legend">
        OpsHostGuard - <?php echo "Version: " . $version; ?> (Built: <?php echo $configData['Config']['ReleaseTime']; ?>)
    </div>

    <!-- Side Navigation Menu -->
    <div class="side-menu" id="sideMenu">
        <div class="menu-option">
            <a href="<?php echo BASE_URL; ?>/views/reports/standar_report.php"><i class="fas fa-chart-pie"></i>  General Report</a>
        </div>
        <div class="menu-option">
            <a href="<?php echo BASE_URL; ?>/views/reports/hardware_inventory_report.php"><i class="fas fa-clipboard-list"></i>  Inventory Report</a>
        </div>
        <div class="menu-option">
            <i class="fas fa-file-csv"></i>  CSV and Logs
        </div>
        <div class="menu-option">
            <i class="fas fa-terminal"></i>  Ops Console
        </div>
        <div class="menu-option">
            <i class="fas fa-database"></i>  Ops DB
        </div>
        <div class="menu-option">
            <i class="fas fa-file-alt"></i>  Ops Log
        </div>
        <div class="menu-option">
            <i class="fas fa-sliders-h"></i>  Advanced Options
        </div>
        <div class="menu-option">
            <i class="fas fa-code"></i>  Powershell
        </div>       
        <div class="menu-option logout">
            <a href="<?php echo BASE_URL; ?>/public/index.php"><i class="fas fa-sign-out-alt"></i>  Logout</a>
        </div>
    </div>

    <!-- Main Content Area -->
    <div class="content">
        <!-- Row for Select Group and Select Host options -->
        <div class="card-row">
            <div class="icon-card">
                <i class="fas fa-layer-group"></i>
                <div class="icon-label">Select Group</div>
            </div>
            <div class="icon-card">
                <i class="fas fa-server"></i>
                <div class="icon-label">Select Host</div>
            </div>
        </div>

        <!-- Grid with various system management options -->
        <div class="icon-grid">
            <div class="icon-card">
                <i class="fas fa-power-off"></i>
                <div class="icon-label">Turn On</div>
            </div>
            <div class="icon-card">
                <i class="fas fa-sync-alt"></i>
                <div class="icon-label">Restart</div>
            </div>
            <div class="icon-card">
                <i class="fas fa-times-circle"></i>
                <div class="icon-label">Shut Down</div>
            </div>
            <div class="icon-card">
                <i class="fas fa-network-wired"></i>
                <div class="icon-label">Host Status</div>
            </div>
            <div class="icon-card">
                <i class="fas fa-user-check"></i>
                <div class="icon-label">Active Sessions</div>
            </div>
            <div class="icon-card">
                <i class="fas fa-tachometer-alt"></i>
                <div class="icon-label">Load Analysis</div>
            </div>
            <div class="icon-card">
                <i class="fas fa-redo"></i>
                <div class="icon-label">Update Windows</div>
            </div>
            <div class="icon-card">
                <i class="fas fa-clipboard-list"></i>
                <div class="icon-label">Event Logs</div>
            </div>
            <div class="icon-card">
                <i class="fas fa-hdd"></i>
                <div class="icon-label">Hardware Inventory</div>
            </div>
            <div class="icon-card">
                <i class="fas fa-tools"></i>
                <div class="icon-label">Basic Check</div>
            </div>
            <div class="icon-card">
                <i class="fas fa-search-plus"></i>
                <div class="icon-label">Complete Scan</div>
            </div>
            <div class="icon-card">
                <i class="fas fa-bug"></i>
                <div class="icon-label">Diagnostics Mode</div>
            </div>
        </div>
    </div>  
</body>
</html>
