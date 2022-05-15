# Export all Secrets & Metadata to file
[CmdletBinding()]
param (
    [Parameter(ValueFromPipeline)]
    [ValidateNotNullOrEmpty()]
    [object] $FileName = '.\MySecrets.json'
)

$ErrorActionPreference = "Stop"

$Vault = Get-SecretVault | Where-Object { $_.IsDefault }
Write-Host "Importing secrets from file:$FileName to Vault:$($Vault.Name) in:$($Vault.ModuleName)  " -ForegroundColor Magenta

$MySecretS = Get-Content $FileName | ConvertFrom-Json
if ($VerbosePreference)
{
    $MySecretS.Name
}
$MySecretS | ForEach-Object { if ($_.UserName) { $S = [pscredential]::new($_.UserName, ($_.secret | ConvertTo-SecureString -AsPlainText -Force)) }else { $S = $_.secret }; $M = @{}; if (![string]::IsNullOrEmpty($_.Metadata)) { $_.Metadata.PSObject.Properties | ForEach-Object { $M["$($_.Name)"] = $_.Value } }; Set-Secret -Name $_.Name -Secret $S -Metadata $M }

Write-Host "Imported $($MySecretS.Count) secrets from $FileName"
