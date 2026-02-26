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
 
 // Validar y sanitizar las entradas del usuario
 $dashboardUser = isset($_POST['username']) ? trim($_POST['username']) : null;
 $dashboardPasswd = isset($_POST['password']) ? trim($_POST['password']) : null;
 
 if (!$dashboardUser || !$dashboardPasswd) {
     header("Location: " . BASE_URL . "/public/index.php?message=missing_credentials");
     exit();
 }
 
 // Comandos para obtener las credenciales
 //$getDashboardUserCmd = 'powershell.exe -ExecutionPolicy Bypass -Command "Import-Module -Name C:/xampp/htdocs/opshostguard/modules/core/system/OpsInit.psm1; Import-Module -Name C:/xampp/htdocs/opshostguard/modules/security/credentialsManager.psm1; Get-Credential -credentialFilePath \'./modules/security/credentials/user_dashboard.xml\'"';
 $getDashboardUserCmd = 'powershell.exe -ExecutionPolicy Bypass -Command "Import-Module -Name ./../../modules/core/system/OpsInit.psm1; Import-Module -Name ./../../modules/security/credentialsManager.psm1; Get-Credential -credentialFilePath \'./modules/security/credentials/user_dashboard.xml\'"';
 
 //$getDashboardPasswdCmd = 'powershell.exe -ExecutionPolicy Bypass -Command "Import-Module -Name C:/xampp/htdocs/opshostguard/modules/core/system/OpsInit.psm1; Import-Module -Name C:/xampp/htdocs/opshostguard/modules/security/credentialsManager.psm1; Get-Credential -credentialFilePath \'./modules/security/credentials/passwd_dashboard.xml\'"';
 $getDashboardPasswdCmd = 'powershell.exe -ExecutionPolicy Bypass -Command "Import-Module -Name ./../../modules/core/system/OpsInit.psm1; Import-Module -Name ./../../modules/security/credentialsManager.psm1; Get-Credential -credentialFilePath \'./modules/security/credentials/passwd_dashboard.xml\'"';
 
 // Ejecutar los comandos
 $resultUser = executePowerShellCommand($getDashboardUserCmd);
 $resultPasswd = executePowerShellCommand($getDashboardPasswdCmd);
 
 // Extraer último elemento de las salidas
 $parseDashboardUser = trim(end($resultUser['output']));
 $parseDashboardPasswd = trim(end($resultPasswd['output']));
 
 // Validar si las salidas son válidas
 if (empty($parseDashboardUser) || empty($parseDashboardPasswd)) {
     file_put_contents(DEBUG_LOG, "Error: Empty or invalid PowerShell output.\nUser Output: " . print_r($resultUser, true) . "\nPassword Output: " . print_r($resultPasswd, true) . "\n", FILE_APPEND);
 
     header("Location: " . BASE_URL . "/public/index.php?message=auth_error");
     exit();
 }
 
 // Registrar credenciales para depuración
 file_put_contents(DEBUG_LOG, "Input Credentials:\nUsername: $dashboardUser\nPassword: $dashboardPasswd\n", FILE_APPEND);
 file_put_contents(DEBUG_LOG, "Parsed Credentials:\nUsername: $parseDashboardUser\nPassword: $parseDashboardPasswd\n", FILE_APPEND);
 
 // Comparar credenciales
 if (strcasecmp($dashboardUser, $parseDashboardUser) === 0 && strcmp($dashboardPasswd, $parseDashboardPasswd) === 0) {
     file_put_contents(DEBUG_LOG, "Authentication successful for user: $dashboardUser\n", FILE_APPEND);
 
     $_SESSION['loggedin'] = true;
     $_SESSION['username'] = $dashboardUser;
     $_SESSION['last_activity'] = time();
 
     header("Location: " . BASE_URL . "/views/dashboard/dashboard.php");
     exit();
 } else {
     file_put_contents(DEBUG_LOG, "Authentication failed for user: $dashboardUser\n", FILE_APPEND);
 
     header("Location: " . BASE_URL . "/public/index.php?message=incorrect_credentials");
     exit();
 }
 
 