<?php

// config.php [OpsHostGuard Module PHP]

/**
 * Loads essential configuration settings for the OpsHostGuard project.
 * 
 * This script dynamically defines the base URL (`BASE_URL`) based on the server environment, 
 * retrieves the project version from a `.VERSION` file, and loads additional configuration 
 * data from a JSON file.
 * 
 * @notes
 * - Ensure the `user_config.json` file exists in the specified directory, as this file contains 
 *   critical configuration settings. If it is missing, the script will exit with an Error message.
 * - The `getVersion()` function expects a `.VERSION` file in the project root directory to indicate 
 *   the current version of OpsHostGuard. If this file is not found, a default Error message will be returned.
 * 
 * @organization
 * Developed for: Faculty of Documentation and Communication Sciences at the University of Extremadura.
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
 * This script is strictly for internal use within the University of Extremadura.
 * It is designed for the IT infrastructure of the University of Extremadura and may not function 
 * as expected in other environments.
 * 
 * @link https://github.com/n7rc/OpsHostGuard
 */

// Get the protocol (http or https)
$protocol = (!empty($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off' || $_SERVER['SERVER_PORT'] == 443) ? "https://" : "http://";

// Get the server name (e.g., localhost or example.com)
$host = $_SERVER['HTTP_HOST'];

// Get the base directory of the opshostguard 
$userData = getUserData();
$configData = getConfigData();
$projectDirectory = "/" . $userData['DashboardSettings']['opshostguardDirectory'] . "/dashboard";

// Combine to create the dynamic BASE_URL
define('BASE_URL', $protocol . $host . $projectDirectory);

/**
 * Retrieves the current version from the .VERSION file.
 * 
 * @return string Current version or an Error message if the file is not found.
 */
function getVersion() {
    $versionFilePath = __DIR__ . '/../../.VERSION';
    if (file_exists($versionFilePath)) {
        return file_get_contents($versionFilePath);
    } else {
        return "Error: VERSION file not found.";
    }
}

/**
 * Loads user configuration data from a JSON file.
 * 
 * @param string $configFile Path to the JSON config file.
 * @return array Parsed configuration data or exits on Error.
 */
function getUserData($configFile = __DIR__ . '/../../config/user_config.json') {
    if (file_exists($configFile)) {
        $configContent = file_get_contents($configFile);
        return json_decode($configContent, true);
    } else {
        echo "Error: user_config.json file not found. Please create the file from global_config.example.json";
        exit;
    }
}

/**
 * Loads configuration data from a JSON file.
 * 
 * @param string $configFile Path to the JSON config file.
 * @return array Parsed configuration data or exits on Error.
 */
function getConfigData($configFile = __DIR__ . '/../../config/ops_config.json') {
    if (file_exists($configFile)) {
        $configContent = file_get_contents($configFile);
        return json_decode($configContent, true);
    } else {
        echo "Error: ops_config.json file not found.";
        exit;
    }
}
?>
