# Verificación de las configuraciones aplicadas en los hosts

$remoteHost = "localhost"

# Función para validar si una clave de registro existe y tiene el valor esperado
function Verify-RegistryValue {
    param (
        [string]$KeyPath,
        [string]$ValueName,
        [string]$ExpectedValue
    )

    $actualValue = (Get-ItemProperty -Path $KeyPath).$ValueName
    if ($actualValue -eq $ExpectedValue) {
        if (-not $global:silentMode) {
    Add-LogMessage "La clave $KeyPath\$ValueName tiene el valor correcto: $ExpectedValue"
}
    } else {
        if (-not $global:silentMode) {
    Add-LogMessage "Error: La clave $KeyPath\$ValueName tiene un valor incorrecto. Esperado: $ExpectedValue, Actual: $actualValue"
}
    }
}

# 1. Verificar la habilitación de WinRM
if (-not $global:silentMode) {
    Add-LogMessage "Verificando la configuración de WinRM en el host remoto: $remoteHost"
}
Invoke-Command -ComputerName $remoteHost -ScriptBlock {
    Verify-RegistryValue -KeyPath "HKLM\Software\Policies\Microsoft\Windows\RemoteManagement\WinRM\Service\Auth" -ValueName "Kerberos" -ExpectedValue 1
    Verify-RegistryValue -KeyPath "HKLM\Software\Policies\Microsoft\Windows\RemoteManagement\WinRM\Service" -ValueName "AllowAutoConfig" -ExpectedValue 1
    Verify-RegistryValue -KeyPath "HKLM\Software\Policies\Microsoft\Windows\RemoteManagement\WinRM\Service" -ValueName "EnableCompatibilityHttpListener" -ExpectedValue 1
}

# 2. Verificar la apertura de puertos 5985 (HTTP) y 5986 (HTTPS)
if (-not $global:silentMode) {
    Add-LogMessage "Verificando la apertura de puertos 5985 y 5986 en el firewall"
}
Invoke-Command -ComputerName $remoteHost -ScriptBlock {
    Verify-RegistryValue -KeyPath "HKLM\SYSTEM\CurrentControlSet\Services\SharedAccess\Parameters\FirewallPolicy\DomainProfile\GloballyOpenPorts\List" `
        -ValueName "5985:TCP" -ExpectedValue "5985:TCP:10.254.73.15:Enabled:WinRM HTTP IPv4"
    Verify-RegistryValue -KeyPath "HKLM\SYSTEM\CurrentControlSet\Services\SharedAccess\Parameters\FirewallPolicy\DomainProfile\GloballyOpenPorts\List" `
        -ValueName "5986:TCP" -ExpectedValue "5986:TCP:10.254.73.15:Enabled:WinRM HTTPS IPv4"
}

# 3. Verificar la apertura de puertos dinámicos RPC
if (-not $global:silentMode) {
    Add-LogMessage "Verificando la apertura de puertos dinámicos de RPC (49152-65535)"
}
Invoke-Command -ComputerName $remoteHost -ScriptBlock {
    Verify-RegistryValue -KeyPath "HKLM\SYSTEM\CurrentControlSet\Services\SharedAccess\Parameters\FirewallPolicy\DomainProfile\GloballyOpenPorts\List" `
        -ValueName "49152-65535:TCP" -ExpectedValue "49152-65535:TCP:10.254.73.15:Enabled:RPC Dinámico IPv4"
}

# 4. Verificar la política de ejecución de scripts remotos
if (-not $global:silentMode) {
    Add-LogMessage "Verificando la política de ejecución de scripts de PowerShell"
}
Invoke-Command -ComputerName $remoteHost -ScriptBlock {
    Verify-RegistryValue -KeyPath "HKLM\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ExecutionPolicy" -ValueName "ExecutionPolicy" -ExpectedValue "RemoteSigned"
}

# 5. Verificar la configuración de Kerberos
if (-not $global:silentMode) {
    Add-LogMessage "Verificando la configuración de Kerberos"
}
Invoke-Command -ComputerName $remoteHost -ScriptBlock {
    Verify-RegistryValue -KeyPath "HKLM\Software\Policies\Microsoft\Windows\WinRM\Service" -ValueName "Auth_AllowKerberos" -ExpectedValue 1
}

# 6. Verificar la configuración del listener HTTP para WinRM
if (-not $global:silentMode) {
    Add-LogMessage "Verificando la configuración del listener HTTP para WinRM"
}
Invoke-Command -ComputerName $remoteHost -ScriptBlock {
    Verify-RegistryValue -KeyPath "HKLM\SOFTWARE\Policies\Microsoft\Windows\WinRM\Service\Listener" -ValueName "Transport" -ExpectedValue "HTTP"
    Verify-RegistryValue -KeyPath "HKLM\SOFTWARE\Policies\Microsoft\Windows\WinRM\Service\Listener" -ValueName "Port" -ExpectedValue 5985
}

if (-not $global:silentMode) {
    Add-LogMessage "Verificación completa. Revisa los mensajes de estado para cualquier Error."
}
