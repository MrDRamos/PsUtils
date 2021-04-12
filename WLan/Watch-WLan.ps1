
<#
.SYNOPSIS
Shows a list of wireless networks detected by the PC's Wifi adapter.
The list is update every second.

.PARAMETER Channel
If specified we filter the list of networs bases on the channel ranges:
    2.4G  : Channels [1..14]
    5G    : Channels [32-165]
    5GLow : Channels [32-64]
    DFS   : Channels [50-144]
    5GHigh: Channels [149-165]
#>
param(
    [Parameter(Mandatory = $false)]
    [ValidateSet("", "2.4G", "5G", "5GLOW", "5GDFS", "5GHIGH")]
    $Channel
)

function Invoke-Periodically([timespan]$Sleep = [timespan]::FromSeconds(1), [timespan]$Timeout= [timespan]::Zero, [scriptblock] $Script)
{   
    $EndDate = (Get-Date) + $Timeout   
    do {
        Start-Sleep -Milliseconds $Sleep.TotalMilliseconds
        Invoke-Command -ScriptBlock $Script
    } while ($Timeout -eq [timespan]::Zero -or (Get-Date) -lt $EndDate)
}


function Watch-WlanSignal([int]$SleepSec = 1)
{
    # https://github.com/PrateekKumarSingh/Graphical
    $esc = [char]27
    $setCursorTop = "$esc[0;0H"
    [int] $Count = 0
    $Script = {
        $WLan = Get-WLan 
        $WLanChan = switch ($Channel) 
        {
            # 2.4G=Chan[1..14], 5GLow=Chan[32-64], DFS=Chan[50-144], 5GHigh=Chan[149-165]
            "2.4G"  { $WLan | Where-Object { $_.Channel -ge 1   -and  $_.Channel -le 14} }
            "5G"    { $WLan | Where-Object { $_.Channel -ge 32  -and  $_.Channel -le 165} }
            "5GLOW" { $WLan | Where-Object { $_.Channel -ge 32  -and  $_.Channel -le 64} }
            "5GDFS" { $WLan | Where-Object { $_.Channel -ge 50  -and  $_.Channel -le 144} }
            "5GHIGH"{ $WLan | Where-Object { $_.Channel -ge 149 -and  $_.Channel -le 165} }
            Default { $WLan }
        }
        if ($Script:Count++ % 5 -eq 0)
        {
            Clear-Host
        }       
        Write-Host $SetCursorTop
        $WLanChan | Format-Table -Property SSID, Channel, Signal
    }
    Invoke-Periodically -Script $Script -Sleep ([timespan]::FromSeconds($SleepSec))
}


#--- Main ---
. $PSScriptRoot\Get-WLan | Out-Null
Watch-WlanSignal
