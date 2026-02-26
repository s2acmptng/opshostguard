# Variables del módulo para almacenar la contraseña y el tiempo de actividad
$script:SessionPassword = $null
$script:SessionExpiryTime = $null
$script:SessionTimeoutMinutes = 15 # Tiempo de inactividad permitido (en minutos)

# Función para iniciar sesión con contraseña
function Start-SecureSession {
    param (
        [string]$PasswordPrompt = "Enter the application password:"
    )

    # Solicitar la contraseña
    $password = Read-Host -AsSecureString $PasswordPrompt
    $plainPassword = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
        [Runtime.InteropServices.Marshal]::SecureStringToBSTR($password)
    )

    # Validar contraseña (puedes agregar lógica personalizada aquí)
    if (-not $plainPassword -or $plainPassword.Length -lt 6) {
        throw "Invalid password. Password must be at least 6 characters long."
    }

    # Establecer la contraseña en la sesión
    $script:SessionPassword = $plainPassword
    $script:SessionExpiryTime = (Get-Date).AddMinutes($script:SessionTimeoutMinutes)

    Write-Host "Secure session started. Session will expire in $script:SessionTimeoutMinutes minutes."
}

# Función para validar la sesión activa
function Validate-SecureSession {
    if (-not $script:SessionPassword) {
        throw "No active session. Please start a secure session first."
    }

    if ((Get-Date) -gt $script:SessionExpiryTime) {
        $script:SessionPassword = $null
        $script:SessionExpiryTime = $null
        throw "Session expired due to inactivity. Please start a new secure session."
    }

    # Renovar el tiempo de expiración en cada validación
    $script:SessionExpiryTime = (Get-Date).AddMinutes($script:SessionTimeoutMinutes)
    return $true
}

# Función para finalizar la sesión
function End-SecureSession {
    $script:SessionPassword = $null
    $script:SessionExpiryTime = $null
    Write-Host "Secure session ended."
}

# Exportar las funciones del módulo
Export-ModuleMember -Function Start-SecureSession, Validate-SecureSession, End-SecureSession
