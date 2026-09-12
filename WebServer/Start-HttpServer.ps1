<#
.SYNOPSIS
    Starts a simple static HTTP server for a local directory.
    With the same behavior as Python's simple HTTP server (http.server).

.DESCRIPTION
    Starts a lightweight static file server using the built-in .NET HttpListener class,
    with behavior similar to Python's `python -m http.server` command. No additional
    packages or web framework are required.

    The server serves files below SiteRoot, returns index.html for directory URLs when
    present, and generates a directory listing when no index.html exists. It supports
    GET and HEAD requests, common content types, directory redirects, and conditional
    caching with Last-Modified and If-Modified-Since. Missing paths and requests that
    resolve outside SiteRoot return 404.

    By default, the server listens on all network interfaces at port 8000, similar to
    Python's http.server. Use LocalOnly to restrict access to this computer at
    http://localhost:8000/. LAN access requires an elevated PowerShell session and an
    enabled inbound Windows Firewall rule for the selected TCP port.

    This script is intended for local development, testing, demonstrations, and quick
    file sharing. It is not intended to replace a production web server.

.PARAMETER SiteRoot
    The root directory of the site to serve. Defaults to the directory containing this script.

.PARAMETER Port
    The port on which the server will listen. Defaults to 8000.

.PARAMETER LocalOnly
    Restricts the listener to localhost. Without this switch, the server listens on all
    network interfaces and requires elevation plus an inbound Windows Firewall rule.

.EXAMPLE
    .\Start-HttpServer.ps1

    Serves the directory containing this script at port 8000 on all network interfaces.

.EXAMPLE
    .\Start-HttpServer.ps1 -SiteRoot 'C:\Websites\Example' -Port 8080

    Serves the specified directory at port 8080 on all network interfaces.

.EXAMPLE
    .\Start-HttpServer.ps1 -LocalOnly

    Serves the directory containing this script only to this computer at http://localhost:8000/.

.EXAMPLE
    http://localhost:8000/assets/

    After starting the server, opens the assets directory. The folder path comes after
    the port: http://host:port/folder/.

.NOTES
    Press Ctrl+C to stop the server.
#>
[CmdletBinding()]
param(
    [string]$SiteRoot = $null,

    [ValidateRange(1, 65535)]
    [int]$Port = 8000,

    [switch]$LocalOnly
)


#Region Helper Functions
function Get-LocalLanAddress
{
    [array]$LanAddresseS = $null
    foreach ($Adapter in (Get-NetAdapter | Where-Object Status -EQ 'Up'))
    {
        [array]$IpAddresseS = Get-NetIPAddress -InterfaceIndex $Adapter.ifIndex -AddressFamily IPv4 | 
            Where-Object { $_.IPAddress -notlike '127.*' -and $_.IPAddress -notlike '169.254.*' }
        foreach ($IpAddress in $IpAddresseS)
        {
            $LanAddresseS += [PsCustomObject]@{ AdapterName = $Adapter.Name; IpAddress = $IpAddress.IpAddress }
        }
    }
    return $LanAddresseS

<#
    $AdapterIndexeS = Get-NetAdapter | Where-Object Status -eq 'Up' | Select-Object -ExpandProperty ifIndex
    Get-NetIPAddress -AddressFamily IPv4 | Where-Object {
            $_.InterfaceIndex -in $AdapterIndexeS -and
            $_.IPAddress -notlike '127.*' -and
            $_.IPAddress -notlike '169.254.*'
        } | Select-Object -ExpandProperty IPAddress
#>
}
<## Unit Test
Get-LocalLanAddress
exit
#>

function Test-IsAdministrator
{
    $currentIdentity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $currentPrincipal = [Security.Principal.WindowsPrincipal]::new($currentIdentity)
    return $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}


function Test-LanFirewallPortOpen
{
    param(
        [int]$Port
    )

    $activeProfiles = Get-NetConnectionProfile |
        Where-Object { $_.IPv4Connectivity -ne 'Disconnected' } |
        Select-Object -ExpandProperty NetworkCategory -Unique

    $allowedRules = foreach ($rule in (Get-NetFirewallRule -Enabled True -Direction Inbound -Action Allow))
    {
        if ($rule.Profile -eq 'Any' -or $activeProfiles | Where-Object { $_ -in $rule.Profile })
        {
            $rule
        }
    }

    foreach ($rule in $allowedRules)
    {
        $portFilters = Get-NetFirewallPortFilter -AssociatedNetFirewallRule $rule
        if ($portFilters | Where-Object {
                $_.Protocol -eq 'TCP' -and
                ($_.LocalPort -eq 'Any' -or $_.LocalPort -eq $Port)
            })
        {
            return $true
        }
    }

    return $false
}


