

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
    [switch] $Physical,

    [Parameter()]
    [switch] $Passthru
)

$AdapterS = Get-NetAdapter -Physical:$Physical
$IpAddrS = $AdapterS | Get-NetIPAddress -AddressFamily $AddressFamily -ErrorAction Ignore
$AdapterIpS = foreach ($IpAddr in ($IpAddrS | Sort-Object PrefixOrigin,IPAddress)) {
    $Adapter = $AdapterS | Where-Object { $_.ifIndex -eq $IpAddr.ifIndex }
    [PSCustomObject]@{
        IPAddress = $IpAddr.IPAddress + '/' + $IpAddr.PrefixLength
        Name = $Adapter.InterfaceAlias
        Status = $Adapter.Status #MediaConnectionState #InterfaceOperationalStatus
        #LifeTime = $IpAddr.ValidLifetime
        #AdapterName = $Adapter.Name #$IpAddr.InterfaceAlias
        InterfaceDescription = $Adapter.InterfaceDescription
        LinkSpeed = $Adapter.LinkSpeed
        PrefixOrigin = $IpAddr.PrefixOrigin
        MacAddress = $Adapter.MacAddress
        IfIdx = $Adapter.InterfaceIndex
    } | Write-Output
}

if ($Passthru) {
    $AdapterIpS | Write-Output
}
else 
{
    $AdapterIpS | Format-Table -AutoSize
}
