

<#
.SYNOPSIS
Defines functions for examining a Windows host's public-facing internet profile.
#>
[CmdletBinding()]
param (
    [Parameter()]
    [uri[]] $TargetUriS = @(
        [uri] 'https://www.example.com'
    ),

    [Parameter()]
    [switch] $PassThru
)


<#
.SYNOPSIS
Gets public IP addresses observed through selected external services.

.DESCRIPTION
OpenDns reports the source of a DNS request. IpifyHttp and IpifyHttps report the
source of web requests. IpifyHttpsIpv6 tests an IPv6-only endpoint. Results can
differ when corporate policy routes each protocol through a different egress.
#>
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


<#
.SYNOPSIS
Reports Netskope service and process evidence together with user proxy settings.

.DESCRIPTION
Collects matching Netskope services and processes and the current user's Windows
internet proxy configuration. NetskopeDetected means that at least one matching
service or process was found; it does not guarantee that every destination is
routed through Netskope.
#>
function Get-NetskopeProfile 
{
  [CmdletBinding()]
  param ()

  $NetskopeServices = Get-Service -ErrorAction SilentlyContinue |
    Where-Object {
      $_.Name -match 'Netskope|stAgent' -or
      $_.DisplayName -match 'Netskope'
    }

  $NetskopeProcesses = Get-Process -ErrorAction SilentlyContinue |
    Where-Object ProcessName -match 'Netskope|stAgent'

  $InternetSettings = Get-ItemProperty `
    'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings' `
    -ErrorAction SilentlyContinue

  [PSCustomObject]@{
    ComputerName      = $env:COMPUTERNAME
    UserName          = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
    CollectedAt       = Get-Date
    NetskopeDetected  = [bool]($NetskopeServices -or $NetskopeProcesses)
    ServiceInstalled  = [bool]$NetskopeServices
    ServiceRunning    = [bool]($NetskopeServices.Status -eq 'Running')
    ProcessRunning    = [bool]$NetskopeProcesses
    Services          = $NetskopeServices.Name -join ', '
    Processes         = $NetskopeProcesses.ProcessName -join ', '
    ProxyEnabled      = [bool]$InternetSettings.ProxyEnable
    ProxyServer       = $InternetSettings.ProxyServer
    AutoConfigURL     = $InternetSettings.AutoConfigURL
  }
}


<#
.SYNOPSIS
Gets active and hidden network adapters with their configured IP addresses.
#>
function Get-NetAdapterProfile 
{
    [CmdletBinding()]
    param (
        [Parameter()]
        [ValidateSet($null, 'NA','IPv4', 'IPv6','Both')]
        [array] $AddressFilters = @(),

        [Parameter()]
        [switch] $StatusUp
    )

    if ($AddressFilters -contains 'Both')
    {
        $AddressFilters += 'IPv4','IPv6'
    }
    $Adapters = Get-NetAdapter -IncludeHidden -ErrorAction SilentlyContinue
    foreach ($Adapter in $Adapters) {
        if ($StatusUp -and $Adapter.Status -ne 'Up') 
        {
            continue
        }
        [array]$AddresseS = Get-NetIPAddress -InterfaceIndex $Adapter.InterfaceIndex -ErrorAction SilentlyContinue
        [array]$Ipv4AddrS = $AddresseS | Where-Object AddressFamily -eq IPv4
        [array]$Ipv6AddrS = $AddresseS | Where-Object AddressFamily -eq IPv6
        $IPv4AdrCsv = $IPv6AdrCsv = $null
        if ($Ipv4AddrS)
        {
            $IPv4AdrCsv = $Ipv4AddrS.IPv4Address -join ','
        }
        if ($Ipv6AddrS)
        {
            $IPv6AdrCsv = $Ipv6AddrS.IPv6Address -join ','
        }
        if (!$AddressFilters -or ('NA' -in $AddressFilters -and (!$AddresseS)) -or ('IPv4' -in $AddressFilters -and $Ipv4AddrS) -or ('IPv6' -in $AddressFilters -and $Ipv6AddrS))
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
            IPv6Address          = $IPv6AdrCsv
            MacAddress           = $Adapter.MacAddress
            }
        }
    }
}
<## Unit test ##DD Uncomment for testing
Gets active and hidden network adapters with their configured IP addresses.
"==== IPv4"
#Get-NetAdapterProfile -AddressFilters 'IPv4' -StatusUp | Format-Table -AutoSize
"==== 6"
#Get-NetAdapterProfile -AddressFilters 'IPv6' -StatusUp | Format-Table -AutoSize
"==== NA"
#Get-NetAdapterProfile -AddressFilters 'NA' -StatusUp | Format-Table -AutoSize
"==== Both"
Get-NetAdapterProfile -AddressFilters 'Both' | Format-Table -AutoSize
"==== IPv4,NA"
Get-NetAdapterProfile -AddressFilters IPv4,NA | Format-Table -AutoSize
"==== IPv4,NA"
Get-NetAdapterProfile | Format-Table -AutoSize
exit
#>


