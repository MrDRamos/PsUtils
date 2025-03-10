

<#
.SYNOPSIS
Returns the IpAddress's associated with the installed physical & or logical Network Adapters

.NOTES
Commands to get public facing IP address:
    ipify:   Invoke-Restmethod -method get -uri http://api.ipify.org
    myip:    Invoke-Restmethod -method get -uri https://api.myip.com
    opendns: nslookup myip.opendns.com resolver1.opendns.com
#>
[CmdletBinding()]
param (
    [Parameter()]
    [ValidateSet('IPv4','IPv6')]
    [string[]] $AddressFamily = 'IPv4', #@('IPv4','IPv6'),

    [Parameter()]
    [switch] $Physical
)

$AdapterS = Get-NetAdapter -Physical:$Physical
$IpAddrS = $AdapterS | Get-NetIPAddress -AddressFamily $AddressFamily -ErrorAction Ignore
$AdapterIpS = foreach ($IpAddr in ($IpAddrS | Sort-Object PrefixOrigin,IPAddress)) {
    $Adapter = $AdapterS | Where-Object { $_.ifIndex -eq $IpAddr.ifIndex }
    [PSCustomObject]@{
        IPAddress = $IpAddr.IPAddress + '/' + $IpAddr.PrefixLength
        PrefixOrigin = $IpAddr.PrefixOrigin
        #LifeTime = $IpAddr.ValidLifetime
        #AdapterName = $Adapter.Name #$IpAddr.InterfaceAlias
        InterfaceDescription = $Adapter.InterfaceDescription
        Status = $Adapter.Status #MediaConnectionState #InterfaceOperationalStatus
        LinkSpeed = $Adapter.LinkSpeed
        MacAddress = $Adapter.MacAddress
        InterfaceIndex = $Adapter.InterfaceIndex
    } | Write-Output
}
$AdapterIpS
