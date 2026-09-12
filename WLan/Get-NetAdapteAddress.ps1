
<#
.SYNOPSIS
Gets active and hidden network adapters with their configured IP addresses.

.DESCRIPTION
Gets network adapters and their configured IPv4 and IPv6 addresses. Results can
be limited by address family, adapter status, or whether the adapter is physical
or hidden. By default, adapters with IPv4 or IPv6 addresses are included.

.PARAMETER AddressFamily
Limits results to adapters with IPv4 addresses, IPv6 addresses, both address
families, or no configured addresses by using 'NA'.

.PARAMETER StatusUp
Limits results to adapters whose status is Up.

.PARAMETER Physical
Limits the adapter query to physical adapters.

.PARAMETER IncludeHidden
Includes hidden adapters in the adapter query.

.PARAMETER PassThru
Writes the adapter profile objects to the pipeline. Without this switch, the
results are formatted as a table for display.

.OUTPUTS
PSCustomObject when PassThru is specified; otherwise, formatted table output.

.EXAMPLE
Get-NetAdapterAddress -AddressFamily IPv4 -StatusUp

Gets active adapters that have an IPv4 address.

.EXAMPLE
Get-NetAdapterAddress -IncludeHidden -PassThru

Gets profiles for visible and hidden adapters and writes the objects to the
pipeline.
#>
[CmdletBinding()]
param (
    [Parameter()]
    [ValidateSet($null, 'NA', 'IPv4', 'IPv6', 'Both')]
    [array] $AddressFamily = @('Both'),

    [Parameter()]
    [switch] $StatusUp,

    [Parameter()]
    [switch] $Physical,

    [Parameter()]
    [switch] $IncludeHidden,

    [Parameter()]
    [switch] $PassThru
)


function Get-NetAdapterAddress
{
    [CmdletBinding()]
    param (
        [Parameter()]
        [ValidateSet($null, 'NA', 'IPv4', 'IPv6', 'Both')]
        [array] $AddressFamily = @('Both'),

        [Parameter()]
        [switch] $StatusUp,

        [Parameter()]
        [switch] $Physical,

        [Parameter()]
        [switch] $IncludeHidden,

        [Parameter()]
        [switch] $PassThru
    )

    if ($AddressFamily -contains 'Both')
    {
        $AddressFamily += 'IPv4', 'IPv6'
    }
    $Adapters = Get-NetAdapter -IncludeHidden:$IncludeHidden -Physical:$Physical -ErrorAction SilentlyContinue | 
    Sort-Object Status, ifIndex -Descending
    $AdapterProfileS = foreach ($Adapter in $Adapters)
    {
        if ($StatusUp -and $Adapter.Status -ne 'Up') 
        {
            continue
        }
        [array]$AddresseS = Get-NetIPAddress -InterfaceIndex $Adapter.InterfaceIndex -ErrorAction SilentlyContinue
        [array]$Ipv4AddrS = $AddresseS | Where-Object AddressFamily -EQ IPv4
        [array]$Ipv6AddrS = $AddresseS | Where-Object AddressFamily -EQ IPv6
        $IPv4AdrCsv = $IPv6AdrCsv = $null
        if ($Ipv4AddrS)
        {
            $IPv4AdrCsvS = foreach ($Ipv4Addr in $Ipv4AddrS) 
            {
                $Ipv4Addr.IPv4Address + '/' + $Ipv4Addr.PrefixLength
            }
            $IPv4AdrCsv = $IPv4AdrCsvS -join ','
        }
        if ($Ipv6AddrS)
        {
            $IPv6AdrCsv = $Ipv6AddrS.IPv6Address -join ','
        }
        if (!$AddressFamily -or ('NA' -in $AddressFamily -and (!$AddresseS)) -or ('IPv4' -in $AddressFamily -and $Ipv4AddrS) -or ('IPv6' -in $AddressFamily -and $Ipv6AddrS))
        { 
            [PSCustomObject]@{
                Name                 = $Adapter.Name
                IPv4Address          = $IPv4AdrCsv
                Status               = $Adapter.Status
                Connected            = $Adapter.MediaConnectionState
                LinkSpeed            = $Adapter.LinkSpeed
                IF                   = $Adapter.InterfaceIndex
                InterfaceDescription = $Adapter.InterfaceDescription
                # DriverFileName       = $Adapter.DriverFileName
                # DriverProvider       = $Adapter.DriverProvider
                MacAddress           = $Adapter.MacAddress
                IPv6Address          = $IPv6AdrCsv
            }
        }
    }

    if ($PassThru)
    {
        $AdapterProfileS | Write-Output
    }
    else 
    {
        $AdapterProfileS | Format-Table -AutoSize
    }
}
<## Unit test ##DD Uncomment for testing
"Gets active and hidden network adapters with their configured IP addresses."
"==== IPv4"
Get-NetAdapterAddress -AddressFamily 'IPv4' -StatusUp
"==== 6"
Get-NetAdapterAddress -AddressFamily 'IPv6' -StatusUp
"==== NA"
Get-NetAdapterAddress -AddressFamily 'NA' -StatusUp -IncludeHidden
"==== Both"
Get-NetAdapterAddress -AddressFamily 'Both'
"==== IPv4,NA"
Get-NetAdapterAddress -AddressFamily IPv4,NA -IncludeHidden
"==== IPv4,NA"
Get-NetAdapterAddress
exit
#>

Get-NetAdapterAddress @PSBoundParameters
