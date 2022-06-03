<#
.SYNOPSIS
Tests if one or more devices are active on the local network.
Returns list of (IP, MACAddress) records for the devices found.

Instead of then sending out slow Ping requests, this function sends
out UDP packates. Devices respond to these requests with thier MAC
address which this computers network drivers record in ARP cache.
We then parse the ARP records for found MAC addresses.

.PARAMETER IP
List of IP Address to scan.

.PARAMETER DelayMS
The amount of time to wait after sending a UDP request to an IP Address.
Default = 2 Miliseconds

.PARAMETER ClearARPCache
Clears the local ARP cache (a mapping of IP-Address to MacAddress) 
with old device records from prior network activity, before scanning for new devices.
#>
[Cmdletbinding()]
Param (
    [Parameter(Mandatory, Position=1)]
    [string[]]$IP,

    [Parameter(Mandatory=$false, Position=2)]
    [ValidateRange(0,15000)]
    [int]$DelayMS = 2,
    
    [Parameter()]
    [switch]$ClearARPCache
)

<#
.SYNOPSIS
Test if any device is connected to local network, for the input 
IP addresses specified.
Returns list of (IP, MACAddress) records for the devices found.

Instead of then sending out slow Ping requests, this function sends
out UDP packates. Devices respond to these requests with thier MAC
address which this computers network drivers record in ARP cache.
We then parse the ARP records for found MAC addresses.

.NOTES
Code Inspired by:
https://xkln.net/blog/layer-2-host-discovery-with-powershell-in-under-a-second/
#>
function Find-LANHosts 
{
    [Cmdletbinding()]

    Param (
        [Parameter(Mandatory, Position=1)]
        [string[]]$IP,

        [Parameter(Mandatory=$false, Position=2)]
        [ValidateRange(0,15000)]
        [int]$DelayMS = 2,
        
        [ValidateScript({
            $IsAdmin = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
            if ($IsAdmin.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
                $True
            } 
            else {
                Throw "Must be running an elevated prompt to use ClearARPCache"
            }
        })]
        [switch]$ClearARPCache
    )

    $ASCIIEncoding = New-Object System.Text.ASCIIEncoding
    $Bytes = $ASCIIEncoding.GetBytes("a")
    $UDP = New-Object System.Net.Sockets.Udpclient

    if ($ClearARPCache) {
        arp -d
    }

    $Timer = [System.Diagnostics.Stopwatch]::StartNew()

    $IP | ForEach-Object {
        $UDP.Connect($_,1)
        [void]$UDP.Send($Bytes,$Bytes.length)
        if ($DelayMS) {
            [System.Threading.Thread]::Sleep($DelayMS)
        }
    }

    $Hosts = arp -a

    $Timer.Stop()
    if ($Timer.Elapsed.TotalSeconds -gt 15) {
        Write-Warning "Scan took longer than 15 seconds, ARP entries may have been flushed. Recommend lowering DelayMS parameter"
    }

    $Hosts = $Hosts | Where-Object {$_ -match "dynamic"} | % {($_.trim() -replace " {1,}",",") | ConvertFrom-Csv -Header "IP","MACAddress"}
    $Hosts = $Hosts | Where-Object {$_.IP -in $IP}

    Write-Output $Hosts
}


Find-LANHosts @PSBoundParameters