<#
.SYNOPSIS
Gets the host's IPv4 and IPv6 default routes and their associated adapters.
#>
function Get-NetDefaultRouteProfile 
{
    [CmdletBinding()]
    param ()

    Get-NetRoute -ErrorAction SilentlyContinue |
        Where-Object DestinationPrefix -in @('0.0.0.0/0', '::/0') |
        Sort-Object AddressFamily, RouteMetric |
        ForEach-Object {
        $Adapter = Get-NetAdapter -InterfaceIndex $_.InterfaceIndex -ErrorAction SilentlyContinue
        [PSCustomObject]@{
            AddressFamily  = $_.AddressFamily
            NextHop        = $_.NextHop
            InterfaceAlias = $_.InterfaceAlias
            InterfaceIndex = $_.InterfaceIndex
            InterfaceStatus = $Adapter.Status
            RouteMetric    = $_.RouteMetric
            InterfaceMetric = $_.InterfaceMetric
            PolicyStore    = $_.PolicyStore
        }
    }
}
<## Unit test ##DD Uncomment for testing
"Gets the host's IPv4 and IPv6 default routes and their associated adapters."
Get-NetDefaultRouteProfile | FT -AutoSize
exit
#>


<#
.SYNOPSIS
Gets DNS servers and suffixes configured for each network interface.
#>
function Get-NetDnsProfile 
{
    [CmdletBinding()]
    param ()

    $GlobalDns = Get-DnsClientGlobalSetting -ErrorAction SilentlyContinue
    foreach ($DnsServer in (Get-DnsClientServerAddress -ErrorAction SilentlyContinue)) {
        $DnsClient = Get-DnsClient -InterfaceIndex $DnsServer.InterfaceIndex -ErrorAction SilentlyContinue
        [PSCustomObject]@{
        InterfaceAlias  = $DnsServer.InterfaceAlias
        ServerAddresses = @($DnsServer.ServerAddresses)
        ConnectionSuffix = $DnsClient.ConnectionSpecificSuffix
        SuffixSearchList = @($GlobalDns.SuffixSearchList)
        InterfaceIndex  = $DnsServer.InterfaceIndex
        AddressFamily   = $DnsServer.AddressFamily
        }
    }
}
<## Unit test ##DD Uncomment for testing
"Gets DNS servers and suffixes configured for each network interface."
$DnsProfile = Get-NetDnsProfile
$DnsProfile | Format-Table -AutoSize
$DnsProfile | Where-Object InterfaceAlias -eq 'Wi-Fi' | Format-List -Property *
exit
#>


<#
.SYNOPSIS
Gets WinINET, environment-variable, and WinHTTP proxy configuration.

.DESCRIPTION
Reports three independent proxy configuration sources. Windows does not combine
them into one system-wide effective proxy, and there is no universal override
order between them. The application and networking API determine which source is
used, and an application can also supply its own proxy configuration.

WinINET values come from the current user's Internet Settings registry key. They
commonly affect applications that use WinINET or Windows Internet Options.

