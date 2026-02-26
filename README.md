<span style="font-size: 36px;">OpsHostGuard Project</span>

***

**SYNOPSIS**

Automates the daily management of Windows hosts, including power-on, shutdown, system load monitoring, session detection, event log capture, mandatory updates, hardware inventory collection, and generating reports in HTML, CSV, and SQL queries for database . Also supports email notifications to the system administrator and now includes automated credential management.

***

**DESCRIPTION**

This script automates several key administrative tasks for managing a group of Windows hosts, while also incorporating user logon functionality for secured access to the dashboard. Additionally, the script now supports secure credential storage for PSRemoting, database access,  and dashboard access, leveraging the `createCredentials` script for automated credential creation and encryption.

**1. \*\*Logon Management:\*\***

\- Ensures users are authenticated before accessing the dashboard by verifying Credentials via \`AuthController.php\`.

\- Handles session creation, validation, and automatic redirection on logon Success or failure.

\- Displays an Error message and redirects to the login page (\`login.php\`) if Credentials are incorrect.

**2. \*\*Host Management:\*\***

\- Powers on hosts from a specified group (default: "all").

\- Monitors CPU, memory, and disk usage for the powered-on hosts, including alerts when usage exceeds 80%.

\- Detects active user sessions on the hosts.

\- Attempts to shut down hosts that have no active sessions.

**3. \*\*Updates and Event Logs:\*\***

\- Automatically installs updates on Successfully powered-on hosts:

&nbsp;   - If \`-UpdateHosts\` is not specified, updates are installed using internal Windows commands (beta).

&nbsp;   - If \`-UpdateHosts\` is set to \`psupdate\`, updates are installed using the PSWindowsUpdate module.

\- Captures critical events (Level 1) from System and Setup logs, and Error events (Level 2) from Application logs from the last 7 days.

**4. \*\*Reports and Notifications:\*\***

\- Uses stored credentials for remote operations, including PowerShell remoting and Windows Update management.

\- Generates comprehensive reports in HTML with print preview and PDF export functionalities.

\- Exports host metrics, hardware inventory, and summary data to CSV and log files for easy data tracking and sharing.

\- Prepares SQL queries for host metrics, hardware details, and summary data, enabling easy database  for further analysis.

\- Sends email notifications to the system administrator, summarizing the results of the daily operations, including power-on and shutdown status, system resource usage, update results, and hardware inventory.

**5. \*\*Credential Management:\*\***

\- Integrates secure credential storage for PSRemoting, database access, and dashboard access by utilizing `Create-Credentials.ps1`.

\- `Create-Credentials.ps1` securely collects user credentials, encrypts them with PowerShell's Export-Clixml, and stores them as XML files.

\- Credentials are stored as SecureStrings to ensure encryption and security during retrieval, accessed in scripts using the `Import-Clixml` method.
    
**6. \*\*Historical Hardware Inventory Tracking:\*\*** 

\- The hardware inventory for each host is stored in the `hardware_inventory` table with a unique `inventory_datestamp` column.

\- Each `host_metrics` record includes an `inventory_datestamp` reference, linking performance metrics to a specific hardware configuration.

\- Allows tracking of changes in hardware over time, providing insights into how hardware modifications impact host performance.

***

**EXAMPLES:**
```powershell
.\\OpsScan.ps1 -GroupName "all" -UpdateHosts "psupdate" 
```
```powershell
.\\OpsScan.ps1 -GroupName "administration" -csvFilePathHosts "./dashboard/data/csv/host_metrics.csv"
```
```powershell
.\\OpsScan.ps1 -GroupName "labs" -Verbose
```

**RECOMMENDED EXAMPLE:**
```powershell
.\\OpsScan.ps1 -GroupName all -UpdateHosts psupdate -Inventory -Verbose
```
This example manages all hosts in the "all" group by powering them on, checking for active sessions, monitoring system load, performing updates with the PSWindowsUpdate module, and running a comprehensive hardware inventory check.

***

**PARAMETERS:**

\#PARAMETER **-g**

Specifies the group of hosts to manage. The default value is "all."

\#PARAMETER **-UpdateHosts \["psupdate", ""\]**

If specified with the value psupdate or not specified -UpdateHosts, the script will install updates using the PSWindowsUpdate module.

If specified -UpdateHosts "", updates will be installed using internal Windows commands.

\#PARAMETER **-Inventory**

Enables Inventory Mode, allowing the script to perform a comprehensive hardware inventory check for each host. When this parameter is set, the script collects detailed Information on hardware components, including CPU, RAM, network adapters, BIOS, motherboard, and storage devices. This mode is designed for tracking hardware configurations over time, making it ideal for historical hardware auditing and asset management.

\#PARAMETER **-config**

Activates the dynamic generation or update of a PHP configuration file, used by the application's dashboard.
   
\#PARAMETER **-Verbose**

Enables Debug mode, displaying detailed logs and messages for troubleshooting.

***

**\NOTES:**

\- Requires administrative privileges to perform certain remote operations.

\- PowerShell remoting must be enabled on target hosts for remote execution.

\- Uses stored credentials loaded from an XML file for remote authentication and execution.

\- Uses stored credentials loaded from an XML file for dashboard access authentication.

\- The PSWindowsUpdate module should be installed on target hosts if using the -UpdateHosts psupdate option. The script installs it by default if -UpdateHosts psupdate is selected.

\- Monitors system resource usage and flags hosts exceeding 70% CPU, RAM, or Disk usage.

\- Captures critical (Level 1) and Error (Level 2) events from the System, Setup, and Application logs.

\- Collects hardware inventory, including details such as CPU, Network Adapter, Motherboard, BIOS, OS, and GPU Information.

\- Generates reports in HTML with print preview and PDF export functionalities, and exports host data to CSV, log, and SQL formats.

\- Sends an email notification to the system administrator with a summary of the daily checks, logs, update results, and hardware inventory.

\- The scripts \`ActiveSessions.psm1\`, \`Start-Hosts.ps1\`, and \`Stop-Hosts.ps1\` are auxiliary scripts for the main module, but they can be used independently by passing the corresponding parameters in each script. These scripts are self-documented.

\- Other auxiliary scripts accompany the application, which, while part of its workflow, can be used separately. They are located in the \`bin\` folder and include: \`Get-Events.ps1\`, \`HostsLoad.ps1\`, and \`Test-HostStatus.ps1\`. These scripts are self-documented.

***

**ORGANIZATION:**

Developed for: **Faculty of Documentation and Communication Sciences at the University of Extremadura.**


**AUTHOR:**

Alberto Ledo \[Faculty of Documentation and Communication Sciences\] - with assistance from OpenAI  

IT Department: University of Extremadura - IT Services for Facilities  

Contact: <albertoledo@unex.es>

***

**VERSION:**

2.3.1

**HISTORY:**

1.0.0 - Initial version by Alberto Ledo.

1.1.0 - Added email reporting for power-on, shutdown, and session detection.

1.2.0 - Introduced the \`-UpdateHosts\` parameter for optional host update functionality.

1.3.0 - Integrated the \`-g\` parameter for specifying host groups, with "all" as default.

1.4.0 - Added the use of stored credentials for remote operations and enhanced logging features.

1.5.0 - Included host load monitoring (CPU, RAM, Disk) and resource usage alerts in email reports.

1.6.0 - Integrated the PSWindowsUpdate module for host updates based on the \`-UpdateHosts\` parameter.

1.7.0 - Added the retrieval of active session details on hosts.

1.8.0 - Added critical and Error log capture from System, Setup, and Application logs.

1.9.0 - Introduced HTML report generation with print preview and PDF export functionality.

2.0.0 - Added CSV and log export for host and summary data, and generated SQL queries for database .

2.1.0 - Added hardware inventory functionality, including CPU, Network Adapter, Motherboard, BIOS, OS, and GPU collection.

2.2.0 - Added user logon functionality for secured access control to the dashboard.

2.2.1 - Modified Stop-Hosts to return more Information.

2.3.0 - Integrated secure credential storage for database and dashboard access using `Create-Credentials.ps1`.

2.3.1 - Introduced historical tracking for hardware inventory in host metrics with `inventory_datestamp`.

2.3.2 - Added the dynamic generation or update of a PHP configuration file. Incorporation of powershell modules:
       `OpsHostGuardGlobalConfig` and `OpsHostGuardConfigPhp`


***

**USAGE:**

This script is strictly for internal use within University of Extremadura.  

The script is designed to operate within the IT infrastructure and environment of University of Extremadura and may not function as expected in other environments.


**DATE:**

October 28, 2024 11:24


**DISCLAIMER:**

This script is provided "as-is" and is intended for use at Faculty of Documentation and Communication Sciences at the University of Extremadura. No warranties, express or implied, are provided. Any modifications or adaptations are not covered under this disclaimer.