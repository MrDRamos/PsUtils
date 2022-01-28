
param
(
    [Parameter()]
    [int] $Range = 50,

    [Parameter()]
    [string] $Lan24Ip = "192.168.1"
)


$IpRange = 1..$Range | ForEach-Object { "$($Lan24Ip).$_" }
& $PSScriptRoot\Test-OnlineFast.ps1 -ComputerName $IpRange
