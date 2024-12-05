

<#
Returns the IpAddress's associated with the installed physical & or logical Network Adapters
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
        IPAddress = $IpAddr.IPAddress
        PrefixOrigin = $IpAddr.PrefixOrigin
        #PrefixLength = $IpAddr.PrefixLength
        AdapterName = $Adapter.Name
        InterfaceDescription = $Adapter.InterfaceDescription
        LinkSpeed = $Adapter.LinkSpeed
        MacAddress = $Adapter.MacAddress
        Status = $Adapter.MediaConnectionState #InterfaceOperationalStatus
        InterfaceIndex = $Adapter.InterfaceIndex
    } | Write-Output
}
$AdapterIpS
