function New-HostMetrics {
    param (
        [hashtable]$hostsData,
        [array]$activeSessionsLogs,
        [bool]$generateInventory,
        [array]$successfulHosts
    )

    $preparedMetrics = @()
    foreach ($HostName in $hostsData.Keys) {
        $hostData = $hostsData[$HostName]
        
        # Prepare sessionName
        $sessionName = if ($hostData.session_active -eq $true) {
            foreach ($log in $activeSessionsLogs) {
                if ($log.HostName -eq $HostName) {
                    if ([string]::IsNullOrEmpty($hostData.session_name)) { 
                        'N/A'
                    }
                    else { 
                        $(($log.Status -replace 'Host in Session \[ ', '') -replace ']', ',')
                    }
                }
            } -join ','
        } else {
            "NULL"
        }

        $preparedMetrics += @{
            HostName         = $HostName
            CpuUsage         = $hostData.cpu_usage
            RamUsage         = $hostData.ram_usage
            DiskUsage        = @($hostData.disk1_usage, $hostData.disk2_usage, $hostData.disk3_usage)
            SessionActive    = $hostData.session_active
            SessionName      = $sessionName
            InventoryDatestamp = if ($successfulHosts -contains $HostName) { 
                if ($generateInventory) { "NOW()" } else { "NULL" }
            } else {
                "NULL"
            }
        }
    }
    return $preparedMetrics
}