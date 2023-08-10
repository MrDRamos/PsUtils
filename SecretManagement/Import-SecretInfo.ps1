<#
.SYNOPSIS Import Secrets & Metadata from file into vault
#>
[CmdletBinding(SupportsShouldProcess)]
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
[int]$Idx=0
$MySecretS | ForEach-Object {
    if ($_.Type -eq 'PSCredential') {
        $S = [pscredential]::new($_.UserName, ($_.Secret | ConvertTo-SecureString -AsPlainText -Force)) 
    }
    elseif ($_.Type -eq 'Hashtable') {
        $S= @{}
        $_.Secret.PsObject.Properties | ForEach-Object { $S["$($_.Name)"] = $_.Value } 
    }
    else {
        $S = $_.secret
    }
    $M = @{}
    if (![string]::IsNullOrEmpty($_.Metadata)) {
        $_.Metadata.PSObject.Properties | ForEach-Object { $M["$($_.Name)"] = $_.Value } 
    }
    if ($WhatIfPreference)
    {
        if ($VerbosePreference)
        {
            if ($M.Count)
            {
                $MStr = $M.Keys | ForEach-Object { "$_='$($M[$_])'" }
                $MStr = '@{' + ($MStr -join ';') + '}'
                Write-Output "Set-Secret -Name '$($_.Name)' -Secret '$S' -Metadata $MStr"
            }
            else 
            {
                Write-Output "Set-Secret -Name '$($_.Name)' -Secret '$S'"
            }    
        }
        else
        {
            Write-Host ('{0,-4} {1,-60}' -f $Idx++, $_.Name)    
        }
    }
    else 
    {        
        Write-Host ('{0,-4} {1,-60}' -f $Idx++, $_.Name)
        Set-Secret -Name $_.Name -Secret $S -Metadata $M
    }
}

Write-Host "Imported $Idx/$($MySecretS.Count) secrets from $FileName"
