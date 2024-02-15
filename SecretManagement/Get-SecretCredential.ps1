<#
.SYNOPSIS
Returns a [pscredential] for the given KeyName from the PowerShell SecretManagement Vault.
see: https://devblogs.microsoft.com/powershell/secretmanagement-and-secretstore-are-generally-available/
The caller is interactively prompted for a user name & password if the KeyName is not found in the vault, 
or if the SecretManagement modules are not installed on this computer.

.PARAMETER KeyName
The name (or key) of the secret to be retrieved. Wild card characters are not allowed.

.PARAMETER Vault
Optional name of the registered vault to retrieve the secret from. 
If no vault name is specified, then all registered vaults are searched.

.PARAMETER Force
Specify this switch to interactively prompt the caller for credentials even if a vault entry already exists.
The new credentials are automatically saved to the vault unless the AskToSave was specified.

.PARAMETER AskToSave
If the user entered new credentials then they are automatically saved to the vault.
Set the AskToSave switch, to first prompt the caller for permission to save the new credentials.

.EXAMPLE
$Cred = Get-SecretCredential -KeyName 'TestKey'
$Cred.UserName; $Cred.GetNetworkCredential().Password

.EXAMPLE
Prompt user for new credential and then ask to override/save to the vault
$Cred = Get-SecretCredential -KeyName 'TestKey' -Force -AskToSave

.NOTES
# To install & register the local secret store extension from the psgallery run:
Install-Module -Name Microsoft.PowerShell.SecretStore -Repository PsGallery
Register-SecretVault -ModuleName Microsoft.PowerShell.SecretStore -Name "local" -Description "https://github.com/powershell/secretstore"
Set-SecretStoreConfiguration -Authentication "None"

# Examples - Enter a master password for the local vault on 1st usage:
# Add a string example:
Set-Secret -Name "hello" -Secret "world"
Get-Secret -Name "hello" -AsPlainText

# Add a [pscredential] example:
$cred = [pscredential]::new("myname", ("mypass" | ConvertTo-SecureString -AsPlainText -Force))
Set-Secret -Name "mycred" -Secret $cred
Get-Secret -Name "mycred" 

# Add a [hashtable] example:
Set-Secret -Name "cities" -Secret @{nyc = "usa"; berlin = "germany"}
Get-Secret -Name "cities" -AsPlainText

# Enumerate all secret names:
Get-SecretInfo

# Export all Secrets & Metadata to file
$MySecretS = Get-SecretInfo | ForEach-Object {$U=$null; $S = Get-Secret -Name $_.Name -AsPlainText; if ($_.Type -eq "PSCredential") {$U=$S.Username;$S=$S.GetNetworkCredential().Password}; [PSCustomObject]@{ Name = $_.Name; UserName=$U; Secret = $S; Metadata = $_.Metadata } }
$MySecretS | ConvertTo-Json | Set-Content .\MySecrets.json

# Import all Secrets & Metadata from a file:
$MySecretS = Get-Content .\MySecrets.json | ConvertFrom-Json
$MySecretS | ForEach-Object {if ($_.UserName){ $S = [pscredential]::new($_.UserName,($_.secret | ConvertTo-SecureString -AsPlainText -Force))}else{$S = $_.secret}; $M = @{};if (![string]::IsNullOrEmpty($_.Metadata)) {$_.Metadata.PSObject.Properties | ForEach-Object { $M["$($_.Name)"]=$_.Value}};Set-Secret -Name $_.Name -Secret $S -metadata $M}

# By default the master password for the local vault must be re-authenticated once every 15 minutes.
# Disable the need to re-authenticate every 15 minutes
Set-SecretStoreConfiguration -Authentication "None"


# Additional Secretmanagement Links:
Introduction:   https://devblogs.microsoft.com/powershell/secretmanagement-and-secretstore-are-generally-available/
Commands help:  https://github.com/PowerShell/SecretManagement/tree/master/help
Main Secretmanagement module:   https://github.com/powershell/secretmanagement
Local vault extension module:   https://github.com/powershell/secretstore
#>
function Get-SecretCredential
{
    [OutputType([pscredential])]
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, Position=0, ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [Alias("Key", "Name")]
        [string] $KeyName, 

        [Parameter(Position=1)]
        [string] $Vault = $null, 

        [Parameter()]
        [switch] $Force,

        [Parameter()]
        [switch] $AskToSave
    )    
    $Cred = $null
    if (!$Force -and (Get-Command "Get-Secret" -ErrorAction Ignore))
    {
        $Cred = Get-Secret -Name $KeyName -Vault $Vault -ErrorAction Ignore
    }
    if (!$Cred)
    {
        $UseConsole = $false
        #$UseConsole = $true
        if ($UseConsole)
        {
            Write-Host "Enter credential for vault key: $KeyName"
            $UserName = Read-Host -Prompt "User name: $KeyName"
            if (!$UserName)
            {
                return $null
            }
            $Password = Read-Host -Prompt "Password for: $UserName" -AsSecureString
            if (!$Password)
            {
                return $null
            }
            $Cred = [pscredential]::new($UserName, $Password)
        }
        else 
        {
            $Cred = Get-Credential -Message "Enter credential for vault key: $KeyName"    
        }        
        if ($Cred -and (Get-Command "Get-Secret" -ErrorAction Ignore))
        {
            $Persist = !$AskToSave
            if ($AskToSave)
            {
                $UserInput = Read-Host -Prompt "Persist credential to the vault:$Vault (Y/N)"
                $Persist = @("yes", "y") -contains $UserInput
            }
            if ($Persist)
            {
                if ($Vault)
                {
                    Set-Secret -Name $KeyName -Secret $Cred -Vault $Vault
                }
                else 
                {
                    Set-Secret -Name $KeyName -Secret $Cred
                }
            }
        }
    }
    return $Cred
}

<#
##### Unit test #####

$Cred = Get-SecretCredential -KeyName 'TestKey' -Force -AskToSave
$Cred.UserName; $Cred.GetNetworkCredential().Password

# Readback
$Cred = Get-SecretCredential -KeyName 'TestKey'
$Cred.UserName; $Cred.GetNetworkCredential().Password

#>
