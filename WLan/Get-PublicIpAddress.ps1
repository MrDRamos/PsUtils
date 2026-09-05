<#
.SYNOPSIS
Gets public IP addresses observed through selected external services.

.DESCRIPTION
OpenDns reports the source of a DNS request. IpifyHttp and IpifyHttps report the
source of web requests. IpifyHttpsIpv6 tests an IPv6-only endpoint. Results can
differ when corporate policy routes each protocol through a different egress.
#>

<#
.SYNOPSIS
Defines functions for examining a Windows host's public-facing internet profile.

.DESCRIPTION
This work-in-progress script is a collection of independent diagnostic functions.
It does not run any checks automatically. Dot-source the script, then call only the
functions needed for an investigation.

Available functions examine public IPv4 and IPv6 addresses, Netskope evidence,
network adapters, default routes, DNS configuration, proxy configuration, target
name resolution, TCP connectivity, HTTP responses, and TLS certificates.

Typical paths in a corporate environment with Netskope enabled:

Method       Possible path
------       -------------
IpifyHttp    HTTP  -> Netskope proxy or corporate gateway A -> ipify
IpifyHttps   HTTPS -> Netskope tunnel/proxy or gateway B    -> ipify
OpenDns      DNS   -> Corporate/Netskope DNS path           -> OpenDNS

HTTPS protects the ipify response in transit and is preferred when only one web
method is needed. Comparing all three methods can reveal different corporate egress
paths; a difference does not necessarily mean that any result is incorrect.
#>
[CmdletBinding()]
param (
    [Parameter()]
    [ValidateSet('OpenDns', 'IpifyHttp', 'IpifyHttps', 'IpifyHttpsIpv6')]
    [string[]] $Method = @('OpenDns', 'IpifyHttp', 'IpifyHttps', 'IpifyHttpsIpv6')
)


function Get-PublicIpAddress
{
    [CmdletBinding()]
    param (
        [Parameter()]
        [ValidateSet('OpenDns', 'IpifyHttp', 'IpifyHttps', 'IpifyHttpsIpv6')]
        [string[]] $Method = @('OpenDns', 'IpifyHttp', 'IpifyHttps', 'IpifyHttpsIpv6')
    )

    $PublicAdresseS = @()
    if ($Method -contains 'OpenDns')
    {
        $PubIp = Resolve-DnsName myip.opendns.com -Server resolver1.opendns.com -Type A | Select-Object -ExpandProperty IP4Address
        $PublicAdresseS += [PSCustomObject] @{
            Method = 'OpenDns'
            Address = $PubIp
        }
    }

    if ($Method -contains 'IpifyHttp')
    {
        $PubIp = Invoke-RestMethod -Method Get -Uri 'http://api.ipify.org'
        $PublicAdresseS += [PSCustomObject] @{
            Method = 'Ipify-Http'
            Address = $PubIp
        }
    }

    if ($Method -contains 'IpifyHttps')
    {
        $PubIp = Invoke-RestMethod -Method Get -Uri 'https://api.ipify.org'
        $PublicAdresseS += [PSCustomObject] @{
            Method = 'Ipify-Https'
            Address = $PubIp
        }
    }

    if ($Method -contains 'IpifyHttpsIpv6')
    {
        try
        {
            $PubIp = Invoke-RestMethod -Method Get -Uri 'https://api6.ipify.org'
            $PublicAdresseS += [PSCustomObject] @{
                Method = 'Ipify-Https-Ipv6'
                Address = $PubIp
            }
        }
        catch {
            $PublicAdresseS += [PSCustomObject] @{
                Method = 'Ipify-Https-Ipv6'
                Address = 'Unavailable'
            }
        }
    }
    Write-Output $PublicAdresseS
}


Get-PublicIpAddress
