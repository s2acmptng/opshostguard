<?php

// auth_controller.php [OpsHostGuard Module PHP]

/**
 * Handles user authentication for the OpsHostGuard system, verifying credentials and managing sessions 
 * to control access to the dashboard.
 * 
 * This PHP script is responsible for processing user login requests in the "OpsHostGuard" project.
 * It validates the username and password submitted via a login form, establishes a session if the 
 * credentials are correct, and redirects the user to the main dashboard. If credentials are incorrect, 
 * an Error message is displayed and the user is redirected to the login page.
 * 
 * @example Successful login:
 *     $_POST['username'] = 'validUser';
 *     $_POST['password'] = 'validPassword';
 *     // Redirects to dashboard on Successful login.
 *
 * @example Failed login:
 *     $_POST['username'] = 'invalidUser';
 *     $_POST['password'] = 'invalidPassword';
 *     // Redirects to login page with Error message.
 * 
 * @param string $username Username entered by the user in the login form, retrieved via POST.
 * @param string $password Password entered by the user in the login form, retrieved via POST.
 * 
 * @throws Exception If authentication credentials files are missing or inaccessible.
 * 
 * @return void Redirects to the dashboard on Success or to the login page on failure.
 * 
 * @notes
 * - The script compares the username and password to values encrypted in PowerShell files.
 * - If authentication fails, the user is redirected to the login page with an Error message.
 *
 * @organization
 * Developed for: Faculty of Documentation and Communication Sciences at the University of Extremadura.
 *
 * @author
 * Alberto Ledo [Faculty of Documentation and Communication Sciences] - with assistance from OpenAI
 * IT Department: University of Extremadura - IT Services for Facilities
 * Contact: albertoledo@unex.es
 * 
 * @version
 * 2.0 - Refactoring and Migration to Event-Driven Model
 * 1.0 - Initial version by Alberto Ledo
 * 
 * @date November 3, 2024
 *
 * @license
 * This script is strictly for internal use within University of Extremadura.
 * It is designed for the IT infrastructure of the University of Extremadura and may not function 
 * as expected in other environments.
 *
 * @link
 * https://github.com/n7rc/OpsHostGuard
 */

require_once __DIR__ . '/../config/config.php';
require_once __DIR__ . '/../auth/session_manager.php';

if (session_status() === PHP_SESSION_NONE) {
    session_start();
}

// Configurar opciones de error
ini_set('display_errors', 1);
ini_set('display_startup_errors', 1);
error_reporting(E_ALL);

// Archivos de registro de depuración
define('DEBUG_LOG', __DIR__ . '/debug_log.log');

// Ejecutar comando PowerShell con captura detallada de errores
function executePowerShellCommand($command) {
    $output = [];
    $returnVar = null;

    exec($command . ' 2>&1', $output, $returnVar);

    // Registrar salida para depuración
    file_put_contents(DEBUG_LOG, "Executing Command: $command\nOutput: " . print_r($output, true) . "\nReturn Code: $returnVar\n", FILE_APPEND);

    return ['output' => $output, 'returnVar' => $returnVar];
}

// Sanitize and validate the 'username' and 'password' inputs
$dashboardUser = isset($_POST['username']) ? htmlspecialchars(trim($_POST['username']), ENT_QUOTES, 'UTF-8') : null;
$dashboardPasswd = isset($_POST['password']) ? htmlspecialchars(trim($_POST['password']), ENT_QUOTES, 'UTF-8') : null;
// Redirect if credentials are missing
if (!$dashboardUser || !$dashboardPasswd) {
    header("Location: " . BASE_URL . "/public/index.php?message=missing_credentials");
    exit();
}

// Validate credentials via PowerShell
$getDashboardUser = 'powershell.exe -ExecutionPolicy Bypass -Command "Import-Module -Name ../../modules/security/CredentialsManager.psm1; Get-Credential -credentialFilePath "./../../modules/security/credentials/user_dashboard.xml""';
$getDashboardPasswd = 'powershell.exe -ExecutionPolicy Bypass -Command "Import-Module -Name ../../modules/security/CredentialsManager.psm1; Get-Credential -credentialFilePath "./../../modules/security/credentials/passwd_dashboard.xml""';

// Function to get the last element of an array
function getLastElement($array) {
    if (!empty($array)) {
        return end($array); // Return the last element
    }
    return null; // Return null if the array is empty
}

// Execute the PowerShell commands and capture output
$outputUser = [];
$outputPasswd = [];
exec($getDashboardUser . ' 2>&1', $outputUser);
exec($getDashboardPasswd . ' 2>&1', $outputPasswd);

// Extract the last element from the output arrays
$parseDashboardUser = trim(getLastElement($outputUser));
$parseDashboardPasswd = trim(getLastElement($outputPasswd));

// Validate that the extracted outputs are not empty and follow expected structure
if (!$parseDashboardUser || !$parseDashboardPasswd) {
    // Log the issue for debugging
    file_put_contents('debug_log.log', "Empty or invalid output for user or password.\nUser Output: " . print_r($outputUser, true) . "\nPassword Output: " . print_r($outputPasswd, true) . "\n", FILE_APPEND);

    // Redirect to error message
    header("Location: " . BASE_URL . "/public/index.php?message=auth_error");
    exit();
}

// Validate credentials and manage session
if ($dashboardUser === $parseDashboardUser && $dashboardPasswd === $parseDashboardPasswd) {
    $_SESSION['loggedin'] = true;
    $_SESSION['username'] = $dashboardUser;
    $_SESSION['last_activity'] = time();
    header("Location: " . BASE_URL . "/views/dashboard/dashboard.php");
    exit();
} else {
    header("Location: " . BASE_URL . "/public/index.php?message=incorrect_credentials");
    exit();
}