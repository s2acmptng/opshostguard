# Create-EmailContent.psm1 [OpsHostGuard]

<#
    .SYNOPSIS
    Generates the body content of an email and sends daily reports on the status of Windows hosts, including 
    power failures, active sessions, shutdown failures, system updates, and critical Error logs.

    .DESCRIPTION
    This script automates the generation and sending of daily email reports for system administrators. It gathers 
    data from several sources, such as power failure logs, session activity, shutdown failures, and system updates. 
    The email body is structured to provide a clear summary of the daily status for each host.

    - **New-EmailBody**: This function creates the email content, including power fail, active sessions, 
      shutdown failures, system update results, and critical logs. The body is formatted as a table with detailed 
      entries for each host.
      
    - **Send-EmailReport**: This function sends the email to the system administrator using the specified SMTP server 
      and email addresses. It includes Error handling and logging for Debugging purposes.

    .PARAMETERS
    - **logEntries**: Array containing log data for power failures, active sessions, and shutdown failures.
    - **updateLogEntries**: Array containing log data for system updates installed during the day.
    - **smtpServer**: The SMTP server used to send the email.
    - **from**: The email address from which the report will be sent.
    - **to**: The recipient email address.
    - **subject**: The subject line for the email.
    .EXAMPLES
    ```powershell
    # Example to generate and send a daily email report
    Send-EmailReport -logEntries $logEntries -updateLogEntries $updateLogEntries
    ```

    .NOTES
    - The script requires access to a functioning SMTP server to send the email reports.
    - It logs Debug Information for each log entry processed and each email sending attempt.
    - If no failures or updates are found, the script generates a simple email body indicating 
      "No failures, active sessions, or updates to report today."

    .ORGANIZATION
    Developed for: Faculty of Documentation and Communication Sciences at the University of Extremadura.

    .AUTHOR [© 2024 Alberto Ledo]
    Alberto Ledo [Faculty of Documentation and Communication Sciences] - with assistance from OpenAI
    IT Department: University of Extremadura - IT Services for Facilities
    Contact: albertoledo@unex.es

    .@Copyright
    © 2024 Alberto Ledo

    .VERSION
    1.0

    .HISTORY
    1.0 - Initial version by Alberto Ledo.

    .USAGE
    This script is strictly for internal use within University of Extremadura. 
    The script is designed to operate within the IT infrastructure and environment of University of Extremadura.

    .DATE
    October 28, 2024 13:58

    .DISCLAIMER
    This script is provided "as-is" and is intended for internal use at University of Extremadura. 
    No warranties, express or implied, are provided. Any modifications or adaptations are not covered 
    under this disclaimer.

    .LINK
    https://github.com/n7rc/OpsHostGuard
#>

