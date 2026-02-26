# OpsDataTemplate.psm1 [OpsHostGuard - Data Templates Module]

<#
    .SYNOPSIS
    Module for defining and initializing standardized data templates in OpsHostGuard.

    .DESCRIPTION
    The OpsDataTemplate module centralizes the creation and management of data structures used throughout OpsHostGuard.
    By aligning closely with the application's database schema, this module ensures consistency, maintainability, 
    and interoperability for both data processing and external integrations.

    Central features include:
    - Initialization of host-specific metrics, availability, hardware inventory, and scan history templates.
    - Aggregated group metrics for reporting and analysis.
    - Seamless integration with both the database and potential REST API endpoints.

    .FUNCTIONS
    - `Initialize-HostMetricsTemplate`: Defines the data structure for individual host metrics and statuses.
    - `Initialize-HostGroupMetricsTemplate`: Creates a structure for aggregated group metrics.
    - `Initialize-HostsAvailabilityTemplate`: Defines the template for tracking host availability and downtime.
    - `Initialize-HardwareInventoryTemplate`: Initializes the structure for host hardware inventory details.
    - `Initialize-OpsScanHistoryTemplate`: Sets up the template for logging scan history metadata.

    .EXAMPLES
    $hostMetrics = Initialize-HostMetricsTemplate -HostName "Host1"
    $groupMetrics = Initialize-HostGroupMetricsTemplate
    $availabilityTemplate = Initialize-HostsAvailabilityTemplate -HostName "Host1"
    $hardwareInventory = Initialize-HardwareInventoryTemplate -HostName "Host1"
    $scanHistory = Initialize-OpsScanHistoryTemplate -scanId 1234

    .NOTES
    This module acts as the backbone for data consistency within OpsHostGuard. Its templates are tailored to align 
    with the application's database schema and are prepared for future expansion, including potential REST API usage.

    .ORGANIZATION
    Faculty of Documentation and Communication Sciences, University of Extremadura.

    .AUTHOR [© 2024 Alberto Ledo]
    Alberto Ledo, Faculty of Documentation and Communication Sciences, with support from OpenAI.
    IT Department: University of Extremadura - IT Services for Facilities.
    Contact: albertoledo@unex.es

    .VERSION
    2.0.0

    .HISTORY
    2.0.0 - Updated to align with restructured database schema. Segmented data structures for modularity.
    1.0.0 - Initial release of data templates for OpsHostGuard.

    .DATE
    November 16, 2024

    .DISCLAIMER
    Provided "as-is" for internal University of Extremadura use. No warranties, express or implied. Modifications are not covered.

    .LINK
    https://github.com/n7rc/OpsHostGuard
#>



function Initialize-HostMetricsTemplate {
    param (
        [string]$HostName
    )
    return @{
        host_name             = $HostName
        cpu_usage             = $null
        ram_usage             = $null
        disk1_usage           = $null
        disk2_usage           = $null
        disk3_usage           = $null
        timestamp             = $null
        update_names          = $null
        update_status         = $null
        session_active        = $false
        session_name          = 'N/A'
        shutdown_status       = "NULL"
        power_on_failure_time = $null
        shutdown_failure_time = $null
        boot_time             = $null
        ip_address            = "NULL"
        mac_address           = "NULL"
        last_update_time      = $null
        last_session_user     = "N/A"
        uptime                = $null
        pending_reboot        = $false
        disk_health_status    = "Healthy"
        script_version        = "NULL"
        admin_comments        = "NULL"
        inventory_datestamp   = $null
    }
}

function Initialize-HostGroupMetricsTemplate {
    return @{
        total_hosts                 = 0
        failed_hosts_count          = 0
        failed_percentage           = 0.0
        total_updates_installed     = 0
        total_critical_logs         = 0
        total_Error_logs            = 0
        total_active_sessions       = 0
        total_hosts_shutdown_failed = 0
        overall_status              = "NULL"
    }
}

function Initialize-HostsAvailabilityTemplate {
    param (
        [string]$HostName
    )
    return @{
        host_name           = $HostName
        availability_status = "Offline"
        last_seen           = $null
        downtime_duration   = 0
    }
}

function Initialize-HardwareInventoryTemplate {
    param (
        [string]$HostName
    )
    return @{
        host_name         = $HostName
        cpu_model         = "NULL"
        cpu_cores         = $null
        ram_capacity_gb   = $null
        network_adapter   = "NULL"
        mac_adapter       = "NULL"
        motherboard       = "NULL"
        bios_version      = "NULL"
        bios_release_date = $null
        os_caption        = "NULL"
        os_build_number   = "NULL"
        gpu_model         = "NULL"
        gpu_driver_version = "NULL"
        inventory_datestamp = $null
    }
}

function Initialize-OpsScanHistoryTemplate {
    param (
        [int]$scanId
    )
    return @{
        scan_id   = $scanId
        scan_type = "Scheduled"
        start_time = $null
        end_time  = $null
        status    = "Pending"
    }
}

Export-ModuleMember -Function Initialize-HostMetricsTemplate, Initialize-HostGroupMetricsTemplate, Initialize-HostsAvailabilityTemplate, Initialize-HardwareInventoryTemplate, `
                              Initialize-OpsScanHistoryTemplate

