
param
(
    [Parameter()]
    [int] $Range = 255,

    [Parameter()]
    [string] $Lan24Ip = "192.168.1"
)


$IpRange = 1..$Range | ForEach-Object { "$($Lan24Ip).$_" }
& $PSScriptRoot\Test-LanIP.ps1 -IP $IpRange
