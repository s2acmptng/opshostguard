# Configurar el host remoto autorizado
$remoteHost = "10.254.73.15"  # Sustituye por la IP del host remoto que tendrá acceso

# Habilitar WinRM
if (-not $global:silentMode) {
    Add-LogMessage "Habilitando WinRM..."
}
Enable-PSRemoting -Force

# Permitir la conexión HTTP en el puerto 5985 (WinRM estándar)
if (-not $global:silentMode) {
    Add-LogMessage "Configurando Firewall para WinRM HTTP (Puerto 5985)..."
}
New-NetFirewallRule -Name "Allow WinRM HTTP from Specific Host" `
    -DisplayName "Allow WinRM HTTP from Specific Host" `
    -Direction Inbound `
    -LocalPort 5985 `
    -Protocol TCP `
    -RemoteAddress $remoteHost `
    -Action Allow

# Permitir la conexión HTTPS en el puerto 5986 (WinRM seguro)
if (-not $global:silentMode) {
    Add-LogMessage "Configurando Firewall para WinRM HTTPS (Puerto 5986)..."
}
New-NetFirewallRule -Name "Allow WinRM HTTPS from Specific Host" `
    -DisplayName "Allow WinRM HTTPS from Specific Host" `
    -Direction Inbound `
    -LocalPort 5986 `
    -Protocol TCP `
    -RemoteAddress $remoteHost `
    -Action Allow

# Definir el rango de puertos dinámicos
$startPort = 1024
$endPort = 65535

# Crear una regla de firewall para permitir el tráfico en los puertos dinámicos para conexiones WinRM
if (-not $global:silentMode) {
    Add-LogMessage "Abriendo puertos dinámicos ($startPort-$endPort) para WinRM desde $remoteHost..."
}
New-NetFirewallRule -Name "Allow WinRM Dynamic Ports" `
    -DisplayName "Allow WinRM Dynamic Ports" `
    -Direction Inbound `
    -LocalPort $startPort-$endPort `
    -Protocol TCP `
    -RemoteAddress $remoteHost `
    -Action Allow

if (-not $global:silentMode) {
    Add-LogMessage "Regla de firewall creada para permitir puertos dinámicos para WinRM desde $remoteHost."
}

# Confirmar la configuración
if (-not $global:silentMode) {
    Add-LogMessage "WinRM y Firewall configurados para permitir conexiones desde $remoteHost."
}
