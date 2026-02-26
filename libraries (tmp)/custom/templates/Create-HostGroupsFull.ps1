# Create-HostGroupsFull.ps1 [OpsHostGuard]

<#
    .SYNOPSIS
    Loads host groups from a JSON file, creates a supergroup combining all hosts except the "Debug" group, and saves the updated
    host groups to a new JSON file.

    .DESCRIPTION
    This script automates the process of loading host groups from a specified JSON file, creating a combined "supergroup" that
    includes all hosts except the ones in the "Debug" group, and then saving the updated groups to a new JSON file (`host_groups.json`).

    - The script first checks if the specified JSON file (`host_groups_template.json`) exists and attempts to load the host groups from it.
    - It converts the loaded JSON data into a hashtable for easier manipulation.
    - A "supergroup" is generated, combining all host groups except the "Debug" group, and this new group is added to the hashtable.
    - Finally, the updated hashtable, now including the supergroup, is saved to `host_groups.json`.

    .PARAMETERS
    - $hostGroupsFile: Specifies the path to the JSON file containing the host groups (`host_groups_template.json` by default).
    - $hostsGroupsHash: A hashtable that stores the host groups loaded from the JSON file and the new supergroup.

    .EXAMPLE
    This script loads host groups from a JSON file, creates a supergroup, and saves it.
    $hostGroupsFile = ".\host_groups_template.json"
    $hostsGroupsHash | ConvertTo-Json | Out-File "../config/host_groups.json"
    
    .NOTES
    - The script assumes that the JSON file (`host_groups_template.json`) exists in the same directory.
    - If the file is missing or cannot be loaded, an Error message will be displayed, and the script will terminate.
    - The resulting JSON file (`host_groups.json`) includes all original host groups and the newly created "supergroup".

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
    1.0 - Initial version.

    .USAGE
    This script is strictly for internal use within University of Extremadura.  
    The script is designed to operate within the IT infrastructure and environment of University of Extremadura 
    and may not function as expected in other environments.

    .DATE
    October 28, 2024 14:01

    .DISCLAIMER
    This script is provided "as-is" and is intended for internal use at University of Extremadura.  
    No warranties, express or implied, are provided. Any modifications or adaptations are not covered 
    under this disclaimer.

    .LINK
    https://github.com/n7rc/OpsHostGuard
#>


# Load host groups from JSON file
$hostGroupsFile = ".\host_groups_template.json"

# Check if the file exists
if (-not (Test-Path $hostGroupsFile)) {
    if (-not $global:silentMode) {
    Add-LogMessage "Error: The host groups file was not found at $hostGroupsFile." -ForegroundColor Red }
    exit 1
}

# Try to load the data from the JSON file
try {
    $hostsGroups = Get-Content $hostGroupsFile | ConvertFrom-Json
}
catch {
    if (-not $global:silentMode) {
    Add-LogMessage "Error: Unable to load the host groups from the JSON file." -ForegroundColor Red }
    exit 1
}

# Convert JSON object to a hashtable
$hostsGroupsHash = [PSCustomObject]@{}
$hostsGroups.psobject.Properties | ForEach-Object {
    $hostsGroupsHash[$_.Name] = $_.Value
}

# Combine all hosts into a supergroup, excluding the "Debug" group
$superGroup = @()
foreach ($GroupNameroup in $hostsGroupsHash.Keys) {
    if ($GroupNameroup -ne "Debug") {
        $superGroup += $hostsGroupsHash[$group]
    }
}

# Add the supergroup to the hashtable
$hostsGroupsHash["all"] = $superGroup

# Output the new groups with the supergroup
$hostsGroupsHash | ConvertTo-Json | Out-File "../config/host_groups.json"

if (-not $global:silentMode) {
    Add-LogMessage "SuperGroup (excluding 'Debug') added Successfully to the host groups."
}