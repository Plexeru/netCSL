<#
    FileName: netCSL.ps1
    Author: Netree AG / ALB
    Date: 25.10.2021
    Version: 1.00

    Version History:
        001 - Initial Version with local AD Data Request
        002 - Importing the JSON-Configfile 
        003 - Authorizing Tenant to Microsoft Graph API for 3 upcoming Queries (AzureAD / Endpoint Manager / AutoPilot)
        004 - Preparing first API Call (Graph API SDK). Changing to more reliable  API Call  (Invoke-RestMethod)
        005 - Creating the First API Call for AzureAD (Troubleshooting of Authentication)
        006 - Adding the 2 other Queries 
        007 - Implementing MAVIQ API Call (Troubleshooting with Roman Andres because of Authentication Failures)
        008 - Cleaning Up Code
        009 - Creating Outputfiles
        1.0 - Finishing Code

    

    Prerequisites
        - AzureAD PowerShell module (AzAccounts)
        - Microsoft Graph SDK 
        - Domain joined server/client to run script on
        - AD User with read rights to AD to run script with
        - Tenant with proper licencing
        - Graph API Permissions
        - MAVIQ API Permissions
        - AzureAD Tenant Credentials including Secrets and Applications IDs
        - Change the paths to the needs of the customer/device it is running on. Optimal would be an Baseline of Paths on every System
#>

<#
.SYNOPSIS
#>
[CmdletBinding()]
param()

<# Logging Modul 

$loggingModulePath = Join-Path $PSScriptRoot "PSStreamLogger\PSStreamLogger.psd1"
$mainScriptPath = Join-Path $PSScriptRoot "AdvancedCopy.ps1"
$logFilePath = Join-Path $PSScriptRoot "$(Get-Date -Format yyyyMM)-AdvancedCopy.log"

Import-Module $loggingModulePath

# Script-Output wird zurückgegeben und kann entsprechend weiterverwendet werden
$output = Invoke-CommandWithLogging -ScriptBlock {
    & $mainScriptPath -InformationAction Continue
} -LogFilePath $logFilePath

#>



###############################
# Preperation & Configruation #
###############################

$Date = Get-Date -Format ddMMyyyy
$DateTime = Get-Date

<# Config File #>
$json = Get-Content (Join-Path $PSScriptRoot ".\appsettings.json") -Encoding utf8 | ConvertFrom-Json

$clientID = $json.ClientID
$tenantID = $json.TenantID
$BasePathFile = $json.BasePathFiles
$clientSecret = $json.ClientSecret
$maviqTenantId = $json.MAVIQTenantID
$maviqclientID = $json.MAVIQClientID
$maviqClientSecret = $json.MAVIQClientSecret | ConvertTo-SecureString
$maviqApiRootUrl = "https://api.maviq.com/"

<# Prepare OAuth2 for Graph API #>
$Body = @{
    'tenant'        = $tenantID
    'client_id'     = $clientID
    'scope'         = 'https://graph.microsoft.com/.default'
    'client_secret' = $clientSecret
    'grant_type'    = 'client_credentials'
}
 
# Assemble a hashtable for splatting parameters, for readability
# The tenant id is used in the uri of the request as well as the body
$Params = @{
    'Uri'         = "https://login.microsoftonline.com/$TenantId/oauth2/v2.0/token"
    'Method'      = 'Post'
    'Body'        = $Body
    'ContentType' = 'application/x-www-form-urlencoded'
}

Write-Information "Authenticating..."
$AuthResponse = Invoke-RestMethod @Params

$Headers = @{
    'Authorization' = "Bearer $($AuthResponse.access_token)"
}

$ErrorActionPreference = "Continue"

################################
# Local Active Directory DATA  #
################################

