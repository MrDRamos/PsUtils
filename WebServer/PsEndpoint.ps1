
#region Helper functions

function Write-Log
{
    [CmdletBinding()]
    param (
        [Parameter(ValueFromPipeline)]
        [array] $Message,

        [Parameter()]
        [string] $Level = 'Info',


        [Parameter()]
        [string] $ForegroundColor = 'Gray'
    )

    # $Input is an automatic variable that references the pipeline value
    if ($Input)
    {
        $InputMsg = $Input -join "`n"
    }
    else 
    {
        $InputMsg = $Message -join "`n"
    }

    $LogStr = ''
    if ($Script:G_LogNoNewLine)
    {
        $LogStr = "`n"    
    }
    $LogStr += '[' + (Get-Date).ToString('yyyy-MM-dd][HH:mm:ss.fffzz') + '][' + $ENV:COMPUTERNAME + '][WebService][' + $Pid + '][' + $Level + ']  ' + $InputMsg

    if ($Level -eq 'Error')
    {
        Write-Host $LogStr -ForegroundColor Red
    }
    elseif ($Level -eq 'Warning')
    {
        Write-Host $LogStr -ForegroundColor Yellow
    }
    else 
    {
        Write-Host $LogStr -ForegroundColor $ForegroundColor
    }
}

#endregion Helper functions

#region Security

<#
.SYNOPSIS
Retrieve firewall rules associated with port 80
#>
function Get-FirewallPortRules([int] $Port = 80, [switch] $IncludeSystemApps)
{
    $PortFilterS = Get-NetFirewallPortFilter -Protocol TCP | Where-Object -Property LocalPort -EQ $Port
    $PortRuleS = $PortFilterS | Get-NetFirewallRule
    if (!$IncludeSystemApps)
    {
        $PortRuleS = $PortRuleS | Where-Object { Get-NetFirewallApplicationFilter -AssociatedNetFirewallRule $_ | 
            Where-Object -Property Program -EQ 'Any' }
    }
    return $PortRuleS
}

<#
#>
function Enable-FirewallWebServiceRule([int] $Port = 80, [string] $Name = 'Allow Web-Service on port 80', [array] $Profile = @('Private', 'Domain'))
{
    [array]$PortRuleS = Get-FirewallPortRules -Port $Port
    if ($PortRuleS)
    {
        $FoundRule = $PortRuleS[0]
        [array]$NamedRule = $PortRuleS | Where-Object { $_.DisplayName -eq $Name }
        if ($NamedRule)
        {
            $FoundRule = $NamedRule[0]
        }
        Enable-NetFirewallRule -InputObject $FoundRule
    }
    else 
    {
        $null = New-NetFirewallRule -DisplayName $Name -Direction Inbound -Protocol TCP -LocalPort $Port -Action Allow -Profile $Profile
    }
}
<# Unit test
Enable-FirewallWebServiceRule
exit
#>


<#
Parses the output of: netsh http show urlacl
Returns an array of [PSCustomObject[]] with these properties:
    [string] URL 
    [string] User
    [bool]   Listen
    [bool]   Delegate
    [string] SDDL

    
#>
function Get-UrlReservation
{
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param (
        [Parameter()]
        [string]$User = ''
    )


    $UrlReservationS = @()
    $UrlAclS = @()
    $InUrlSection = $false
    $LineS = netsh http show urlacl
    foreach ($Line in $LineS) 
    {
        if ([string]::IsNullOrWhiteSpace($Line))
        {
            $InUrlSection = $false
            if ($UrlAclS)
            {
                $UserAclS = $UrlAclS | Where-Object { $_.User -match $User }
                if ($UserAclS)
                {
                    $UrlReservationS += $UserAclS
                }
                $UrlAclS = @()
            }
        }
        elseif ($Line -match 'Reserved URL\s+: (\S+)')
        {
            $InUrlSection = $true
            $UrlAcl = [PSCustomObject]@{
                URL      = $matches[1]
                User     = $null
                Listen   = $false
                Delegate = $false
                SDDL     = $null
            }
            $UrlAclS += $UrlAcl
        }
        elseif ($InUrlSection)
        {
            if ($Line -match 'User: (\S+)')
            {
                if ($UrlAcl.User)
                {
                    $UrlAcl = $UrlAcl.PsObject.Copy()
                    $UrlAcl.User = $matches[1]
                    $UrlAclS += $UrlAcl
                }
                else 
                {
                    $UrlAcl.User = $matches[1]
                }
            }
            elseif ($Line -match 'Listen: (\S+)')
            {
                $UrlAcl.Listen = $matches[1] -eq 'Yes'
            }
            elseif ($Line -match 'Delegate: (\S+)')
            {
                $UrlAcl.Delegate = $matches[1] -eq 'Yes'
            }
            elseif ($Line -match 'SDDL: (\S+)')
            {
                $UrlAcl.SDDL = $matches[1]
            }
        }
    }
    return $UrlReservationS
}
<# Unit test
Get-UrlReservation | ft
Get-UrlReservation -User $Env:USERNAME | ft
exit
#>