HTTP_PROXY, HTTPS_PROXY, ALL_PROXY, and NO_PROXY are conventions honored by many
command-line and cross-platform tools, but not by every Windows application. A
tool commonly prefers the protocol-specific variable, uses ALL_PROXY as a
fallback, and excludes NO_PROXY destinations; the exact behavior is tool-specific.

WinHTTP has separate default and advanced configuration and is commonly used by
Windows services and applications built on the WinHTTP API. An application may
override the default for its own WinHTTP session. Advanced settings can select a
named proxy, PAC URL, or automatic detection and can be scoped per user or machine.

Matching values between sources can result from policy, import, or shared user
configuration and do not establish a general precedence rule. Transparent
Netskope steering, a VPN, or an upstream network proxy may affect traffic without
appearing in any of these sources.
#>
function Get-NetProxyProfile 
{
    [CmdletBinding()]
    param ()

    $WinInetProxyEnabled = $null
    $WinInetAutoDetect = $null
    $WinInetCfg = Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings' -ErrorAction SilentlyContinue
    if ($WinInetCfg) 
    {
        if ($null -ne $WinInetCfg.ProxyEnable) 
        {
            $WinInetProxyEnabled = [bool]$WinInetCfg.ProxyEnable
        }
        if ($null -ne $WinInetCfg.AutoDetect) 
        {
            $WinInetAutoDetect = [bool]$WinInetCfg.AutoDetect
        }
    }

    $WinHttpNetshError = $null
    # Get Default & Advanced HTTP proxy settings. Also see: Get-WinhttpProxy() instead: of netsh winhttp
    try
    {
        $ProxyLineS = ((netsh winhttp show proxy 2>&1 -Split "`n") -match '\w') | Select-Object -Skip 1 | ForEach-Object { $_.Trim() }
        if ($LASTEXITCODE -ne 0) {
            throw "netsh winhttp show proxy, Command failed with exit code: $LASTEXITCODE."
        }        
        $DefaultProxyServer = $ProxyLineS | Where-Object { $_ -match 'Proxy Server\(' } | ForEach-Object { ($_ -split ':',2)[1].Trim() }
        $DefaultBypassList = ($ProxyLineS | Where-Object { $_ -match 'Bypass List' } | ForEach-Object { ($_ -split ':',2)[1].Trim() })
        $DefaultDirectAccess= @($ProxyLineS | Where-Object { $_ -match 'Direct access ' }).Count -gt 0
    }
    catch
    {
        $WinHttpNetshError = $_.Exception.Message + " "
        $DefaultProxyServer = $null
        $DefaultBypassList = $null
        $DefaultDirectAccess = $null
    }

    try 
    {
        $AdvOutput = (netsh winhttp show advproxy 2>&1 -Split "`n") -match '\w|\{|\}'
        if ($LASTEXITCODE -eq 0) 
        {
            $AdvProxyCfg = $AdvOutput | Select-Object -Skip 1 | ConvertFrom-Json
        }
        else 
        {
            throw "netsh winhttp show advproxy, Command failed with exit code: $LASTEXITCODE."
        }
    }
    catch 
    {
        $WinHttpNetshError = $WinHttpNetshError + $_.Exception.Message
        $AdvProxyCfg = [PSCustomObject]@{
            Proxy              = $null
            ProxyBypass        = $null
            ProxyIsEnabled     = $null
            AutoConfigIsEnabled= $null
            AutoConfigUrl      = $null
            AutoDetect         = $null
            PerUserProxySettings= $null
        }
    }

    $ProxyProfile = [PSCustomObject]@{
        WinInetProxyEnabled     = $WinInetProxyEnabled
        WinInetProxyServer      = $WinInetCfg.ProxyServer
        WinInetAutoConfigUrl    = $WinInetCfg.AutoConfigURL
        WinInetAutoDetect       = $WinInetAutoDetect
        EnvironmentHttpProxy    = $ENV:HTTP_PROXY
        EnvironmentHttpsProxy   = $ENV:HTTPS_PROXY
        EnvironmentAllProxy     = $ENV:ALL_PROXY
        EnvironmentNoProxy      = $ENV:NO_PROXY
        WinHttpDefaultProxyServer  = $DefaultProxyServer
        WinHttpDefaultBypassList   = $DefaultBypassList
        WinHttpDefaultDirectAccess = $DefaultDirectAccess
        WinHttpAdvProxy            = $AdvProxyCfg.Proxy
        WinHttpAdvProxyBypassList  = $AdvProxyCfg.ProxyBypass
        WinHttpAdvProxyIsEnabled   = $AdvProxyCfg.ProxyIsEnabled
        WinHttpAdvAutoConfigEnabled= $AdvProxyCfg.AutoConfigIsEnabled
        WinHttpAdvAutoConfigUrl    = $AdvProxyCfg.AutoConfigUrl
        WinHttpAdvAutoDetect       = $AdvProxyCfg.AutoDetect
        WinHttpAdvPerUserProxy     = $AdvProxyCfg.PerUserProxySettings
        WinHttpErrors              = $WinHttpNetshError
    }
    return $ProxyProfile
}
<## Unit test ##DD Uncomment for testing
"Gets WinINET, environment-variable, and WinHTTP proxy configuration."
Get-NetProxyProfile | Format-List -Property *
exit
#>