try {
    Import-Module ActiveDirectory

    #Get localAD Device Data

    Write-Information "Get local AD devices"
    $localADDevices = Get-ADComputer -SearchBase "DC=netCSL, DC=local" -Filter 'operatingsystem -notlike "*server*" -and Enabled -eq "true"' -Properties * | Select-Object -Property CN, LastLogonDate, ObjectCategory, SamAccountName, SID, OperatingSystem, OperatingSystemVersion, Created, Enabled, LockedOut, logonCount | Sort-Object CN

    Write-Information "Export local AD devices to CSV -> '$BasePathFile\LocalADDevices.csv' "
    $localADDevices | Export-Csv "$BasePathFile\LocalADDevices.csv"

    Write-Information "Export local AD devices to JSON -> '$BasePathFile\LocalADDevices.json' "
    $localADDevices | ConvertTo-Json | Out-File "$BasePathFile\LocalADDevices.json"

}
catch {
    Write-Error "Error while getting local AD devices -> $($_.Exception)"
}


##########################
# Graph API AzureAD DATA #
##########################

try {
    Write-Information "Get Azure AD devices"
    $readAzureADDevices = Invoke-RestMethod -Uri 'https://graph.microsoft.com/v1.0/devices' -Headers $Headers

    $AzureADDevices = $readAzureADDevices.value

    Write-Information "Export Azure AD devices to CSV $BasePathFile\AzureADDevices.csv"
    $AzureADDevices | Export-Csv "$BasePathFile\AzureADDevices.csv"

    Write-Information "Export Azure AD devices to JSON $BasePathFile\AzureADDevices.json"
    $AzureADDevices | ConvertTo-Json | Out-File "$BasePathFile\AzureADDevices.json"
}
catch {
    Write-Error "$($_.Exception)"    
}

#########################
# Graph API Intune DATA #
#########################

try {

    Write-Information "Get Intune devices"
    $readIntuneDevices = Invoke-RestMethod -Uri 'https://graph.microsoft.com/beta/deviceManagement/managedDevices' -Headers $Headers

    $IntuneDevices = $readIntuneDevices.value

    Write-Information "Export Intune devices to JSON $BasePathFile\IntuneDevices.json"
    $IntuneDevices | ConvertTo-Json | Out-File "$BasePathFile\IntuneDevices.json"

    Write-Information "Export Intune devices to CSV $BasePathFile\IntuneDevices.csv"   
    $IntuneDevices | Export-Csv "$BasePathFile\IntuneDevices.csv"

}
catch {
    Write-Error "$($_.Exception)" 
}

############################
# Graph API Autopilot DATA #
############################

try {

    Write-Information "Get Autopilot devices"
    $readAutopilotDevices = Invoke-RestMethod -Uri 'https://graph.microsoft.com/v1.0/deviceManagement/windowsAutopilotDeviceIdentities' -Headers $Headers

    $AutopilotDevices = $readAutopilotDevices.value

    Write-Information "Export Autopilot devices to JSON $BasePathFile\AutopilotDevices.json"
    $AutopilotDevices | ConvertTo-Json | Out-File "$BasePathFile\AutopilotDevices.json"

    Write-Information "Export Autopilot devices to CSV $BasePathFile\AutopilotDevices.csv"
    $AutopilotDevices | Export-Csv "$BasePathFile\AutopilotDevices.csv"

}
catch {
    Write-Error "$($_.Exception)" 
}

##################
# MAVIQ API DATA #
##################

