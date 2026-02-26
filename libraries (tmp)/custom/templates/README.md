# Templates for OpsHostGuard

This directory contains scripts and JSON templates for configuring host groups and supergroups in the OpsHostGuard project. The scripts automate the process of creating a "supergroup" that combines all hosts, excluding those in the "Debug" group, and save the results in complete JSON files for use in other parts of the project.

## Contents

### Scripts

#### 1. `Create-HostGroupsFull.ps1`

- **Description**: 
  This script loads host groups from the JSON file `host_groups_template.json`, creates a "supergroup" that includes all hosts except those in the "Debug" group, and saves the updated groups to a new JSON file, `host_groups.json`.
  
- **Parameters**:
  - `$hostGroupsFile`: Specifies the path to the JSON file containing the host groups (default: `host_groups_template.json`).
  - `$hostsGroupsHash`: A hashtable that stores the host groups loaded from the JSON file and the new supergroup.
  
- **Usage Example**:
  ```powershell
  $hostGroupsFile = ".\host_groups_template.json"
  .\Create-HostGroupsFull.ps1
Notes:
The script assumes that host_groups_template.json exists in the same directory.
If the file is missing or cannot be loaded, an Error message will be displayed, and the script will terminate.
The resulting JSON file, host_groups.json, includes all original host groups and the newly created "supergroup".
2. Create-HostMACFull.ps1
Description: Similar to the previous script, this one loads host groups with their MAC addresses from hosts_mac_template.json, creates a "supergroup" excluding the "Debug" group, and saves the result in hosts_mac_full.json.

Parameters:

$hostGroupsFile: Specifies the path to the JSON file containing the host groups and MAC addresses (default: hosts_mac_template.json).
$hostsGroupsHash: A hashtable that stores the host groups loaded from the JSON file and the new supergroup.
Usage Example:

powershell
Copiar código
$hostGroupsFile = ".\hosts_mac_template.json"
.\Create-HostMACFull.ps1
Notes:

Requires hosts_mac_template.json to be present in the directory.
If the file does not exist or cannot be loaded, an Error message will be displayed, and the script will terminate.
The generated file, hosts_mac_full.json, contains all original host groups and the "supergroup" of hosts and MAC addresses.
JSON Templates
1. host_groups_template.json
This JSON file serves as a template to define host groups in the project. The groups defined here are loaded by Create-HostGroupsFull.ps1 to generate the full host_groups.json file with the "supergroup".

2. hosts_mac_template.json
This JSON file is a template that includes host groups with their respective MAC addresses. Create-HostMACFull.ps1 uses this template to generate hosts_mac_full.json, which includes the "supergroup" with all host MAC addresses.

Usage
Ensure that host_groups_template.json and/or hosts_mac_template.json are present in the directory.
Run the appropriate script (Create-HostGroupsFull.ps1 or Create-HostMACFull.ps1) as needed.
The scripts will generate full JSON files (host_groups.json and/or hosts_mac_full.json) in the config folder.
Security Notes
This directory and its scripts are intended for internal use within the Faculty of Documentation and Communication Sciences at the University of Extremadura. Modifications or usage in other environments may not function as expected.

Author
Developed by Alberto Ledo, with assistance from OpenAI.

perl
Copiar código

This `README.md` provides a clean, structured explanation in Markdown format for the conten