#endregion Security

#region WebApi functions

<#
This code example returns the user information for a client request
#>
function Get-ClientAuthenticationMessage([System.Net.HttpListenerContext] $Context)
{
    [System.Security.Principal.IPrincipal] $User = $Context.User;
    if (!$User -or !$User.Identity)
    {
        return "Client authentication is not enabled for this Web server.";
    }

    $Retval = ""
    [System.Security.Principal.IIdentity] $Id = $User.Identity;
    if ($Id.IsAuthenticated)
    {
        $Retval = "$($Id.Name) was authenticated using $($Id.AuthenticationType)"
        if ($Id.AuthenticationType -eq "Basic")
        {
            $Retval += " Password=$($Id.Password)"
        }
    }
    else
    {
        $Retval = "$($Id.Name) was not authenticated"
    }
    return $Retval
}


<#
.SYNOPSIS
Configure how the listener authenticates incoming requests.

.PARAMETER SchemeS
One or more [System.Net.AuthenticationSchemes] 
[enum]::GetNames([System.Net.AuthenticationSchemes])
    None
    Digest
    Negotiate
    Ntlm
    IntegratedWindowsAuthentication
    Basic
    Anonymous

-Anonymous
    No Authentication i.e. The endpoint will accept any client connection
    The endpoint call needs no credentials

-Basic
    Use Basic Authentication: Username:Password
    Example CallL
        $UserName = "LetMeIn"; $Password = "TopSecret"

        $BasicAuthB64 = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("$($UserName):$($Password)"))
        $Header = @{ Authorization = "Basic $BasicAuthB64" }
        Invoke-RestMethod -Uri "http://${HostName}/" -header $Header
            or
        Cred = [pscredential]::new($UserName, (ConvertTo-SecureString $Password -AsPlainText -Force))  
        Invoke-RestMethod -Uri "http://${HostName}/" -Credential $Cred -AllowUnencryptedAuthentication

-IntegratedWindowsAuthentication
    For Intranet environment only: Use Kerberos or NTLM to authenticated user
    Invoke-RestMethod -Uri "http://${HostName}/" -UseDefaultCredentials -AllowUnencryptedAuthentication
#>
function Set-AuthenticationSchema([System.Net.HttpListener] $Listener, [System.Net.AuthenticationSchemes[]] $SchemeS = '-Anonymous')
{
    if ($SchemeS)
    {
        $Listener.AuthenticationSchemes = $SchemeS
    }
}


<#
.SYNOPSIS
$PrefixeS = @("http://localhost:80/")              # -> irm "http://localhost/"
$PrefixeS = @("http://localhost:8080/")            # -> irm "http://localhost:8080/"
$PrefixeS = @("http://$($env:COMPUTERNAME):8080/") # -> irm "http://<ComputerName>:8080/"
#PrefixeS = @("http://$($env:COMPUTERNAME):80/")   # Port 80 requires app to run as Administrator
#PrefixeS = @("http://+:80/")                      # use localhost | ipaddress | computername
$PrefixeS = @("http://+:8080/test/")               # -> irm "http://localhost:8080/test"

.NOTES
Remote computers will not be able to access the service unless a firewall rule to enable incoming access to the port is created.
New-NetFirewallRule -DisplayName "Allow Port 80" -Direction Inbound -Protocol TCP -LocalPort 80 -Action Allow -Profile @('Private', 'Domain')

.LINK
HTTPS support: https://stackoverflow.com/questions/11403333/httplistener-with-https-support/11457719#11457719