try {

    <# Prerequisites #>
    Import-Module Az.Accounts -ErrorAction Stop

    <# Authentication #>
    $credential = New-Object PSCredential -ArgumentList @($maviqclientID, $maviqClientSecret)

    # Connect as an Azure AD application (service principal)
    Write-Information "Get Connect to AzureAD"
    $azProfile = Connect-AzAccount -Credential $credential -Tenant $tenantID -ServicePrincipal -ErrorAction Stop

    # Get an access token for the MAVIQ API and convert it to a secure string
    Write-Information "Get Accesstoken"
    $accessToken = Get-AzAccessToken -ResourceUrl $maviqApiRootUrl -ErrorAction Stop | Select-Object -ExpandProperty Token | ConvertTo-SecureString -AsPlainText -Force

    # Get MAVIQ-Device Data  - MAVIQ API
    Write-Information "Get MAVIQ devices"
    $readMaviqDevices = Invoke-RestMethod -Method Get -Uri "https://api.maviq.com/$($maviqTenantId)/device/search?search=%2A&%24count=true&queryType=simple&searchMode=any" -Authentication Bearer -Token $accessToken 

    $MaviqDevices = $readMaviqDevices.value

    Write-Information "Export MAVIQ devices to CSV $BasePathFile\MAVIQDevice.csv"
    $MaviqDevices | Export-Csv  "$BasePathFile\MAVIQDevice.csv"

    Write-Information "Export MAVIQ devices to JSON $BasePathFile\MAVIQDevice.json"
    $MaviqDevices | ConvertTo-Json | Out-File "$BasePathFile\MAVIQDevice.json"

    # Disconnect
    Disconnect-AzAccount -AzureContext $azProfile.Context | Out-Null

}
catch {
    Write-Error "$($_.Exception)" 
} 

Write-Host "Script Finished"


########################################################
#           Paging for every API Call                  #
########################################################

<#
$AzureADDevices = $readAzureADDevices.value
while ($Result.'@odata.nextLink') {
    Write-Host "Getting another Page of 100 devices..."
    $readAzureADDevices = Invoke-RestMethod -Uri $readAzureADDevices.'@odata.nextLink' -Headers $Headers
}
return $AzureADDevices

Write-Host "Finished listing AzureAD Devices"


$readIntuneDevices = Invoke-RestMethod -Uri 'https://graph.microsoft.com/beta/deviceManagement/managedDevices' -Headers $Headers

$IntuneDevices = $readIntuneDevices.value
while ($Result.'@odata.nextLink') {
    Write-Host "Getting another Page of 100 devices..."
    $readIntuneDevices = Invoke-RestMethod -Uri $readIntuneDevices.'@odata.nextLink' -Headers $Headers
}
return $IntuneDevices

Write-Host "Finished listing Intune Devices"


$readAutopilotDevices = Invoke-RestMethod -Uri 'https://graph.microsoft.com/v1.0/deviceManagement/windowsAutopilotDeviceIdentities' -Headers $Headers

$AutopilotDevices = $readAutopilotDevices.value
while ($Result.'@odata.nextLink') {
    Write-Host "Getting another Page of 100 devices..."
    $readAutopilotDevices = Invoke-RestMethod -Uri $readAutopilotDevices.'@odata.nextLink' -Headers $Headers
}
return $AutopilotDevices

Write-Host "Finished listing Autopilot Devices"


###############################################################
#                Singlecode for Paging if needed              #
###############################################################


while ($Result.'@odata.nextLink') {
    Write-Host "Getting another Page of 100 devices..."
    $readAzureADDevices = Invoke-RestMethod -Uri $readAzureADDevices.'@odata.nextLink' -Headers $Headers
}
return $AzureADDevices


#################################################################################
# Calling Data with the Microsoft Graph PowerShell SDK ((Limited Data to Call)) #
#################################################################################


# Authenticate
Connect-MgGraph -ClientID $json.ClientId -TenantId $json.TenantId -CertificateThumbprint $json.CertificateId

Write-Host "USERS:"
Write-Host "======================================================"
# List first 50 users
Get-MgUser -Property "id,displayName" -PageSize 50 | Format-Table DisplayName, Id

Write-Host "GROUPS:"
Write-Host "======================================================"
# List first 50 groups
Get-MgGroup -Property "id,displayName" -PageSize 50 | Format-Table DisplayName, Id

Get-MgDevice -Property "id, displayName"

# Disconnect
Disconnect-MgGraph

#Lokales AD Umsystem 1



#>