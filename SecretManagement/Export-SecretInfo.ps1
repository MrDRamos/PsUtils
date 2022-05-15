# Export all Secrets & Metadata to file
[CmdletBinding()]
param (
    [Parameter(ValueFromPipeline)]
    [ValidateNotNullOrEmpty()]
    [object] $FileName = '.\MySecrets.json'
)

$ErrorActionPreference = "Stop"

$Vault = Get-SecretVault | Where-Object { $_.IsDefault }
Write-Host "Exporting secrets from Vault:$($Vault.Name) in:$($Vault.ModuleName) to file:$FileName" -ForegroundColor Magenta

$VaultSecretS = Get-SecretInfo -Vault $Vault.Name
if ($VerbosePreference)
{
    $VaultSecretS
}
$MySecretS = $VaultSecretS | ForEach-Object { $U = $null; $S = Get-Secret -Name $_.Name -AsPlainText; if ($_.Type -eq "PSCredential") { $U = $S.Username; $S = $S.GetNetworkCredential().Password }; [PSCustomObject]@{ Name = $_.Name; UserName = $U; Secret = $S; Metadata = $_.Metadata } }
$MySecretS | ConvertTo-Json | Set-Content $FileName

Write-Host "Exported $($MySecretS.Count)/$($VaultSecretS.Count) secrets to $FileName"
