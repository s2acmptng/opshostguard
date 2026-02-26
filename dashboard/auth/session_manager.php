<?php

// session_manager.php [OpsHostGuard Module PHP]

/**
 * Manages user sessions for the OpsHostGuard project.
 * 
 * This script provides functions to check user authentication status, enforce session timeout policies
 * based on inactivity, and handle redirections to the login page when necessary. It relies on 
 * `config.php` for the `BASE_URL` constant used in redirection paths.
 * 
 * @notes
 * - Ensure that `config.php` is accessible, as it contains critical configuration settings like `BASE_URL`.
 * - `checkSessionTimeout()` allows customization of the session timeout period via the `$timeout` parameter 
 *   and the redirection URL after timeout via the `$redirectUrl` parameter.
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
 * This script is provided "as-is" and is intended for internal use at University of Extremadura.
 * No warranties, express or implied, are provided. Any modifications or adaptations are not covered 
 * under this disclaimer.
 * 
 * @link https://github.com/n7rc/OpsHostGuard
 */

require_once __DIR__ . '/../config/config.php';

session_start();

/**
 * Checks if the user is logged in. Redirects to login page if not authenticated.
 */
function checkLogin()
{
    if (!isset($_SESSION['loggedin']) || $_SESSION['loggedin'] !== true) {
        header("Location: " . BASE_URL . "/public/index.php?message=login_required");
        exit();
    }
}

/**
 * Checks if the session has timed out due to inactivity.
 * 
 * @param int $timeout Session timeout in seconds. Default is 10 minutes.
 * @param string $redirectUrl URL to redirect after session expiration.
 */
function checkSessionTimeout($timeout = null, $redirectUrl = null){

    global $userData;

    // Set default timeout from configuration if not provided
    if ($timeout === null) {
        $timeout = $userData['SessionConfig']['sessionTimeout'];
    }

    // Set the default redirect URL if none is provided   
    if ($redirectUrl === null) {
        $redirectUrl = BASE_URL . "/public/index.php?message=session_expired";
    }

    if (isset($_SESSION['last_activity']) && (time() - $_SESSION['last_activity'] > $timeout)) {
        session_unset();
        session_destroy();
        header("Location: $redirectUrl");
        exit();
    }
    $_SESSION['last_activity'] = time();
}
