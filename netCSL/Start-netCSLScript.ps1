$loggingModulePath = Join-Path $PSScriptRoot "PSStreamLogger\PSStreamLogger.psd1"
$mainScriptPath = Join-Path $PSScriptRoot "netCSL.ps1"
$logFilePath = Join-Path $PSScriptRoot "$(Get-Date -Format yyyyMM)-netCSL.log"

Import-Module $loggingModulePath

$fileLogger = New-FileLogger -FilePath $logFilePath

# Script-Output wird zurückgegeben und kann entsprechend weiterverwendet werden
$output = Invoke-CommandWithLogging -ScriptBlock {
    & $mainScriptPath -InformationAction Continue
} -Loggers @($fileLogger)