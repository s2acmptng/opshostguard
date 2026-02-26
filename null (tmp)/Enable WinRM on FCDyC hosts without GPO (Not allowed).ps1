# Crear una nueva GPO para WinRM
$gpoName = "Configurar WinRM y PSRemoting"
$gpo = New-GPO -Name $gpoName -Domain "fcdyc.unex.es" 

# Vincular la GPO a la OU de los clientes (cambiar por la OU correcta)
New-GPLink -Name $gpoName -Target "OU=Clientes,DC=fcdyc,DC=unex,DC=es"

# Habilitar WinRM en los clientes
$scriptBlock = @"
[CmdletBinding()]
param()
if (-not $global:silentMode) {
    Add-LogMessage "Habilitando WinRM en el cliente"
}
winrm quickconfig -force
Set-Item WSMan:\localhost\Service\Auth\Kerberos -Value $true
Enable-PSRemoting -Force -SkipNetworkProfileCheck
"@
$scriptBlock | Out-File -FilePath "C:\GPO-WinRM.ps1"

# Configurar la GPO para ejecutar el script de configuración de WinRM
$gpo | Set-GPRegistryValue -Key "HKLM\Software\Microsoft\Windows\CurrentVersion\Policies\System\Scripts\Startup" `
    -ValueName "GPO-WinRM" -Type String -Value "C:\GPO-WinRM.ps1"

# Abrir puertos necesarios para WinRM en el Firewall pero solo para el cliente 10.254.73.15 y usando IPv4
$winrmFirewallRule = [PSCustomObject]@{
    Name        = "Abrir puertos para WinRM solo para 10.254.73.15"
    Enabled     = $true
    Profile     = "Domain"
    Direction   = "Inbound"
    Action      = "Allow"
    LocalPort   = 5985, 5986
    Protocol    = "TCP"
    RemoteAddress = "10.254.73.15"  # Se especifica el cliente desde donde se administrará WinRM
    LocalAddress = "Any"            # Se permite cualquier dirección local en el host
    InterfaceType = "Any"
    EdgeTraversalPolicy = "Block"
}
New-NetFirewallRule @winrmFirewallRule

# Configurar reglas adicionales para asegurarse de que solo IPv4 sea usado
$ipv4FirewallRule = [PSCustomObject]@{
    Name        = "Permitir WinRM solo en IPv4"
    Enabled     = $true
    Profile     = "Domain"
    Direction   = "Inbound"
    Action      = "Allow"
    LocalPort   = 5985, 5986
    Protocol    = "TCP"
    RemoteAddress = "10.254.73.15"  # Solo permitir conexiones desde el cliente 10.254.73.15
    LocalAddress = "Any"
    InterfaceType = "Any"
    EdgeTraversalPolicy = "Block"
    LocalOnlyMapping = $true  # Solo conexiones locales permitidas
    LocalAddress = "0.0.0.0/0"  # Se asegura que sea IPv4, ninguna dirección IPv6
}
New-NetFirewallRule @ipv4FirewallRule

# Configurar Kerberos y PSRemoting en los clientes
$gpo | Set-GPRegistryValue -Key "HKLM\Software\Policies\Microsoft\Windows\RemoteManagement\WinRM\Service\Auth" `
    -ValueName "Kerberos" -Type DWORD -Value 1
$gpo | Set-GPRegistryValue -Key "HKLM\Software\Policies\Microsoft\Windows\RemoteManagement\WinRM\Service" `
    -ValueName "AllowAutoConfig" -Type DWORD -Value 1

# Abrir los puertos para PowerShell Remoting (5985 HTTP, 5986 HTTPS), solo para IPv4 y cliente 10.254.73.15
$gpo | Set-GPRegistryValue -Key "HKLM\SYSTEM\CurrentControlSet\Services\SharedAccess\Parameters\FirewallPolicy\DomainProfile\GloballyOpenPorts\List" `
    -ValueName "5985:TCP" -Type String -Value "5985:TCP:10.254.73.15:Enabled:WinRM HTTP solo IPv4"
$gpo | Set-GPRegistryValue -Key "HKLM\SYSTEM\CurrentControlSet\Services\SharedAccess\Parameters\FirewallPolicy\DomainProfile\GloballyOpenPorts\List" `
    -ValueName "5986:TCP" -Type String -Value "5986:TCP:10.254.73.15:Enabled:WinRM HTTPS solo IPv4"

# Forzar la actualización de las GPO en todos los clientes y servidores
Invoke-GPUpdate -Computer "10.254.73.15"