<#
.SYNOPSIS
Resolves a target hostname and returns its CNAME, IPv4, and IPv6 records.
#>
function Resolve-NetTargetProfile 
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string] $HostName
    )

    $Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    try {
        $Records = Resolve-DnsName -Name $HostName -ErrorAction Stop
        $Stopwatch.Stop()
        [PSCustomObject]@{
            HostName       = $HostName
            Succeeded      = $true
            DurationMs     = $Stopwatch.ElapsedMilliseconds
            CanonicalNames = @($Records | Where-Object Type -eq CNAME | ForEach-Object NameHost) -join ', '
            IPv4Addresses  = @($Records | Where-Object Type -eq A | ForEach-Object IPAddress) -join ', '
            IPv6Addresses  = @($Records | Where-Object Type -eq AAAA | ForEach-Object IPAddress) -join ', '
            Error          = $null
        }
    }
    catch {
        $Stopwatch.Stop()
        [PSCustomObject]@{
            HostName       = $HostName
            Succeeded      = $false
            DurationMs     = $Stopwatch.ElapsedMilliseconds
            CanonicalNames = @()
            IPv4Addresses  = @()
            IPv6Addresses  = @()
            Error          = $_.Exception.Message
        }
    }
}
<## Unit test ##DD Uncomment for testing
"Resolves a target hostname and returns its CNAME, IPv4, and IPv6 records."
Resolve-NetTargetProfile -HostName "www.example.com" | Format-List -Property *
exit
#>


<#
.SYNOPSIS
Tests TCP connectivity to a target host and port.
#>
function Test-NetTargetPort 
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string] $HostName,

        [Parameter()]
        [ValidateRange(1, 65535)]
        [int] $Port = 443
    )

    $Result = Test-NetConnection -ComputerName $HostName -Port $Port -InformationLevel Detailed
    [PSCustomObject]@{
        HostName           = $HostName
        Port               = $Port
        RemoteAddress      = $Result.RemoteAddress.IPAddressToString
        ResolvedAddresses  = $Result.ResolvedAddresses.IPAddressToString -join ', '
        SourceAddress      = $Result.SourceAddress
        InterfaceAlias     = $Result.InterfaceAlias
        TcpTestSucceeded   = $Result.TcpTestSucceeded
        NameResolutionSucceeded = [bool]$Result.NameResolutionResults
    }
}
<## Unit test ##DD Uncomment for testing
"Tests TCP connectivity to a target host and port."
Test-NetTargetPort -HostName "www.example.com" -Port 443 | Format-List -Property *
exit
#>


