# Verificar la política de ejecución actual para sesiones remotas
$currentPolicyRemote = Get-ExecutionPolicy -Scope RemoteSession
if (-not $global:silentMode) {
    Add-LogMessage "Política de ejecución actual para sesiones remotas: $currentPolicyRemote"
}

# Cambiar la política de ejecución para sesiones remotas a RemoteSigned
if (-not $global:silentMode) {
    Add-LogMessage "Cambiando la política de ejecución para sesiones remotas a RemoteSigned..."
}
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope RemoteSession -Force
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope LocalMachine -Force

# Confirmar el cambio de política
$newPolicyRemote = Get-ExecutionPolicy -Scope RemoteSession
if (-not $global:silentMode) {
    Add-LogMessage "La nueva política de ejecución para sesiones remotas es: $newPolicyRemote"
}