function Get-DirectoryListingHtml
{
    param(
        [string]$DirectoryPath,
        [string]$RequestPath
    )

    $displayPath = "/$($RequestPath.Trim('/'))/" -replace '^//$', '/'
    $encodedPath = [System.Net.WebUtility]::HtmlEncode($displayPath)
    $listing = [System.Text.StringBuilder]::new()
    [void]$listing.AppendLine('<!DOCTYPE html>')
    [void]$listing.AppendLine("<html><head><meta charset='utf-8'><title>Directory listing for $encodedPath</title></head><body>")
    [void]$listing.AppendLine("<h1>Directory listing for $encodedPath</h1><hr><ul>")

    if ($RequestPath.Trim('/'))
    {
        [void]$listing.AppendLine("<li><a href='../'>../</a></li>")
    }

    foreach ($entry in (Get-ChildItem -LiteralPath $DirectoryPath -Force | Sort-Object Name))
    {
        $suffix = if ($entry.PSIsContainer) { '/' } else { '' }
        $href = [System.Uri]::EscapeDataString($entry.Name) + $suffix
        $name = [System.Net.WebUtility]::HtmlEncode($entry.Name + $suffix)
        [void]$listing.AppendLine("<li><a href='$href'>$name</a></li>")
    }

    [void]$listing.AppendLine('</ul><hr></body></html>')
    return $listing.ToString()
}


function Get-ContentType
{
    param(
        [string]$FilePath
    )

    $extension = [System.IO.Path]::GetExtension($FilePath).ToLowerInvariant()
    if ([string]::IsNullOrEmpty($extension))
    {
        return 'application/octet-stream'
    }

    $registeredContentType = [Microsoft.Win32.Registry]::GetValue("HKEY_CLASSES_ROOT\$extension", 'Content Type', $null)
    if ($registeredContentType)
    {
        return $registeredContentType
    }

    $fallbackContentTypes = @{
        '.avif' = 'image/avif'
        '.bmp'  = 'image/bmp'
        '.css'  = 'text/css; charset=utf-8'
        '.csv'  = 'text/csv; charset=utf-8'
        '.gif'  = 'image/gif'
        '.htm'  = 'text/html; charset=utf-8'
        '.html' = 'text/html; charset=utf-8'
        '.ico'  = 'image/x-icon'
        '.jpeg' = 'image/jpeg'
        '.jpg'  = 'image/jpeg'
        '.js'   = 'text/javascript; charset=utf-8'
        '.json' = 'application/json; charset=utf-8'
        '.map'  = 'application/json; charset=utf-8'
        '.mjs'  = 'text/javascript; charset=utf-8'
        '.mp3'  = 'audio/mpeg'
        '.mp4'  = 'video/mp4'
        '.ogg'  = 'audio/ogg'
        '.ogv'  = 'video/ogg'
        '.pdf'  = 'application/pdf'
        '.png'  = 'image/png'
        '.txt'  = 'text/plain; charset=utf-8'
        '.wasm' = 'application/wasm'
        '.wav'  = 'audio/wav'
        '.webm' = 'video/webm'
        '.webp' = 'image/webp'
        '.woff' = 'font/woff'
        '.woff2' = 'font/woff2'
        '.xml'  = 'application/xml; charset=utf-8'
    }

    return $fallbackContentTypes[$extension] ?? 'application/octet-stream'
}
#EndRegion Helper Functions

#Region Initialization
if (-not $LocalOnly)
{
    if (!(Test-IsAdministrator))
    {
        @"
LAN access requires an elevated PowerShell session. 
Try again in an elevated PowerShell session (Run as Administrator)'. 
To serve this computer only, run '.\Start-HttpServer.ps1 -LocalOnly'.
"@ | Write-Host -ForegroundColor Red
        exit 1
    }

    if (!(Test-LanFirewallPortOpen -Port $Port))
    {
        @"
Windows Firewall does not allow inbound TCP traffic on port $Port for the active network profile.
Run this command in an elevated PowerShell session, then start the server again:
New-NetFirewallRule -DisplayName 'Allow inbound TCP traffic' -Direction Inbound -Action Allow -Protocol TCP -LocalPort $Port -Profile Private
"@ | Write-Host -ForegroundColor Red
        exit 1
    }
}

if ([string]::IsNullOrWhiteSpace($SiteRoot))
{
    $SiteRoot = $PSScriptRoot
}
if (-not (Test-Path -LiteralPath $SiteRoot -PathType Container))
{
    Write-Host "Site root '$SiteRoot' is not an existing directory." -ForegroundColor Red
    exit 1
}

$siteRoot = (Resolve-Path -LiteralPath $SiteRoot).Path
$siteRootPrefix = $siteRoot.TrimEnd([System.IO.Path]::DirectorySeparatorChar) + [System.IO.Path]::DirectorySeparatorChar

$listener = [System.Net.HttpListener]::new()
$hostName = if ($LocalOnly) { 'localhost' } else { '+' }
$listener.Prefixes.Add("http://${hostName}:$Port/")
#EndRegion Initialization

