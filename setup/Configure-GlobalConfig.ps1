# Path to the user_config.json file
$configPath = "config/user_config.json"

# Function to read and parse the JSON file
function Load-ConfigFile {
    param (
        [string]$path
    )
    if (Test-Path -Path $path) {
        return Get-Content -Path $path | ConvertFrom-Json
    } else {
        if (-not $global:silentMode) {
    Add-LogMessage "Configuration file not found at $path. A new one will be created." -ForegroundColor Yellow
} 
        return [PSCustomObject]@{
            _meta            = [PSCustomObject]@{}
            GPOConfiguration = [PSCustomObject]@{}
            DatabaseConnection = [PSCustomObject]@{}
            HTMLReport       = [PSCustomObject]@{}
            EmailNotification = [PSCustomObject]@{}
        }
    }
}

# Function to prompt the user for configuration input
function Get-UserInput {
    param (
        [string]$prompt,
        [string]$defaultValue
    )
    
    # Show the prompt with a default value if it exists
    $input = Read-Host "$prompt [$defaultValue]"
    
    # Return the input or the default value if input is empty
    if ($input) {
        return $input
    } else {
        return $defaultValue
    }
}

# Load the existing configuration or create a new one
$config = Load-ConfigFile -path $configPath

# Metadata configuration
$config._meta.description = Get-UserInput -prompt "Enter description" -defaultValue ($config._meta.description -or "Global configuration for OpsHostGuard")
$config._meta.version = Get-UserInput -prompt "Enter version" -defaultValue ($config._meta.version -or "1.0")
$config._meta.AUTHOR [© 2024 Alberto Ledo] = Get-UserInput -prompt "Enter author name" -defaultValue ($config._meta.AUTHOR [© 2024 Alberto Ledo] -or "Your Name")
$config._meta.organization = Get-UserInput -prompt "Enter organization" -defaultValue ($config._meta.organization -or "Your Organization")
$config._meta.lastUpdated = (Get-Date -Format "yyyy-MM-dd")

# GPO Configuration
$config.GPOConfiguration.gpoName = Get-UserInput -prompt "Enter GPO name" -defaultValue ($config.GPOConfiguration.gpoName -or "Configure WinRM and PSRemoting")
$config.GPOConfiguration.adminHost = Get-UserInput -prompt "Enter admin host IP" -defaultValue ($config.GPOConfiguration.adminHost -or "127.0.0.1")
$config.GPOConfiguration.domainName = Get-UserInput -prompt "Enter domain name" -defaultValue ($config.GPOConfiguration.domainName -or "yourdomain.com")
$config.GPOConfiguration.targetOU = Get-UserInput -prompt "Enter target OU" -defaultValue ($config.GPOConfiguration.targetOU -or "OU=Hosts,DC=yourdomain,DC=com")

# Database Connection Configuration
$config.DatabaseConnection.dataBaseHost = Get-UserInput -prompt "Enter database host" -defaultValue ($config.DatabaseConnection.dataBaseHost -or "localhost")
$config.DatabaseConnection.dataBaseName = Get-UserInput -prompt "Enter database name" -defaultValue ($config.DatabaseConnection.dataBaseName -or "opshostguard")

# HTML Report Configuration
$config.HTMLReport.stdReportTitle = Get-UserInput -prompt "Enter standard report title" -defaultValue ($config.HTMLReport.stdReportTitle -or "Classroom Hosts Monitoring Report")
$config.HTMLReport.hardInventoryReportTitle = Get-UserInput -prompt "Enter hardware inventory report title" -defaultValue ($config.HTMLReport.hardInventoryReportTitle -or "Hardware Inventory Hosts Report")

# Email Notification Configuration
$config.EmailNotification.smtpServer = Get-UserInput -prompt "Enter SMTP server" -defaultValue ($config.EmailNotification.smtpServer -or "smtp.yourdomain.com")
$config.EmailNotification.from = Get-UserInput -prompt "Enter email from address" -defaultValue ($config.EmailNotification.from -or "admin@yourdomain.com")
$config.EmailNotification.to = Get-UserInput -prompt "Enter email to address" -defaultValue ($config.EmailNotification.to -or "recipient@yourdomain.com")
$config.EmailNotification.subject = Get-UserInput -prompt "Enter email subject" -defaultValue ($config.EmailNotification.subject -or "Daily Alerts")

# Save the configuration back to the JSON file
$config | ConvertTo-Json -Depth 5 | Set-Content -Path $configPath

if (-not $global:silentMode) {
    Add-LogMessage "Configuration saved Successfully to $configPath."
}
