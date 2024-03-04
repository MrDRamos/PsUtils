[CmdletBinding()]
param (
    [Parameter()]
    [string] $Vault = $null
)

$SelectedSecret = Get-SecretInfo -Vault $Vault | Sort-Object -Property Name | Out-GridView -OutputMode single -Title 'Copy secret to clipboard'
if ($SelectedSecret)
{
    $Secret = Get-Secret -Name $SelectedSecret.Name -Vault $Vault -AsPlainText
    if ($SelectedSecret.Type -eq 'PSCredential')
    {
        $Secret = $Secret.GetNetworkCredential().Password
    }
    $Secret | Set-Clipboard 
}