# Schedule-OpsHostGuard.ps1 [OpsHostGuard]

<#
    .SYNOPSIS
    Schedules a task to run the PowerShell script `OpsScan.ps1` daily at 7:00 AM.

    .DESCRIPTION
    This script uses PowerShell to create a scheduled task named "OpsHostGuard" that triggers the execution of the 
    `OpsScan.ps1` script every day at 7:00 AM. The `OpsScan.ps1` script performs a series of daily checks 
    on hosts, including system load monitoring, updates, session detection, and other administrative tasks.

    The scheduled task is configured to:
    - Run the `OpsScan.ps1` script via PowerShell daily at 7:00 AM.
    - Optionally, Invoke the script with additional arguments to install updates.

    .PARAMETERS
    - $action: Defines the action to Invoke `PowerShell.exe` with the `OpsScan.ps1` script.
    - $trigger: Triggers the task daily at 7:00 AM.

    .EXAMPLE
    # This command registers the scheduled task to run OpsScan.ps1 every day at 7:00 AM.
    Register-ScheduledTask -Action $action -Trigger $trigger -TaskName "OpsHostGuard" -Description "Runs OpsScan.ps1 daily at 7:00 AM"

    .NOTES
    - The script assumes that the `OpsScan.ps1` script is located in the current directory.
    - Ensure the `OpsScan.ps1` script is properly configured for daily checks and operations.
    - The task can optionally be configured to install updates by uncommenting the alternative action.

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
    October 28, 2024 14:06

    .DISCLAIMER
    This script is provided "as-is" and is intended for internal use at University of Extremadura. 
    No warranties, express or implied, are provided. Any modifications or adaptations are not covered 
    under this disclaimer.

    .LINK
    https://github.com/n7rc/OpsHostGuard
    https://n7rc.gitbook.io/
#>

$action = New-ScheduledTaskAction -Invoke 'PowerShell.exe' -Argument '-File ".\OpsScan.ps1" -GroupName all -Verbose -UpdateHosts psupdate -Inventory'

$trigger = New-ScheduledTaskTrigger -Daily -At 7:00AM

Register-ScheduledTask -Action $action -Trigger $trigger -TaskName "OpsHostGuard" -Description "Runs OpsScan.ps1 daily at 7:00 AM"