# Create a new GPO to configure WinRM and PSRemoting
$gpoName = "Configure WinRM and PSRemoting"
$gpo = Get-GPO -Name $gpoName -ErrorAction SilentlyContinue
if (-not $gpo) {
    if (-not $global:silentMode) {
    Add-LogMessage "Creating new GPO: $gpoName"
}
    $gpo = New-GPO -Name $gpoName -Domain "fcdyc.unex.es" -Comment "Enable WinRM"
} else {
    if (-not $global:silentMode) {
    Add-LogMessage "Modifying existing GPO: $gpoName"
}
}

# Link the GPO to the appropriate OU (specify the OU containing the servers/hosts)
New-GPLink -Name $gpoName -Target "DC=fcdyc,DC=unex,DC=es"

# Configure WinRM to enable Kerberos and PSRemoting

# Enable Kerberos authentication for WinRM
$gpo | Set-GPRegistryValue -Key "HKLM\Software\Policies\Microsoft\Windows\RemoteManagement\WinRM\Service\Auth" `
    -ValueName "Kerberos" -Type DWORD -Value 1

Set-GPRegistryValue -Name $gpoName -Key "HKLM\SOFTWARE\Policies\Microsoft\Windows\WinRM\Service" -ValueName "Auth_AllowKerberos" -Type DWORD -Value 1

# Configure PSRemoting and allow automatic configuration of WinRM
$gpo | Set-GPRegistryValue -Key "HKLM\Software\Policies\Microsoft\Windows\RemoteManagement\WinRM\Service" `
    -ValueName "AllowAutoConfig" -Type DWORD -Value 1

$gpo | Set-GPRegistryValue -Key "HKLM\Software\Policies\Microsoft\Windows\RemoteManagement\WinRM\Service" `
    -ValueName "EnableCompatibilityHttpListener" -Type DWORD -Value 1

# Enable WinRM on the client side (allow remote connections)
$gpo | Set-GPRegistryValue -Key "HKLM\Software\Policies\Microsoft\Windows\RemoteManagement\WinRM\Service" `
    -ValueName "AllowUnencrypted" -Type DWORD -Value 0
$gpo | Set-GPRegistryValue -Key "HKLM\Software\Policies\Microsoft\Windows\RemoteManagement\WinRM\Service" `
    -ValueName "EnableCompatibilityHttpListener" -Type DWORD -Value 1

# Firewall of WinRM ONLY from client (10.254.73.15)
Set-GPRegistryValue -Name $gpoName -Key "HKLM\SOFTWARE\Policies\Microsoft\Windows\WinRM\Service" -ValueName "IPv4Filter" -Type String -Value "10.254.73.15"

# Firewall configuration to allow WinRM ONLY from the administrator client (10.254.73.15)
# Open ports 5985 (HTTP) and 5986 (HTTPS) for IPv4 connections from 10.254.73.15
$firewallInboundRule = [PSCustomObject]@{
    Name        = "WinRM Inbound Rule for 10.254.73.15 (IPv4)"
    Enabled     = $true
    Profile     = "Domain"
    Direction   = "Inbound"
    Action      = "Allow"
    LocalPort   = 5985, 5986
    Protocol    = "TCP"
    RemoteAddress = "10.254.73.15"  # Only allow connections from client 10.254.73.15
    InterfaceType = "Any"
}
$gpo | Set-GPRegistryValue -Key "HKLM\SYSTEM\CurrentControlSet\Services\SharedAccess\Parameters\FirewallPolicy\DomainProfile\GloballyOpenPorts\List" `
    -ValueName "5985:TCP" -Type String -Value "5985:TCP:10.254.73.15:Enabled:WinRM HTTP from IPv4"
$gpo | Set-GPRegistryValue -Key "HKLM\SYSTEM\CurrentControlSet\Services\SharedAccess\Parameters\FirewallPolicy\DomainProfile\GloballyOpenPorts\List" `
    -ValueName "5986:TCP" -Type String -Value "5986:TCP:10.254.73.15:Enabled:WinRM HTTPS from IPv4"

# Ensure only IPv4 is used (disable IPv6) [Sin embargo en ListeningOn de los hosts es null. Otra GPO está sobreescribiendo la regla]
$gpo | Set-GPRegistryValue -Key "HKLM\SYSTEM\CurrentControlSet\Services\SharedAccess\Parameters\FirewallPolicy\DomainProfile\GloballyOpenPorts\List" `
    -ValueName "LocalOnlyMapping" -Type DWORD -Value 1
$gpo | Set-GPRegistryValue -Key "HKLM\SYSTEM\CurrentControlSet\Services\SharedAccess\Parameters\FirewallPolicy\DomainProfile\GloballyOpenPorts\List" `
    -ValueName "LocalAddress" -Type String -Value "0.0.0.0/0"

# Configure dynamic RPC ports for WinRM

# Open dynamic ports 49152-65535 for RPC, only for client 10.254.73.15 (IPv4)
$gpo | Set-GPRegistryValue -Key "HKLM\SYSTEM\CurrentControlSet\Services\SharedAccess\Parameters\FirewallPolicy\DomainProfile\GloballyOpenPorts\List" `
    -ValueName "49152-65535:TCP" -Type String -Value "49152-65535:TCP:10.254.73.15:Enabled:Dynamic RPC IPv4"

# Reduce dynamic RPC port range on the servers

# Limit the dynamic RPC port range to 60000-60100 for increased security
$gpo | Set-GPRegistryValue -Key "HKLM\Software\Microsoft\Rpc" `
    -ValueName "InternetAvailableServerPorts" -Type MultiString -Value "60000-60100"

# 5. (Optional) Additional rules to restrict connections to IPv4 only

# Set PowerShell execution policy to "RemoteSigned"
Set-GPRegistryValue -Name $gpoName -Key "HKLM\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ExecutionPolicy" -ValueName "ExecutionPolicy" -Type String -Value "RemoteSigned"

# Additional WinRM Listener configurations
Set-GPRegistryValue -Name $gpoName -Key "HKLM\SOFTWARE\Policies\Microsoft\Windows\WinRM\Service\Listener" -ValueName "Transport" -Type String -Value "HTTP"
Set-GPRegistryValue -Name $gpoName -Key "HKLM\SOFTWARE\Policies\Microsoft\Windows\WinRM\Service\Listener" -ValueName "Address" -Type String -Value "0.0.0.0"
Set-GPRegistryValue -Name $gpoName -Key "HKLM\SOFTWARE\Policies\Microsoft\Windows\WinRM\Service\Listener" -ValueName "Port" -Type DWORD -Value 5985

# Force deployment on all domain computers
#Invoke-GPUpdate -All

# Sync sysvol across Samba domain controllers (Optional) (10.10.10.5 and 10.10.10.7)
# rsync -avz /var/lib/samba/sysvol/ <secondary_server>:/var/lib/samba/sysvol/
