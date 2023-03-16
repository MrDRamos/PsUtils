<#
.SYNOPSIS
Retuns a list of wireless networks detected by the PC's WiFi adapter.
The list is sorted by channel and signal strength.

.DESCRIPTION
The list is obtained by parsing the output of the following command:
netsh wlan show networks mode=Bssid

.EXAMPLE
Show table of detected WiFi networks
Get-WLan | Format-Table
#>
param()

function New_Wlan()
{
    return [pscustomobject] @{
        Interface          = ''
        SSID               = ''
        Channel            = ''
        Signal             = ''
        RadioType          = ''
        Band               = ''
        Authentication     = ''
        BSSID              = ''
        NetworkType        = ''
        Encryption         = ''
        'BasicRates(Mbps)' = ''
        'OtherRates(Mbps)' = ''
    }
}

function Get-WLan
{
    $WlanS = [System.Collections.ArrayList]::new()
    $Interface = ""

    [string[]]$OutLineS = & netsh.exe wlan show networks mode=Bssid
    $MatchLineS = $OutLineS | Select-String '\s*(.*)\s+:\s+(.*)'
    foreach ($MatchLine in $MatchLineS) 
    {
        $GroupS = $MatchLine.Matches.Groups
        $Key = ($GroupS[1].Value -split ' ')[0]
        $Value = $GroupS[2].Value.Trim()
        switch ($Key) {
            'Interface' { $Interface = $Value; break }
            'SSID' {
                $WlanSsid = New_Wlan
                $WlanSsid.Interface = $Interface
                $WlanSsid.SSID = $Value
                if ([string]::IsNullOrWhiteSpace($Value))
                {
                    $WlanSsid.SSID = '-hidden-' + ($GroupS[1].Value -split ' ')[1]
                }
                break 
            }
            'Network' { $WlanSsid.NetworkType = $Value; break }
            'Authentication' { $WlanSsid.Authentication = $Value; break }
            'Encryption' { $WlanSsid.Encryption = $Value; break }

            'BSSID' {
                $Wlan = New_Wlan
                [void]$WlanS.Add($Wlan)
                $Wlan.Interface = $WlanSsid.Interface
                $Wlan.SSID = $WlanSsid.SSID
                $Wlan.NetworkType = $WlanSsid.NetworkType
                $Wlan.Authentication = $WlanSsid.Authentication
                $Wlan.Encryption = $WlanSsid.Encryption
                $Wlan.BSSID = $Value
                break 
            }
            'Channel' { $Wlan.Channel = [int]$Value; break }
            'Signal' { $Wlan.Signal = $Value; break }
            'Radio' { $Wlan.RadioType = $Value; break }
            'Band' { $Wlan.Band = $Value; break }
            'Basic' { $Wlan.'BasicRates(Mbps)' = $Value; break }
            'Other' { $Wlan.'OtherRates(Mbps)' = $Value; break }
        }
    }

    return $WlanS | Sort-Object -Property Band, Channel, @{Expression = "Signal"; Descending = $True }
}

$Retval = Get-WLan
return $Retval
