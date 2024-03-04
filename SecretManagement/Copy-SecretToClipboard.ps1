[CmdletBinding()]
param (
    [Parameter()]
    [string] $Vault = $null
)

$AllSecretS = Get-SecretInfo -Vault $Vault
do 
{
    $SelectedSecret = $AllSecretS | Sort-Object -Property Name | Out-GridView -OutputMode single -Title 'Copy secret to clipboard'
    if ($SelectedSecret)
    {
        $Secret = Get-Secret -Name $SelectedSecret.Name -Vault $Vault -AsPlainText
        if ($SelectedSecret.Type -eq 'PSCredential')
        {
            $Secret = $Secret.GetNetworkCredential().Password
        }
        $Secret | Set-Clipboard 
    }
} while ($SelectedSecret)