Routing Incoming Requests
https://learn.microsoft.com/en-us/windows/win32/http/routing-incoming-requests
#>
function Add-LocalUrlPrefix([System.Net.HttpListener] $Listener, [string[]]$PrefixeS = "http://+:80/", [string] $LocalUrlPath)
{
    foreach ($Prefix in $PrefixeS) 
    {        
        $FullPrefix = $Prefix.TrimEnd('/') + '/'
        if ($LocalUrlPath)
        {
            $FullPrefix = $FullPrefix + $LocalUrlPath.TrimEnd('/') + '/'
        }        
        $Listener.Prefixes.Add($FullPrefix)
    }
}


<#
.SYNOPSIS
Extracts the key=value pairs in the querystring of the URI into a PowerShell [hashtable] 
e.g. $QueryStr = "Country=USA&City=Boston&City=NewYork&Zipcode=11790"
    $QryParamS = @{ Country='USA'; City=@('Boston','NewYork'); Zipcode=11790 }
We return an empty @{} hashtable instead $null if the QueryStr was empty
#>
function Get-RequestQueryParams
{
    [CmdletBinding()]
    [OutputType([Hashtable])]
    param (
        [Parameter()]
        [System.Net.HttpListenerRequest] $Request
    )
    
    $QueryParamS = @{}
    if ($Request.QueryString.Count)
    {
        # Map DotNet Specialized.NameValueCollection -> [hashtable]
        $QryStr = $Request.QueryString  
        foreach ($Key in $QryStr.AllKeys) 
        {
            $Value = $QryStr.GetValues($Key)
            if ($null -eq $Key)
            {
                $Key = ''
            }
            $QueryParamS.Add($Key, $Value)
        }
    }
    return $QueryParamS
}


function Get-RequestBody
{
    [CmdletBinding()]
    param (
        [Parameter()]
        [System.Net.HttpListenerRequest] $Request
    )

    $StreamReader = [System.IO.StreamReader]::new($Request.InputStream)
    $Body = $RequestBody = $StreamReader.ReadToEnd()

    if ($Request.ContentType -match "json") # -ContentType "application/json"
    {
        $Body = $RequestBody | ConvertFrom-Json
    }
    elseif ($Request.ContentType -match "x-www-form-urlencoded")
    {
        $Body = @{}
        #multiple occurrences of the same query string parameter are listed as a single entry with a comma separating each value
        $BodyItemS = [System.Web.HttpUtility]::ParseQueryString($RequestBody)
        foreach ($Key in $BodyItemS.AllKeys)
        {
            $ValueS = $BodyItemS[$Key] -split ","
            $Body[$Key] = $ValueS
        }
    }
    Return $Body
}

#endregion WebApi functions

#region Endpoint-Handlers

function Get-Usage
{
    [CmdletBinding()]
    param (
        [Parameter()]
        [Object] $QueryParamS = @{}
    )

    if ($QueryParamS.Count)
    {
        $ReplyText = "Query Parameters:", ($QueryParamS | Format-Table | Out-String).TrimEnd()
    }
    else
    {
        $ReplyText = @"
$Script:AppName WebServer examples:
Base Uri = http://$ENV:Computername/$LocalUrlPath/

Get Help:  irm -Method Get  -Uri "http://$ENV:Computername/$LocalUrlPath"
Get ?Str:  irm -Method Get  -Uri "http://$ENV:Computername/$LocalUrlPath/?Country=USA&City=Boston&City=NewYork&Zipcode=11790"
Get Dir:   irm -Method Get  -Uri "http://$ENV:Computername/$LocalUrlPath/dir"
Get Dir:   irm -Method Get  -Uri "http://$ENV:Computername/$LocalUrlPath/dir?*.ps1"
Post Data: irm -Method Put  -Uri "http://$ENV:Computername/$LocalUrlPath/" -Body '{ "key1": "val1", "key2": "val2" }' -ContentType "application/json"
Terminate: irm -Method Post -Uri "http://$ENV:Computername/$LocalUrlPath/exit"       
"@
    }

    return @($ReplyText, 200)
}


