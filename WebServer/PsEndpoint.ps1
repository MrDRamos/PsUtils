
# https://4sysops.com/archives/building-a-web-server-with-powershell/
# https://gist.github.com/Tiberriver256/868226421866ccebd2310f1073dd1a1e
# https://github.com/PowerShell/Polaris
# https://github.com/TLaborde/NodePS

$AppName = "PsEndpoint"
$PrefixeS = @("http://localhost:8080/")
#$PrefixeS = @("http://+:8080/test/")
#$PrefixeS = @("http://$($env:COMPUTERNAME):8080/")
# https endpoint: https://stackoverflow.com/questions/11403333/httplistener-with-https-support/11457719#11457719

function Get-ClientAuthenticationMessage([System.Net.HttpListenerContext] $Context)
{
    [System.Security.Principal.IPrincipal] $User = $Context.User;
    [System.Security.Principal.IIdentity] $Id = $User.Identity;
    if (!$id)
    {
        return "Client authentication is not enabled for this Web server.";
    }

    $Retval = ""
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

function Get-RequestBody([System.Net.HttpListenerRequest] $Request)
{
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
    "Body:", ($Body | Format-Table | Out-String).TrimEnd() | Write-Verbose -Verbose
    Return $Body
}


# Set up a Listener. https://docs.microsoft.com/en-us/dotnet/api/system.net.httplistener?view=net-6.0
$Listener = New-Object System.Net.HttpListener
$Prefixes | ForEach-Object { $Listener.Prefixes.Add($_) }
$Listener.Start()
Write-Output "$AppName listening on: $PrefixeS"

# 1) Negotiate the authentication scheme to use
#$Listener.AuthenticationSchemes = [System.Net.AuthenticationSchemes]::Negotiate

<# 2) Use Basic Authentication: Username:Password
$User = "LetMeIn"; $Password = "TopSecret"
$BasicAuthB64 = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("$($User):$($Password)"))
$Header = @{ Authorization = "Basic $BasicAuthB64" }
run: irm "http://localhost:8080/" -header $Header
or:  irm "http://localhost:8080/" -Credential $Cred -AllowUnencryptedAuthentication
#>
#$Listener.AuthenticationSchemes = [System.Net.AuthenticationSchemes]::Basic

<# 3) For Intranet environment only: Use Kerberos or NTLM to authenticated user
run: irm "http://localhost:8080/" -UseDefaultCredentials -AllowUnencryptedAuthentication
#>
#$Listener.AuthenticationSchemes = [System.Net.AuthenticationSchemes]::IntegratedWindowsAuthentication

try 
{
    $ExitApp = $False
    while ($Listener.IsListening)
    {
        #https://docs.microsoft.com/en-us/dotnet/api/system.net.httplistenercontext?redirectedfrom=MSDN&view=net-6.0
        Write-Host "Listening ..."
        [System.Net.HttpListenerContext] $Context = $Listener.GetContext()

        #... Received a request
        [System.Net.HttpListenerRequest] $Request = $Context.Request
        $EndPoint = $Request.Url.LocalPath
        Write-Verbose "Received request: $EndPoint"
       
        #Convert the QueryString into powershell [HashTable] of key/value parameters
        $QueryParamS = @{}       
        $QryStr = $Request.QueryString  # e.g. $QueryStr = "?Country=USA&City=Boston&City=NewYork&Zipcode=11790"  
        foreach ($Key in $QryStr)
        {
            $ValueS = $QryStr[$Key] -split ","
            $QueryParamS[$Key] = $ValueS
        }
        "QueryStr:", ($QueryParamS | Format-Table | Out-String).TrimEnd() | Write-Verbose -Verbose

        $ClientAuthMsg = Get-ClientAuthenticationMessage -Context $Context
        Write-Output $ClientAuthMsg

        $ReplyText = $null
        switch ($Request.HttpMethod) 
        {
            "GET"
            {
                if ($EndPoint -eq "/")
                {
                    $ReplyText = "$AppName Usage: ...TBD..."
                }
                elseif ($EndPoint -eq "/Dir")
                {
                    #$ReplyText = Get-Item -Path * | ConvertTo-Json
                    $ReplyText = Get-Item -Path * | Format-Table | Out-String
                }
            }

            "PUT"
            {
                $Body = Get-RequestBody $Request
                #TODO $Content = ...
            }

            "POST"
            {
                $Body = Get-RequestBody $Request
                if ($EndPoint -eq "/exit")
                {
                    $ReplyText = "`"Stopping $AppName Web Service`""
                }
                $ExitApp = $true
            }
        }

        #Response: https://docs.microsoft.com/en-us/dotnet/api/system.net.httpListenercontext.response?view=net-6.0
        [System.Net.HttpListenerResponse] $Response = $Context.Response
        if ($null -eq $ReplyText)
        {
            $ReplyText = "<h1>404 - Page not found</h1>"
            $Response.StatusCode = 401
        }

        $ReplyByteS = [Text.Encoding]::UTF8.GetBytes($ReplyText)
        $Response.ContentLength64 = $ReplyByteS.Count
        $Response.OutputStream.Write($ReplyByteS, 0 , $ReplyByteS.Count)
        #$Context.Response.ContentType = [System.Web.MimeMapping]::GetMimeMapping("")
        $Response.Close()
        Write-Host "Response: $($Response.StatusCode)"

        if ($ExitApp)
        {
            $Listener.Stop()
        }
    }
}
catch 
{
    Write-Output $_.Exception.Message
}
$Listener.Dispose()
Write-Output "$AppName Stopped"