<#
.SYNOPSIS
Tests an HTTP or HTTPS URI and reports status, redirects, and elapsed time.
#>
function Test-NetTargetUri 
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [uri] $Uri
    )

    $Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    try {
        $Response = Invoke-WebRequest -Uri $Uri -Method Head -UseBasicParsing -ErrorAction Stop
        $Stopwatch.Stop()
        $FinalUri = if ($Response.BaseResponse.RequestMessage.RequestUri) {
            $Response.BaseResponse.RequestMessage.RequestUri.AbsoluteUri
        }
        else {
            $Response.BaseResponse.ResponseUri.AbsoluteUri
        }
        [PSCustomObject]@{
            Uri          = $Uri.AbsoluteUri
            Succeeded    = $true
            StatusCode   = [int]$Response.StatusCode
            StatusText   = $Response.StatusDescription
            FinalUri     = $FinalUri
            DurationMs   = $Stopwatch.ElapsedMilliseconds
            Error        = $null
        }
    }
    catch {
        $Stopwatch.Stop()
        $StatusCode = if ($_.Exception.Response) { [int]$_.Exception.Response.StatusCode } else { $null }
        [PSCustomObject]@{
            Uri          = $Uri.AbsoluteUri
            Succeeded    = $false
            StatusCode   = $StatusCode
            StatusText   = $null
            FinalUri     = $null
            DurationMs   = $Stopwatch.ElapsedMilliseconds
            Error        = $_.Exception.Message
        }
    }
}
<## Unit test ##DD Uncomment for testing
"Tests an HTTP or HTTPS URI and reports status, redirects, and elapsed time."
Test-NetTargetUri -Uri "https://www.example.com" | Format-List -Property *
exit
#>


<#
.SYNOPSIS
Gets the TLS certificate presented during a direct connection to a host.

.DESCRIPTION
Creates a direct TLS connection and reports the presented certificate. A
transparent inspection product may replace the certificate. This check does not
use an explicitly configured HTTP proxy or PAC file.
#>
function Get-NetTlsCertificate 
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string] $HostName,

        [Parameter()]
        [ValidateRange(1, 65535)]
        [int] $Port = 443
    )

    $TcpClient = [System.Net.Sockets.TcpClient]::new()
    try {
        $TcpClient.Connect($HostName, $Port)
        $SslStream = [System.Net.Security.SslStream]::new($TcpClient.GetStream(), $false, { $true })
        try {
            $SslStream.AuthenticateAsClient($HostName)
            $Certificate = [System.Security.Cryptography.X509Certificates.X509Certificate2]::new($SslStream.RemoteCertificate)
            [PSCustomObject]@{
                HostName       = $HostName
                Port           = $Port
                Subject        = $Certificate.Subject
                Issuer         = $Certificate.Issuer
                Thumbprint     = $Certificate.Thumbprint
                NotBefore      = $Certificate.NotBefore
                NotAfter       = $Certificate.NotAfter
                Protocol       = $SslStream.SslProtocol
                SignatureAlgorithm = $Certificate.SignatureAlgorithm.FriendlyName
            }
        }
        finally {
            if ($SslStream) { $SslStream.Dispose() }
        }
    }
    finally {
        $TcpClient.Dispose()
    }
}
<# Unit test ##DD Uncomment for testing
"Gets the TLS certificate presented during a direct connection to a host."
Get-NetTlsCertificate -HostName "www.example.com" -Port 443 | Format-List -Property *
exit
#>


