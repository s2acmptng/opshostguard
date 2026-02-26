<?php

// index.php [OpsHostGuard]

/**
 * Renders the login page for the OpsHostGuard project, handling session messages and loading 
 * configuration values such as the project version.
 * 
 * This script initializes essential settings, loads configuration and session manager files, 
 * and displays an HTML form for user login. It also manages alert messages based on URL parameters.
 * 
 * @example Successful login:
 *     URL: http://localhost/opshostguard/index.php
 *     // Shows login form, redirects to dashboard upon Successful login.
 *
 * @example Error message display:
 *     URL: http://localhost/opshostguard/index.php?message=incorrect_credentials
 *     // Displays an Error message if credentials are incorrect.
 * 
 * @notes
 * - Requires `config.php` for BASE_URL and `session_manager.php` for session control.
 * - Loads the project version from the `.VERSION` file using `getVersion()`.
 * - Displays alert messages based on specific URL parameters (`session_expired`, `login_required`, etc.).
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
 
 require_once __DIR__ . '/../config/config.php';
 require_once __DIR__ . '/../auth/session_manager.php';

ini_set('display_errors', 1);
ini_set('display_startup_errors', 1);
error_reporting(E_ALL);
 
 $version = getVersion();
 $message = isset($_GET['message']) ? $_GET['message'] : '';
 
 // Determine the alert message based on the URL parameter
 switch ($message) {
     case 'session_expired':
         $alertMessage = "Your session has expired\n Please log in again";
         break;
     case 'login_required':
         $alertMessage = "You need to log in to access this page.";
         break;
     case 'missing_credentials':
         $alertMessage = "Please enter both your username and password.";
         break;
     case 'incorrect_credentials':
         $alertMessage = "Invalid username or password\n Please try again";
         break;
     case 'auth_error':
         $alertMessage = "An error occurred during authentication\nPlease try again or contact support";
            break;
     default:
         $alertMessage = '';
 }
 
 ?>
 <!DOCTYPE html>
 <html lang="en">
 <head>
     <meta charset="UTF-8">
     <meta name="viewport" content="width=device-width, initial-scale=1.0">
     <link rel="icon" href="<?php echo BASE_URL; ?>/public/assets/images/favicon.png" type="image/png">
     <title>Login - OpsHostGuard</title>
     <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.0.0-beta3/css/all.min.css">
     <link href="https://fonts.googleapis.com/css2?family=Roboto:wght@400;700&family=Lato:wght@400;700&display=swap" rel="stylesheet">
     <link rel="stylesheet" href="<?php echo BASE_URL; ?>/public/assets/css/main-styles.css">
     <script src="<?php echo BASE_URL; ?>/public/assets/js/main.js"></script>
 </head>
 <body class="body">
     <div class="login-container">
         <div class="login-header">  
         <img src="<?php echo BASE_URL; ?>/public/assets/images/logo.png" alt="OpsHostGuard Logo" class="login-logo">
             <hr class="divider">
             <a href="#"><i class="fa-solid fa-user"></i></a>
         </div>
 
         <!-- Login form, sends data to AuthController.php via POST -->
         <form class="login-form" action="<?php echo BASE_URL; ?>/controllers/AuthController.php" method="post">
             <div class="form-group">
                 <label for="username">Username</label>
                 <input type="text" id="username" name="username" required>
             </div>
             <div class="form-group">
                 <label for="password">Password</label>
                 <input type="password" id="password" name="password" required>
             </div>
             <div class="form-group">
                 <button type="submit" class="login-button">Login</button>
             </div>
             <div class="footer-legend">
                <?php echo "Version: " . htmlspecialchars($version); ?> (Built: <?php echo $configData['Config']['ReleaseTime']; ?>)
             </div>
         </form>
     </div>
 
     <!-- Display alert message if applicable -->
     <?php if ($alertMessage): ?>
         <div class="alert-container">
             <button class="close-button" onclick="this.parentElement.style.display='none';">&times;</button>
             <h2>Alert</h2>
             <p><?php echo nl2br(htmlspecialchars($alertMessage)); ?></p>
         </div>
     <?php endif; ?>
 </body>
 </html>
 