function Get-FileList
{
    [CmdletBinding()]
    param (
        [Parameter()]
        [Object] $QueryParamS = @{}
    )

    $ReplyText = ''
    try 
    {
        $ErrorActionCtx = "retrieve $($QueryParamS.Values) files"
        if ($QueryParamS.Count)
        {
            $FileS = Get-Item -Path $QueryParamS.Values
        }
        else 
        {
            $FileS = Get-Item -Path *
        }
        $ReplyText = $FileS | Format-Table | Out-String
        #$ReplyText = $FileS | ConvertTo-Json
        #$ReplyText = $FileS | ConvertTo-Html -Property Mode, LastWriteTime, Length, Name
        
        Write-Log "Retrieved $($FileS.Count) files"
    }
    catch 
    {
        $ErrorMsg = "Failed to ${ErrorActionCtx}: $($_.Exception.Message)"
        Write-Log $ErrorMsg -Level 'Error'
        return @($ErrorMsg, 400)
    }
    
    return @($ReplyText, 200)
}

#endregion Endpoint-Handlers

############## main ##############
#region main

<######################################   MAIN  ######################################
 References:
    https://4sysops.com/archives/building-a-web-server-with-powershell/
    https://gist.github.com/Tiberriver256/868226421866ccebd2310f1073dd1a1e
    https://github.com/PowerShell/Polaris
    https://github.com/TLaborde/NodePS
######################################################################################>


<#
A request url has these segments: http://<hostname>/<LocalUrlPath><EndPoint><?QuerySting>
The listener will not process a request unless the url has these segments: http://<hostname>/<LocalUrlPath>
In this program the <LocalUrlPath> = $AppName/$AppVer
Note: $AppName, $AppVer and thus $LocalUrlPath may all be empty
#>
$AppName = 'MyWebApi'
$AppVer  = 'v1'

# Init $LocalUrlPath -> Resulting $URI= "http://$ENV:Computername/ArellaApi/v1"
$LocalUrlPath = $AppName
if (![string]::IsNullOrWhiteSpace($AppVer))
{
    $LocalUrlPath = "$AppName/$AppVer"
}
$LocalUrlPath = $LocalUrlPath.Trim(' /') # Leave out trailing /

$ErrorMsgByErrorNo = @{
    400 = '<h1>400 - Bad Request<h1>'
    404 = '<h1>404 - Page not found</h1>'
    500 = '<h1>500 - Internal Server Error</h1>'
}

