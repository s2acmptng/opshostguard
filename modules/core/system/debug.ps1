import-module .\OpsInit.psd1
Initialize-Files
Initialize-Log
Test-PathsAndFiles
Update-PluginsInConfig -DetectedPlugins $detectedPlugins
Initialize-Modules
Import-Modules
Import-Plugins
Initialize-DefaultParameters
Initialize-GlobalSettings -ParameterHash $UserParameters
Initialize-GlobalPsRemotingCredential