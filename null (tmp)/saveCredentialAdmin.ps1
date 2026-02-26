# Script de PowerShell para guardar credenciales
$cred = New-Object System.Management.Automation.PSCredential ('username', (ConvertTo-SecureString 'password' -AsPlainText -Force))
$cred | Export-Clixml -Path ".\credentials\credAdmin.xml"