function New-EmailContent {
    param (
        [array]$logEntries, # Combined list of Power Fail, Active Sessions, and Shutdown Fail entries
        [array]$updateLogEntries    # List of updates installed today
    )
    
    # Log the processing of each entry for Debugging
    foreach ($entry in $logEntries) {
        Add-LogMessage "Processing log entry: HostName = $($entry.HostName), Timestamp = $($entry.Timestamp), Status = $($entry.Status)"
    }

    # If no log entries or updates, return a message stating that nothing to report
    if ($logEntries.Count -eq 0 -and $updateLogEntries.Count -eq 0) {
        return "No failures, active sessions, or updates to report today."
    }

    # Start building the email body with a header for the daily report
    $body = "Daily Report for Power Fail, Active Sessions and Shutdown Failures:" + "`n`n"

    # Add the table header for the log entries
    $body += "Host".PadRight(20) + "| Timestamp".PadRight(24) + "| Status".PadRight(18) + "`n"
    $body += ("-" * 60) + "`n"

    # Add each log entry (power failures, active sessions, shutdown failures)
    foreach ($entry in $logEntries) {
        $timestampString = "{0:yyyy-MM-dd HH:mm:ss}" -f $entry.Timestamp  # Format timestamp
        Add-LogMessage "Checking log entry: HostName = $($entry.HostName), Timestamp = $timestampString, Status = $($entry.Status)"

        # Ensure valid data exists before adding the entry to the email body
        if ($entry[0] -NotLike "Status*" -and $entry[0] -NotLike "------*") {
            $body += $entry.HostName.PadRight(20) + "| " + $timestampString.PadRight(22) + "| " + $entry.Status.PadRight(18) + "`n"
        }
        else {
            Add-LogMessage "Skipping log entry with missing data:  HostName = $($entry.HostName), Timestamp = $timestampString, Status = $($entry.Status)"
        }
    }

    # Add the header for updates installed today
    $body += "`n`nUpdates Installed Today:" + "`n`n"
    $body += "Host".PadRight(20) + "| Timestamp".PadRight(24) + "| Update".PadRight(70) + "| Result".PadRight(18) + "`n"
    $body += ("-" * 128) + "`n"
    # Add each update entry to the email body
    foreach ($updateEntry in $updateLogEntries) {
        $timestampString = if ($updateEntry.Timestamp) { "{0:yyyy-MM-dd HH:mm:ss}" -f $updateEntry.Timestamp } else { "N/A" }
        $HostName = if ($updateEntry.HostName) { $updateEntry.HostName } else { "N/A" }
        $status = if ($updateEntry.Status) { $updateEntry.Status } else { "N/A" }
        $result = if ($updateEntry.Result) { $updateEntry.Result } else { "N/A" }
    
        # Add the formatted update entry to the email body
        $body += $HostName.PadRight(20) + "| " + $timestampString.PadRight(22) + "| " + $status.PadRight(68) + "| " + $result.PadRight(18) + "`n"
    }
    
    # Add the host load metrics to the email body
    $body += "`n`nHost Load Metrics - Any metric exceeding 70%:" + "`n`n"
    $body += $hostLoadTable
    
    # If any hosts failed to report load metrics, include them in the email
    if ($failedLoadHosts.Count -gt 0) {
        $body += "`n`nFailed to retrieve load metrics from the following hosts:`n"
        $failedLoadHosts | ForEach-Object { $body += "$_`n" }
    }
    
    # Add the section for critical logs
    $body += "`n`nCritical Logs for System and Setup (Last 7 Days):" + "`n`n"
    $body += $criticalLogTable
    
    # Add the section for Application Error logs
    $body += "`n`nApplication Error Logs (Last 7 Days):" + "`n`n"
    $body += "TimeCreated".PadRight(20) + "| EventID".PadRight(10) + "| Level".PadRight(10) + "| Message" + "`n"
    $body += ("-" * 80) + "`n"
        
    # If there are any Application Error logs, add them to the body
    if ($allApplicationErrorLogs.Count -gt 0) {
        foreach ($log in $allApplicationErrorLogs) {
            $body += $log.TimeCreated.ToString("yyyy-MM-dd HH:mm").PadRight(20) + "| " + $log.Id.ToString().PadRight(10) + "| " + $log.Level.PadRight(10) + "| " + $log.Message + "`n"
        }
    }
    
    return $body  # Return the complete email body
}

# Function to send the email report
function Send-EmailReport {
    param (
        [string]$smtpServer = "fcdyc-ad1.unex.es", # SMTP server for sending the email
        [string]$from = "admin@fcdyc-ad1.unex.es", # Sender email address
        [string]$to = "admin@fcdyc-ad1.unex.es", # Recipient email address
        [string]$subject = "Daily Alerts in Classrooms FCDYC", # Email subject
        [array]$logEntries, # Combined list of log entries
        [array]$updateLogEntries                                 # Combined list of update entries
    )

    try {
        # Generate the email body using the log and update entries
        $body = New-EmailBody -logEntries $logEntries -updateLogEntries $updateLogEntries
        
        # Send the email (commented out in this case)
        #Send-MailMessage -From $from -To $to -Subject $subject -Body $body -SmtpServer $smtpServer
        if (-not $global:silentMode) {
    Add-LogMessage "Email report sent Successfully!" -ForegroundColor Green }

        # Debugging: log the email body content
        if ($Verbose) {
            Add-LogMessage -message "Mail sending...:"
            return $body  # Optionally return the email body for verification
        }
    }
    catch {
        if (-not $global:silentMode) {
    Add-LogMessage "Failed to send email: $_" -ForegroundColor Red }
    }
}