try 
{
    #Region Server Setup
    try 
    {
        $listener.Start()
    }
    catch 
    {
        throw "Failed to start the server on port $Port. $($_.Exception.Message)"
    }

    Write-Host "Serving $siteRoot" -ForegroundColor Cyan
    if (-not $LocalOnly)
    {
        [array]$LanAddresseS = Get-LocalLanAddress
        if ($LanAddresseS.Count -eq 1) 
        {
            Write-Host "Open http://$($LanAddresseS[0].IpAddress):$Port/"
        }
        elseif ($LanAddresseS.Count -gt 1) 
        {
            Write-Host 'Open one of these LAN addresses:'
            foreach ($LanAddress in $LanAddresseS) 
            {
                Write-Host ("{0,-30} - {1}" -f "http://$($LanAddress.IpAddress):$Port/", $LanAddress.AdapterName)
            }
        }
        else 
        {
            Write-Host "Open http://localhost:$Port/ locally. No active physical IPv4 LAN address was found."
        }
    }
    else 
    {
        Write-Host "Open http://localhost:$Port/"
    }
    Write-Host 'Press Ctrl+C to stop the server.' -ForegroundColor Cyan
    #EndRegion Server Setup

    #Region Request Handling
    while ($listener.IsListening) 
    {
        # https://learn.microsoft.com/en-us/dotnet/api/system.net.httplistener.begingetcontext
        $pendingContext = $listener.BeginGetContext($null, $null)
        try 
        {
            while (-not $pendingContext.AsyncWaitHandle.WaitOne(200)) 
            {
                # Return to PowerShell regularly so Ctrl+C can interrupt the script.
            }
            $context = $listener.EndGetContext($pendingContext)
        }
        finally 
        {
            $pendingContext.AsyncWaitHandle.Dispose()
        }

        if ($VerbosePreference -eq 'Continue') 
        {
            Write-Host "Received request from $($context.Request.RemoteEndPoint): $($context.Request.HttpMethod) $($context.Request.Url.AbsolutePath)"
        }
        $requestPath = [System.Uri]::UnescapeDataString($context.Request.Url.AbsolutePath).TrimStart('/')
        $filePath = [System.IO.Path]::GetFullPath((Join-Path $siteRoot $requestPath))
        $isWithinSiteRoot = $filePath -eq $siteRoot -or $filePath.StartsWith($siteRootPrefix, [System.StringComparison]::OrdinalIgnoreCase)
        if (!$isWithinSiteRoot -or !(Test-Path -LiteralPath $filePath))
        {
            $context.Response.StatusCode = 404
            $body = [System.Text.Encoding]::UTF8.GetBytes('Not found')
            $context.Response.ContentType = 'text/plain; charset=utf-8'
            $context.Response.ContentLength64 = $body.Length
            if ($context.Request.HttpMethod -ne 'HEAD')
            {
                $context.Response.OutputStream.Write($body, 0, $body.Length)
            }
            $context.Response.Close()
            continue
        }

        if (Test-Path -LiteralPath $filePath -PathType Container)
        {
            if (-not $context.Request.Url.AbsolutePath.EndsWith('/'))
            {
                $context.Response.StatusCode = 301
                $context.Response.RedirectLocation = $context.Request.Url.AbsolutePath + '/' + $context.Request.Url.Query
                $context.Response.Close()
                continue
            }

            $indexPath = Join-Path $filePath 'index.html'
            if (Test-Path -LiteralPath $indexPath -PathType Leaf)
            {
                $filePath = $indexPath
            }
            else
            {
                $body = [System.Text.Encoding]::UTF8.GetBytes((Get-DirectoryListingHtml -DirectoryPath $filePath -RequestPath $requestPath))
                $context.Response.ContentType = 'text/html; charset=utf-8'
                $context.Response.ContentLength64 = $body.Length
                if ($context.Request.HttpMethod -ne 'HEAD')
                {
                    $context.Response.OutputStream.Write($body, 0, $body.Length)
                }
                $context.Response.Close()
                continue
            }
        }

        $context.Response.ContentType = Get-ContentType -FilePath $filePath
        $fileInfo = Get-Item -LiteralPath $filePath
        $lastModifiedUtc = $fileInfo.LastWriteTimeUtc.AddTicks(-($fileInfo.LastWriteTimeUtc.Ticks % [TimeSpan]::TicksPerSecond))
        $context.Response.Headers['Last-Modified'] = $lastModifiedUtc.ToString('R')
        $ifModifiedSince = $context.Request.Headers['If-Modified-Since']
        $requestedModifiedTime = [DateTime]::MinValue
        if ($ifModifiedSince -and [DateTime]::TryParse($ifModifiedSince, [ref]$requestedModifiedTime) -and $lastModifiedUtc -le $requestedModifiedTime.ToUniversalTime())
        {
            $context.Response.StatusCode = 304
            $context.Response.Close()
            continue
        }

        $bytes = [System.IO.File]::ReadAllBytes($filePath)
        $context.Response.ContentLength64 = $bytes.Length
        if ($context.Request.HttpMethod -ne 'HEAD')
        {
            $context.Response.OutputStream.Write($bytes, 0, $bytes.Length)
        }
        $context.Response.Close()
    }
    #EndRegion Request Handling
}
finally 
{
    if ($listener.IsListening) 
    {
        $listener.Stop()
    }
    $listener.Close()
}

