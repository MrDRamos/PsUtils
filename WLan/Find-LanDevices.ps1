<#
.SYNOPSIS
Scans the local network for active devices.
Returns a list of records containing the: IpAddress, MacAddress & DnsName
for each device that was found.
This script is a wrapper to: Test-LanIP.ps1 

.PARAMETER Range
An optional range of IP Addresses to scan. Default = 255
which will cycle last octet of the networks IP Address
thru all the values 1..255

.PARAMETER InterfaceIndex
Optional ID of one or more network adapter to use.\
To get a list of availible network adapter call: Get-NetAdapter 
The default is to scan for devices on each enabled Physical adapter.

.PARAMETER ResolveDnsName
An additional DNS query is made to try to determine the device name associated
with the found IP Addresses.

.PARAMETER ClearARPCache
Clears the local ARP cache (a mapping of IP-Address to MacAddress) 
with old device records from prior network activity, before scanning for new devices.
#>
param
(
    [Parameter()]
    [int] $Range = 255,

    [Parameter()]
    [uint[]] $InterfaceIndex = $null,

    [Parameter()]
    [switch] $ResolveDnsName,

    [Parameter()]
    [switch] $ClearARPCache
)

$ActiveAdapterS = Get-NetAdapter -Physical | Where-Object Status -EQ "Up"
if (!$InterfaceIndex)
{
    $InterfaceIndex = $ActiveAdapterS.InterfaceIndex
}

$IpConnectionS =  Get-NetIPAddress -InterfaceIndex $InterfaceIndex -AddressFamily "IPv4"
[array]$ActiveIpS = $IpConnectionS | Where-Object { $ActiveAdapterS.InterfaceIndex -contains $_.InterfaceIndex }

foreach ($ActiveIp in $ActiveIpS)
{
    #Region Init IpRange
    $IPAddrObj = [System.Net.IPAddress]$ActiveIp.IPAddress
    $MaskBits = 32 - $ActiveIp.PrefixLength
    $AddrRange = [Math]::Pow(2, $MaskBits)

    #IPv4 addresses are 32-bits long
    $NetAddr64 = [System.Net.IPAddress]::HostToNetworkOrder($IPAddrObj.Address) -shr 32
    # We need to typecast from Int64 to UInt32
    [UInt32]$NetAddr = [BitConverter]::ToUInt32([BitConverter]::GetBytes($NetAddr64))
    $MaskPow = 1 + [Int]([math]::Log($MaskBits, 2))
    $BaseAddr = ($NetAddr -shr $MaskPow) -shl $MaskPow

    $IpRange = foreach ($Idx in 1..($AddrRange -1)) 
    {
        $NetAddr = $BaseAddr + $Idx
        $HostAddr64 = [System.Net.IPAddress]::NetworkToHostOrder($NetAddr) -shr 32
        # We need to typecast from Int64 to UInt32
        [UInt32]$HostAddr = [BitConverter]::ToUInt32([BitConverter]::GetBytes($HostAddr64))
        $IpAddr = ([System.Net.IPAddress]$HostAddr).IPAddressToString
        $IpAddr
    }
    #EndRegion Init IpRange

    $Result = & $PSScriptRoot\Test-LanIP.ps1 -IP $IpRange -ClearARPCache:$ClearARPCache

    if ($ResolveDnsName)
    {
        $Result | ForEach-Object {
            [PSCustomObject]@{
                IpAddress  = $_.IP
                MacAddress = $_.MACAddress
                DnsName    = ((Resolve-DnsName($_.IP) -DnsOnly -ErrorAction Ignore).NameHost  )
            }
        }
    }
    else 
    {
        $Result
    }
}



