
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
        Enable-NetFirewallRule -InputObject $PortRuleS[0]
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
In this sample code we simply return a message stating what authentication method was applied
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
Configure how the listener authenticates incomming requests.

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
    No Athentication i.e. The endpoint will accept any client connection
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
#PrefixeS = @("http://$($env:COMPUTERNAME):80/")    # Port 80 requires app to run as Administrator
#PrefixeS = @("http://+:80/")                       # use localhost | ipaddress | computername
$PrefixeS = @("http://+:8080/test/")               # -> irm "http://localhost:8080/test"

.NOTES
Remote computers will not be able to access the service unless a firewall rule to enable incomming access to the port is created.
New-NetFirewallRule -DisplayName "Allow Port 80" -Direction Inbound -Protocol TCP -LocalPort 80 -Action Allow -Profile @('Private', 'Domain')

.LINK
HTTPS support: https://stackoverflow.com/questions/11403333/httplistener-with-https-support/11457719#11457719
#>
function Set-EndpointPrefix([System.Net.HttpListener] $Listener, [string[]]$PrefixeS = "http://+:80/", [string] $EndpointName)
{
    foreach ($Prefix in $PrefixeS) 
    {        
        $FullPrefix = $Prefix.TrimEnd('/') + '/'
        if ($EndpointName)
        {
            $FullPrefix = $FullPrefix + $EndpointName.TrimEnd('/') + '/'
        }        
        $Listener.Prefixes.Add($FullPrefix)
    }
}


function Get-RequestBody([System.Net.HttpListenerRequest] $Request)
{
    $StreamReader = [System.IO.StreamReader]::new($Request.InputStream)
    $Body = $RequestBody = $StreamReader.ReadToEnd()

    if ($Request.ContentType -match "json") # -ContentType "application/json"
    {
        $Body = $RequestBody | ConvertFrom-Json -Depth 99
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

#endregion Helper functions

#region Handlers

function Get-Usage
{
    [CmdletBinding()]
    param (
        [Parameter()]
        [Object] $QueryParamS
    )

    if ($QueryParamS.Count)
    {
        $ReplyText = "Query Parameters:", ($QueryParamS | Format-Table | Out-String).TrimEnd()
    }
    else
    {
    $ReplyText = @"
$Script:AppName WebServer examples:
localhost    = $ENV:Computername
LocalUrlPath = $LocalUrlPath

Get Help:  irm -Method Get  -Uri "http://localhost/$LocalUrlPath"
Get ?Str:  irm -Method Get  -Uri "http://localhost/$LocalUrlPath/?Country=USA&City=Boston&City=NewYork&Zipcode=11790"
Get Dir:   irm -Method Get  -Uri "http://localhost/$LocalUrlPath/dir"
Get Dir:   irm -Method Get  -Uri "http://localhost/$LocalUrlPath/dir?*.ps1"
Post Data: irm -Method Put  -Uri "http://localhost/$LocalUrlPath/" -Body '{ "key1": "val1", "key2": "val2" }' -ContentType "application/json"
Terminate: irm -Method Post -Uri "http://localhost/$LocalUrlPath/exit"       
"@
    }
    
    return @($ReplyText, 200)
}


function Get-FileList
{
    [CmdletBinding()]
    param (
        [Parameter()]
        [Object] $QueryParamS
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
        Write-Log $ErrorMsg
        return @($ErrorMsg, 400)
    }
    
    return @($ReplyText, 200)
}

#endregion Handlers


#region main

<######################################   MAIN  ######################################
 Refernces:
    https://4sysops.com/archives/building-a-web-server-with-powershell/
    https://gist.github.com/Tiberriver256/868226421866ccebd2310f1073dd1a1e
    https://github.com/PowerShell/Polaris
    https://github.com/TLaborde/NodePS
######################################################################################>

<#
A request url hase these segments: http://<hostname>/<LocalUrlPath><EndPoint><?QuerySting>
The listener will not process a request unless the url has these segments: http://<hostname>/<LocalUrlPath>
In this program the <LocalUrlPath> = $AppName/$AppVer
Note: $AppName, $AppVer and thus $LocalUrlPath may all be empty
#>
$AppName = 'MyEndpoint'
$AppVer  = 'v1'

# Init $LocalUrlPath
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
    # Set up a Listener. https://docs.microsoft.com/en-us/dotnet/api/system.net.httplistener?view=net-6.0
    $Listener = New-Object System.Net.HttpListener

    Set-EndpointPrefix -Listener $Listener -EndpointName $LocalUrlPath
    $ListenUrl = $Listener.Prefixes -join ', '

    Set-AuthenticationSchema -Listener $Listener -SchemeS 'Anonymous'
    $Listener.Start()
    Write-Log "$AppName listening on: $ListenUrl"

    $ExitApp = $False
    while ($Listener.IsListening)
    {
        #https://docs.microsoft.com/en-us/dotnet/api/system.net.httplistenercontext?redirectedfrom=MSDN&view=net-6.0
        Write-Log "Listening ..."
        [System.Net.HttpListenerContext] $Context = $Listener.GetContext()

        #... Received a request
        [System.Net.HttpListenerRequest] $Request = $Context.Request
        Write-Log "Received $($Request.HttpMethod) request: $($Request.Url.OriginalString)"

        if ($Listener.AuthenticationSchemes -ne 'Anonymous')
        {
            $ClientAuthMsg = Get-ClientAuthenticationMessage -Context $Context
            Write-Log $ClientAuthMsg
        }

        # A request url hase these segments: http://<hostname>/<LocalUrlPath><EndPoint><?QuerySting>
        # Here we extract the optioanl $EndPoint segment. 
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
       
        #Init $QueryParamS with key/value pairs found in QueryString
        # e.g. $QueryStr = "Country=USA&City=Boston&City=NewYork&Zipcode=11790"
        # => $QueryParamS = @{ Country='USA'; City=@('Boston','NewYork'); Zipcode=11790 }
        $QueryParamS = @{}
        if ($Request.QueryString.Count)
        {
            $QryStr = $Request.QueryString  # Map DotNet Specialized.NameValueCollection -> [hashtable]
            foreach ($Key in $QryStr.AllKeys) 
            {
                $Value = $QryStr.GetValues($Key)
                if ($null -eq $Key)
                {
                    $Key = ''
                }
                $QueryParamS.Add($Key, $Value)
            }

            if ($QueryParamS)
            {
                "Query Parameters:", ($QueryParamS | Format-Table | Out-String).TrimEnd() | Write-Log
            }
        }

        $ReturnCode = 200
        [string[]] $ReplyText = @()
        try
        {
            switch ($Request.HttpMethod) 
            {
                "GET"
                {
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

        #Response: https://docs.microsoft.com/en-us/dotnet/api/system.net.httpListenercontext.response?view=net-6.0
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