function ConvertTo-WanProfileHtml
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [PSCustomObject] $WanProfile
    )

    $Sections = [ordered]@{
        'Public Addresses'    = $WanProfile.PublicAddresses
        'Netskope'            = $WanProfile.Netskope
        'Network Adapters'    = $WanProfile.NetworkAdapters
        'Default Routes'      = $WanProfile.DefaultRoutes
        'DNS Configuration'   = $WanProfile.DnsConfiguration
        'Proxy Configuration' = $WanProfile.ProxyConfiguration
        'Target DNS'          = $WanProfile.TargetDns
        'Target TCP'          = $WanProfile.TargetTcp
        'Target HTTP'         = $WanProfile.TargetHttp
        'Target TLS'          = $WanProfile.TargetTls
    }

    $SectionDescriptions = @{
        'Public Addresses'    = 'These are the public IP addresses that outside services see for this computer. If an Azure firewall or access restriction uses an IP allowlist, compare its entries with the HTTPS result. Different results can mean DNS and web traffic leave through different corporate gateways.'
        'Netskope'            = 'This shows whether the Netskope client appears to be installed and running. A running client can send internet traffic through a corporate gateway, so the destination may see a Netskope public IP instead of the IP assigned by your local internet provider.'
        'Network Adapters'    = 'These are the active local network connections, including Wi-Fi, Ethernet, VPN, and virtual adapters. Look for an unexpected adapter, missing IP address, or disconnected interface that could explain why traffic is using the wrong network path.'
        'Default Routes'      = 'A default route tells Windows where to send traffic when no more specific route exists. The route with the lowest combined metrics is normally preferred. VPN or security software can add another default route and change which gateway carries internet traffic.'
        'DNS Configuration'   = 'These are the DNS servers Windows can use to translate service names into IP addresses. Problems here can cause a hostname to fail, resolve slowly, or resolve to a private or unexpected address even when general internet connectivity works.'
        'Proxy Configuration' = 'These settings can send web requests through a proxy or PAC file. Browsers, PowerShell, and Windows services may use different proxy sources, which explains why a portal can work in a browser while a script or application fails.'
        'Target DNS'          = 'This confirms whether each requested service name resolves and shows the returned addresses. A failed lookup points to DNS; an unexpected private address may indicate a private endpoint or corporate DNS rule that also requires access to the private network.'
        'Target TCP'          = 'This tests whether the host can open a network connection to port 443 before HTTP or authentication is involved. A failure usually points to routing, firewall, proxy, VPN, or endpoint availability rather than application credentials.'
        'Target HTTP'         = 'This makes an HTTPS request to the actual service and records its status and response time. A timeout suggests a network path problem, while a 401 or 403 proves the service was reached but authentication or an access restriction rejected the request.'
        'Target TLS'          = 'This shows the certificate presented during a direct TLS connection. An unexpected issuer can indicate HTTPS inspection by Netskope or another corporate product. Certificate errors can prevent a client from reaching the service even when TCP port 443 is open.'
    }

    $OverviewRow = $WanProfile |
        Select-Object ComputerName, UserName, CollectedAt, PowerShellVersion, TargetUris
    $OverviewProperties = $OverviewRow.PSObject.Properties | ForEach-Object {
        [PSCustomObject]@{
            Property = $_.Name
            Value    = $_.Value
        }
    }
    $Overview = $OverviewProperties | ConvertTo-Html -Fragment

    $SectionHtml = foreach ($Section in $Sections.GetEnumerator())
    {
        $Description = $SectionDescriptions[$Section.Key]
        $Rows = @($Section.Value)
        if ($Rows.Count -eq 0)
        {
            $Table = '<p class="empty">No results returned.</p>'
        }
        else
        {
            $FlatRows = foreach ($Row in $Rows)
            {
                $FlatRow = [ordered]@{}
                foreach ($Property in $Row.PSObject.Properties)
                {
                    $Value = $Property.Value
                    if ($Value -is [System.Collections.IEnumerable] -and $Value -isnot [string])
                    {
                        $Value = @($Value) -join ', '
                    }
                    $FlatRow[$Property.Name] = $Value
                }
                [PSCustomObject] $FlatRow
            }

            if ($Rows.Count -eq 1)
            {
                $PropertyRows = $FlatRows[0].PSObject.Properties | ForEach-Object {
                    [PSCustomObject]@{
                        Property = $_.Name
                        Value    = $_.Value
                    }
                }
                $Table = $PropertyRows | ConvertTo-Html -Fragment
            }
            else
            {
                $Table = $FlatRows | ConvertTo-Html -Fragment
            }
        }

        "<section><h2>$($Section.Key)</h2><p class='section-description'>$Description</p><div class='table-wrap'>$Table</div></section>"
    }

    $Style = @'