$Listener = $null
try 
{
    # Set up a Listener: https://learn.microsoft.com/en-us/dotnet/api/system.net.httplistener
    $Listener = New-Object System.Net.HttpListener

    Add-LocalUrlPrefix -Listener $Listener -LocalUrlPath $LocalUrlPath
    $ListenUrlCsv = $Listener.Prefixes -join ', ' 
    $ListenUrl = $ListenUrlCsv -replace '\+\:80', $ENV:COMPUTERNAME

    <#
    To run HttpListener in non-admin mode. You need to grant the user a URL reservation with the OS.
    The netsh http add urlacl command is used to reserve a specified URL for non-administrator users and accounts.
    Example to register a specific URL: 'http://$ENV:COMPUTERNAME/MyWebsite'
        netsh http add urlacl url=http://+:80/MyWebsite user=DOMAIN\user
    Example to register any URL on port 80
        netsh http add urlacl url=http://+:80 user=DOMAIN\user
    
    netsh http add urlacl:
    https://learn.microsoft.com/en-us/windows-server/networking/technologies/netsh/netsh-http#add-urlacl

    HttpListener Access Denied
    https://stackoverflow.com/questions/4019466/httplistener-access-denied

    Configuring HTTP and HTTPS:
    https://learn.microsoft.com/en-us/dotnet/framework/wcf/feature-details/configuring-http-and-https?redirectedfrom=MSDN
    #>
    [array]$UserReservationS = Get-UrlReservation -User $ENV:USERNAME | Where-Object { $ListenUrlCsv.IndexOf($_.Url) -ge 0 }
    # $UserReservationS = $null ##DD
    if (!$UserReservationS)
    {
        if (!([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator))
        {
            Write-Warning "The WebService needs to be launched with elevated Administrator permissions to allow access from remote servers"
            $CommandLine = "-File `"" + $MyInvocation.MyCommand.Path + "`" " + $MyInvocation.UnboundArguments    
            Start-Process -Verb RunAs -FilePath pwsh.exe -ArgumentList $CommandLine
            return
        }
    }
    $ReplyText, $ReturnCode = Get-Usage
    $ReplyText | Write-Host
    
    Set-AuthenticationSchema -Listener $Listener -SchemeS 'Anonymous'
    $Listener.Start()
    Write-Log "$AppName listening on: $ListenUrl"

    $ExitApp = $False
    while ($Listener.IsListening)
    {
        Write-Log "Listening ..."
        # GetContext() blocks while waiting for a request.
        # https://learn.microsoft.com/en-us/dotnet/api/system.net.httplistener.getcontext
        [System.Net.HttpListenerContext] $Context = $Listener.GetContext()

        #... Received a request
        [System.Net.HttpListenerRequest] $Request = $Context.Request
        Write-Log "Received $($Request.HttpMethod) request: $($Request.Url.OriginalString)"

        if ($Listener.AuthenticationSchemes -ne 'Anonymous')
        {
            $ClientAuthMsg = Get-ClientAuthenticationMessage -Context $Context
            Write-Log $ClientAuthMsg
        }

        # A request url has these segments: http://<hostname>/<LocalUrlPath><EndPoint><?QuerySting>
        # Here we extract the optional $EndPoint segment. 
        $EndPoint = $null
        $LocalRequest = $Request.Url.LocalPath
        $idx = $LocalRequest.ToLower().IndexOf($LocalUrlPath.ToLower())
        if ($idx -ge 0)
        {
            $idx += $LocalUrlPath.Length
            if ($idx -lt $LocalRequest.Length)
            {
                $EndPoint = $LocalRequest.Substring($idx)
            }
        }
        if (!$EndPoint) 
        {
            $EndPoint = '/' # / Represents empty <EndPoint> url segment
        }
       
        $ReturnCode = 200
        [string[]] $ReplyText = @()
        try
        {
            switch ($Request.HttpMethod) 
            {
                "GET"
                {
                    #Init $QueryParamS with key/value pairs found in QueryString
                    $QueryParamS = Get-RequestQueryParams -Request $Request
                    if ($EndPoint -eq "/")
                    {
                        $ReplyText, $ReturnCode = Get-Usage -QueryParamS $QueryParamS
                    }
                    elseif ($EndPoint -eq "/Dir")
                    {
                        $ReplyText, $ReturnCode = Get-FileList -QueryParamS $QueryParamS
                    }
                    else 
                    {
                        $ReturnCode = 404
                    }
                }

                "PUT"
                {
                    # Just echo back the body as a key : value list
                    $Body = Get-RequestBody $Request
                    $ReplyText = "Body:", ($Body | Format-List | Out-String).TrimEnd()
                    Write-Log $ReplyText
                }

                "POST"
                {
                    $Body = Get-RequestBody $Request
                    if ($EndPoint -eq "/exit")
                    {
                        $ReplyText = "`"Stopping $AppName Web Service`""
                        $ExitApp = $true
                    }
                    else 
                    {
                        $ReturnCode = 404
                    }
                }
            }            
        }
        catch 
        {
            $ReturnCode = 500
            $ReplyText = $_.Exception.Message
        }

        #Response: https://learn.microsoft.com/en-us/dotnet/api/system.net.httplistenerresponse
        [System.Net.HttpListenerResponse] $Response = $Context.Response
        $Response.StatusCode = $ReturnCode
        if ($ReturnCode -ge 400)
        {
            $ErrorMsg = switch ($ReturnCode) 
            {
                400 { $ErrorMsgByErrorNo[400] }
                404 { $ErrorMsgByErrorNo[404] }
                Default { $ErrorMsgByErrorNo[500] }
            }
            if ($ReplyText)
            {
                $ReplyText = $ErrorMsg +"`n<p>" +$ReplyText +'</p>'
            }
            else 
            {
                $ReplyText = $ErrorMsg
            }
            Write-Log "Response: $($Response.StatusCode)`n$ReplyText" -Level 'Error'
        }
        else 
        {
            Write-Log "Response: $($Response.StatusCode)"
        }

        $ReplyByteS = [Text.Encoding]::UTF8.GetBytes($ReplyText)
        $Response.ContentLength64 = $ReplyByteS.Count
        $Response.OutputStream.Write($ReplyByteS, 0 , $ReplyByteS.Count)
        #$Context.Response.ContentType = [System.Web.MimeMapping]::GetMimeMapping("")
        $Response.Close()

        if ($ExitApp)
        {
            $Listener.Stop()
        }
    }
}
catch 
{
    Write-Log $_.Exception.Message -Level 'Error'
}

if ($Listener)
{
    $Listener.Dispose()
}
Write-Log "Exiting $AppName" -ForegroundColor Cyan
Exit 0

#endregion main
