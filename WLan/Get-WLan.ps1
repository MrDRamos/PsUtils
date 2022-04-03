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


function Get-WLan
{
    [int]$HidenCount = 0
    [int]$LineNo = 0
    #$WlanS = @()
    $WlanS = [System.Collections.ArrayList]::new()

    [string[]]$outLineS = & netsh.exe wlan show networks mode=Bssid
    while ($LineNo -lt $outLineS.Count)
    {
        $Line = $outLineS[$LineNo++]
        if ($Line.StartsWith("SSID "))
        {
            $Name = $Line.Substring($Line.IndexOf(":")+1).Trim()
            $Line = $outLineS[$LineNo++]
            $NetType = $Line.Substring($Line.IndexOf(":")+1).Trim()
            $Line = $outLineS[$LineNo++]
            $Authentication = $Line.Substring($Line.IndexOf(":")+1).Trim()
            $Line = $outLineS[$LineNo++]
            $Encryption = $Line.Substring($Line.IndexOf(":")+1).Trim()
            $Line = $outLineS[$LineNo++]
            while ($Line.StartsWith("    BSSID "))
            {
                if ($Name)
                {
                    $SSID = $Name
                }
                else
                {
                    $HidenCount++            
                    $SSID = "-hidden-$HidenCount"
                }
                $BSSID = $Line.Substring($Line.IndexOf(":")+1).Trim()
                $Line = $outLineS[$LineNo++]
                #$Signal = [int]($Line.Substring($Line.IndexOf(":")+2) -replace "\%\s","")
                $Signal = $Line.Substring($Line.IndexOf(":")+1).Trim()
                $Line = $outLineS[$LineNo++]
                $RadioType = $Line.Substring($Line.IndexOf(":")+1).Trim()
                $Line = $outLineS[$LineNo++]
                $Channel = [int]($Line.Substring($Line.IndexOf(":")+1))
                $Line = $outLineS[$LineNo++]
                $BasicRates = $Line.Substring($Line.IndexOf(":")+1).Trim()
                $Line = $outLineS[$LineNo++]
                $OtherRates = $Line.Substring($Line.IndexOf(":")+1).Trim()
                $Line = $outLineS[$LineNo++]

                $Wlan = [pscustomobject] @{
                    SSID = $SSID
                    Channel = $Channel
                    Signal = $Signal
                    RadioType = $RadioType
                    Authentication = $Authentication
                    BSSID = $BSSID
                    NetworkType = $NetType
                    Encrption = $Encryption
                    "BasicRates(Mbps)" = $BasicRates
                    "OtherRates(Mbps)" = $OtherRates
                }
                #$WlanS += $Wlan
                [void]$WlanS.add($Wlan)
            }
        }
    }

    return $WlanS | Sort-Object -Property Channel, @{Expression = "Signal"; Descending = $True}
}

$Retval = Get-WLan
return $Retval