<style>
    :root { color-scheme: light; font-family: Aptos, "Segoe UI", sans-serif; }
    body { margin: 0; color: #17202a; background: #eef2f5; }
    header { padding: 28px 36px; color: white; background: #174b63; }
    h1 { margin: 0 0 6px; font-size: 28px; font-weight: 650; }
    header p { margin: 0; color: #d8e8ef; }
    main { max-width: 1500px; margin: 0 auto; padding: 24px; }
    section { margin-bottom: 22px; padding: 18px; background: white; border: 1px solid #d5dde2; border-radius: 6px; }
    h2 { margin: 0 0 14px; color: #174b63; font-size: 19px; }
    .section-description { max-width: 1050px; margin: -4px 0 16px; color: #4d5f68; font-size: 14px; line-height: 1.5; }
    .table-wrap { overflow-x: auto; }
    table { width: 100%; border-collapse: collapse; font-size: 13px; }
    th { padding: 9px 10px; color: white; background: #32677d; text-align: left; white-space: nowrap; }
    td { padding: 8px 10px; border-bottom: 1px solid #e3e8eb; vertical-align: top; }
    tr:nth-child(even) td { background: #f6f8f9; }
    .empty { margin: 0; color: #66757d; font-style: italic; }
</style>
'@

    $Body = @"
<header>
    <h1>Internet Diagnostics</h1>
    <p>$($WanProfile.ComputerName) &middot; Collected $($WanProfile.CollectedAt)</p>
</header>
<main>
    <section><h2>Overview</h2><p class='section-description'>This identifies the computer, user, collection time, PowerShell version, and requested target URLs for this report. Keep it with diagnostic results so you know which host, session, and internet services produced the data.</p><div class='table-wrap'>$Overview</div></section>
    $($SectionHtml -join "`n")
</main>
"@

    ConvertTo-Html -Title "Internet Diagnostics - $($WanProfile.ComputerName)" -Head $Style -Body $Body
}


############################ Main ############################

$TargetHostS = @($TargetUriS.DnsSafeHost | Sort-Object -Unique)
$PublicIpMethodS = @('OpenDns', 'IpifyHttp', 'IpifyHttps', 'IpifyHttpsIpv6')

$WanProfile = [PSCustomObject]@{
    ComputerName      = $env:COMPUTERNAME
    UserName          = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
    CollectedAt       = Get-Date
    PowerShellVersion = $PSVersionTable.PSVersion.ToString()
    TargetUris        = $TargetUriS.AbsoluteUri -join ', '
    PublicAddresses   = @(Get-PublicIpAddress -Method $PublicIpMethodS)
    Netskope          = Get-NetskopeProfile
    NetworkAdapters   = @(Get-NetAdapterProfile -StatusUp)
    DefaultRoutes     = @(Get-NetDefaultRouteProfile)
    DnsConfiguration = @(Get-NetDnsProfile)
    ProxyConfiguration = Get-NetProxyProfile
    TargetDns         = @($TargetHostS | ForEach-Object { Resolve-NetTargetProfile -HostName $_ })
    TargetTcp         = @($TargetHostS | ForEach-Object { Test-NetTargetPort -HostName $_ -Port 443 })
    TargetHttp        = @($TargetUriS | ForEach-Object { Test-NetTargetUri -Uri $_ })
    TargetTls         = @($TargetHostS | ForEach-Object { Get-NetTlsCertificate -HostName $_ -Port 443 })
}

if ($PassThru)
{
    $WanProfile
}
else
{
    $HtmlPath = Join-Path ([System.IO.Path]::GetTempPath()) "InternetDiagnostics-$($env:COMPUTERNAME)-$(Get-Date -Format 'yyyyMMdd-HHmmss').html"
    ConvertTo-WanProfileHtml -WanProfile $WanProfile | Set-Content -Path $HtmlPath -Encoding utf8
    Start-Process -FilePath $HtmlPath | Out-Null
    Write-Output $HtmlPath
}

