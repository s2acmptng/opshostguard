# OpsAux.psm1 [OpsHostGuard - Auxiliar functions Configuration Module]

<#
    .SYNOPSIS


    .ORGANIZATION
    Faculty of Documentation and Communication Sciences, University of Extremadura.

    .AUTHOR [© 2024 Alberto Ledo] [© 2024 Alberto Ledo]
    Alberto Ledo, Faculty of Documentation and Communication Sciences, with support from OpenAI.
    IT Department: University of Extremadura - IT Services for Facilities.
    Contact: albertoledo@unex.es

    .VERSION
    1.0.0

    .HISTORY
   
    1.0.0 - Initial release

    .DATE
    November 21, 2024

    .DISCLAIMER
    Provided "as-is" for internal University of Extremadura use. No warranties, express or implied. Modifications are not covered.

    .LINK
    https://github.com/n7rc/OpsHostGuard
#>

<# Function: Resolve-PowerOn
.SYNOPSIS
Processes and categorizes the results of power-on operations for a list of hosts.
.DESCRIPTION
This function evaluates the power-on results for a list of hosts, separating them into successful and failed categories. 
For each host, it checks the `Status` field to determine if the operation succeeded or failed, logs the outcome, and 
returns two categorized lists:
- Failed hosts with details about the failure.
- Successfully powered-on hosts with their details.
The function also associates each result with a timestamp for tracking purposes and logs all actions for debugging 
and traceability.
.PARAMETER powerOnResult
An array of objects representing the power-on results for hosts. Each object should include:
- `Name`: The hostname.
- `Status`: The status of the power-on operation (e.g., "Success", "Failed").
.PARAMETER timestamp
A timestamp to associate with each result. This is useful for tracking the timing of operations.
.OUTPUTS
Returns an array containing two sub-arrays:
1. Failed hosts as custom objects, each with:
   - `HostName`: The name of the host.
   - `Timestamp`: The associated timestamp.
   - `Status`: A description of the failure.
2. Successful hosts as custom objects, each with:
   - `HostName`: The name of the host.
   - `Timestamp`: The associated timestamp.
   - `Status`: A description of the success.
.EXAMPLE
Process power-on results for a group of hosts:
$results = Resolve-PowerOn -powerOnResult $hostPowerResults -timestamp (Get-Date)
.EXAMPLE
Log and categorize power-on results with detailed logs:
$failed, $successful = Resolve-PowerOn -powerOnResult $powerOnArray -timestamp "2024-11-21"
.NOTES
- This function logs each operation, including successes and failures, to the configured logging System.
- Any exceptions encountered during processing are logged as errors, and empty arrays are returned in case of failure.
- Designed for integration into workflows where power-on results need categorization and logging for reporting or further analysis.
.LINK
OpsHostGuard Documentation: https://github.com/n7rc/OpsHostGuard
#>
function Resolve-PowerOn {
    param (
        [array]$powerOnResult,  # Array of power-on results for hosts
        [string]$timestamp      # Timestamp to associate with the results
    )
    
    # Initialize arrays to store failed and successful hosts
    $failedHosts = @()
    $successfulHosts = @()

    # Log the start of the function execution
    Add-LogMessage -functionName $MyInvocation.InvocationName `
        -message "Processing power-on results for group '$GroupName'." `
        -logLevel "Debug"

    try {
        # Iterate through the power-on results
        foreach ($hostEntry in $powerOnResult) {
            if ($hostEntry.Status -ne "Success") {
                # Log failed host details
                Add-LogMessage -functionName $MyInvocation.InvocationName `
                    -message "Power-on failed for host: $($hostEntry.Name)." `
                    -logLevel "Warning"

                # Add failed host details to the failedHosts array
                $failedHosts += [PSCustomObject]@{
                    HostName  = $hostEntry.Name
                    Timestamp = $timestamp
                    Status    = "Power-on Failed"
                }
            }
            else {
                # Log successful host details
                Add-LogMessage -functionName $MyInvocation.InvocationName `
                    -message "Power-on succeeded for host: $($hostEntry.Name)." `
                    -logLevel "Info"

                # Add successful host details to the successfulHosts array
                $successfulHosts += [PSCustomObject]@{
                    HostName  = $hostEntry.Name
                    Timestamp = $timestamp
                    Status    = "Powered On"
                }
            }
        }
        # Return the arrays of failed and successful hosts
        return @($failedHosts, $successfulHosts)
    }
    catch {
        # Log any exceptions that occur during processing
        Add-LogMessage -functionName $MyInvocation.InvocationName `
            -message "Error processing power-on results: $($_.Exception.Message)." `
            -logLevel "Error"

        # Return empty arrays in case of failure
        return @(@(), @())
    }
}

