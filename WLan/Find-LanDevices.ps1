
param
(
    [Parameter()]
    [int] $Range = 255,

    [Parameter()]
    [int] $InterfaceIndex = $null,

    [Parameter()]
    [switch] $ResolveDnsName

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
    $IPAddrObj = [System.Net.IPAddress]$ActiveIp.IPAddress
    $MaskBits = 32 - $ActiveIp.PrefixLength
    $AddrRange = [Math]::Pow(2, 32 - $ActiveIp.PrefixLength)

    $NetAddr = [System.Net.IPAddress]::HostToNetworkOrder([Int32]$IPAddrObj.Address)
    $MaskPow = 1 + [math]::Log($MaskBits, 2)
    $BaseAddr = $NetAddr -shr $MaskPow -shl $MaskPow
    #$BaseAddr = [System.Net.IPAddress]::NetworkToHostOrder($NetAddr)

#    $NetIpS = 1..$AddrRange | ForEach-Object { [System.Net.IPAddress]::NetworkToHostOrder($BaseAddr + $_) }
    $NetIpS = 1..130 | ForEach-Object { [System.Net.IPAddress]::NetworkToHostOrder($BaseAddr + $_) }
    $NetIpS | ForEach-Object { ([System.Net.IPAddress]$_).IPAddressToString }
    #$NetIpS | ForEach-Object { [System.Net.IPAddress]($_).ToString()}
    return



    $MaskLen = [math]::Max($MaskLen, 3)
    $BaseAddress = ($ActiveIp -split "\.")[1..$MaskLen] -join "."
    if (!$Range)
    {
        $Range = (4 - $MaskLen) * 256
    }
    
    $IpRange = 1..$Range | ForEach-Object { "$BaseAddress`.$_" }
    $Result = & $PSScriptRoot\Test-LanIP.ps1 -IP $IpRange

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



