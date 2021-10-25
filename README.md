# netCSL
Diplomarbeit und Projektauftrag

# Version
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
        
# Prerequisites
        - AzureAD PowerShell module (AzAccounts)
        - Microsoft Graph SDK 
        - Domain joined server/client to run script on
        - AD User with read rights to AD to run script with
        - Tenant with proper licencing
        - Graph API Permissions
        - MAVIQ API Permissions
        - AzureAD Tenant Credentials including Secrets and Applications IDs
        - Change the paths to the needs of the customer/device it is running on. Optimal would be an Baseline of Paths on every System

# Authentication
  To get the choosen Devicedata over the API there has to be an 2OAuth authentication
  The authentication will need different Credentials which are saved in a external JSON-File

  To Creating the correct API-Query there are 2 different Websites to Try&Error
  Graph API - Graph Explorer https://aka.ms/ge
  MAVIQ API - https://docs.maviq.com/api/#/Device/Device-Search-Get

  Graph Explorer also provides information about the correct and needed permissions for the application.

# Logging
  To create a Log start the Start-netCSLScript.ps1 PowerShell script