<#
Function: Export-UpdateResults
.SYNOPSIS
Exports and displays the results of update and verification processes for hosts.
.DESCRIPTION
This function processes the results of update and verification operations stored in a `PSCustomObject` 
and displays them in a formatted table. It categorizes entries into updates applied and updates verified. 
If no updates or verifications are recorded, a warning is logged. This function is intended for use as a 
reporting utility for update management workflows.
.PARAMETER resultUpdate
A `PSCustomObject` containing:
- `UpdateLogEntries`: An array of update results, each including `HostName`, `Status`, and `Update` information.
- `VerificationUpdateEntries`: An array of verification results, each including `HostName`, `Result`, and `Status` information.
.OUTPUTS
Displays formatted tables to the console for:
- Applied updates, showing `HostName`, `Purpose` (always "Applied"), `Status`, and `Update`.
- Verified updates, showing `HostName`, `Purpose` (always "Verified"), `Result`, and `Status`.
- Logs warnings if no updates or verifications are available.
.EXAMPLE
Export results of updates and verifications:
Export-UpdateResults -resultUpdate $updateResults
# Displays formatted tables of applied and verified updates and logs any warnings if no entries exist.
.NOTES
- The `resultUpdate` parameter must be a properly structured `PSCustomObject` with `UpdateLogEntries` 
  and `VerificationUpdateEntries` properties.
- Logs all actions, including warnings for missing entries, to the configured logging System.
- Designed for use in conjunction with update management functions in OpsHostGuard.
#>

function Export-UpdateResults {
    param (
        [PSCustomObject]$resultUpdate
    )

    try {
        # Log the start of the function
        Add-LogMessage -functionName $MyInvocation.InvocationName `
            -message "Export-UpdateResults called." `
            -logLevel "Debug"

        # Ensure global configuration is initialized
        if (-not $Global:Config) {
            Add-LogMessage -functionName $MyInvocation.InvocationName `
                -message "Global configuration is not initialized. Aborting operation." `
                -logLevel "Error"
            return
        }

        # Verify UpdateLogEntries exist and are valid
        if ($resultUpdate.UpdateLogEntries.Count -gt 0) {
            Add-LogMessage -functionName $MyInvocation.InvocationName `
                -message "Processing update log entries." `
                -logLevel "Info"

            # Display updates applied
            $resultUpdate.UpdateLogEntries |
            Select-Object HostName, @{Name = "Purpose"; Expression = { "Applied" } }, Status, Update |
            Format-Table -AutoSize
        }

        # Verify VerificationUpdateEntries exist and are valid
        if ($resultUpdate.VerificationUpdateEntries.Count -gt 0) {
            Add-LogMessage -functionName $MyInvocation.InvocationName `
                -message "Processing verification update entries." `
                -logLevel "Info"

            # Display verified updates
            $resultUpdate.VerificationUpdateEntries |
            Select-Object HostName, @{Name = "Purpose"; Expression = { "Verified" } }, Result, Status |
            Format-Table -AutoSize
        }

        # Log and handle cases where no updates or verifications occurred
        if (($resultUpdate.UpdateLogEntries.Count -eq 0) -and ($resultUpdate.VerificationUpdateEntries.Count -eq 0)) {
            Add-LogMessage -functionName $MyInvocation.InvocationName `
                -message "No updates or verifications were performed." `
                -logLevel "Warning"
        }

        # Store the results in the global configuration under the group name for reference
        $Global:Config.Groups.resultGroup = [PSCustomObject]@{
            UpdateLogEntries = $resultUpdate.UpdateLogEntries
            VerificationUpdateEntries = $resultUpdate.VerificationUpdateEntries
        }

        # Log the successful storage of results
        Add-LogMessage -functionName $MyInvocation.InvocationName `
            -message "Results successfully stored in global configuration." `
            -logLevel "Success"
    }
    catch {
        # Log any exceptions
        Add-LogMessage -functionName $MyInvocation.InvocationName `
            -message "Error exporting update results: $($_.Exception.Message)" `
            -logLevel "Error"
    }
}

Export-ModuleMember -Function Resolve-PowerOn, Export-UpdateResults
