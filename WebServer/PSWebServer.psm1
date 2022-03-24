Function New-PSWebServer {

    <#
 .Synopsis
 Creates a web server that will invoke PowerShell code based on routes being asked for by the client.
 
 .Description
 New-PSWebServer creates a web server.  The web server is composed of a schema that defines the client's requests to routes where PowerShell code is executed.
 
 Under the covers, New-PSWebServer uses the HTTPListener .NET class to execute powershell code as requested, retrieves the results and sends data back through the httplistener web server framework.
 .Parameter Url
 Specifies a url/port in the form: http://servername:xxx/ to listen on where xxx is the port number to listen on.  When specifying localhost with the public switch activated, it will enable listening on all IP addresses.
 .Parameter Webschema
 Webschema takes a collection of hashes.  Each element in the hash represents a different route requested by the client.  For routes, the three values used in the hash are path, method, and script.  These hashes are abstracted by a DSL that you may use to build the hash. 
 method defines the HTTP method that will be used by the client to get to the route.
 path defines the address in the url supplied by the client after the http://host:port/ part of the address.  Paths support parameters allowed by Nancy.  For example, if you your path is /process/{name}, the value supplied by the requestor for {name} is passed to your script.  You would use the $parameters special variable to access the name property.  In the /process/{name} example, the property would be $parameters.name in your script.
 script is a scriptblock that will be executed when the client requests the path.  The code will be routed to this scriptblock.  The scriptblock has a special variable named $parameters that will accept client parameters.  It also contains a $request special variable that contains the request info made by the client.  The $request variable can be used to read post data from the client with the following example:
 $data = (new-Object System.IO.StreamReader @($Request.Body, [System.Text.Encoding]::UTF8)).ReadToEnd()
 Here is an example of creating the webschema with the DSL:
 $webschema = @(
     Get  '/' { "Welcome to PSWebServer!" }
     Get  '/process' { Get-Process | select name, id, path | ConvertTo-Json }
     Post '/process' {
             $processname = $Body.ProcessName
             Start-Process $processname
     }
     Get '/process/{name}' { get-process $parameters.name |convertto-json -depth 1 }
     Get '/prettyprocess' { Get-Process | ConvertTo-HTML name, id, path }
 )
 Here is an example of the raw data that the above DSL creates.  This may also be passed to -webschema:
 $webschema = @(
     @{
         path   = '/'
         method = 'get'
         script = { "Welcome to PSWebServer!" }
     },@{
         path   = '/process'
         method = 'get'
         script = { 
             Get-Process | select name, id, path | ConvertTo-Json
         }
     },@{
         path   = '/process'
         method = 'post'
         script = { 
             $processname = (new-Object System.IO.StreamReader @($Request.Body, [System.Text.Encoding]::UTF8)).ReadToEnd()
             Start-Process $processname
         }
     },@{
         path   = '/process/{name}'
         method = 'get'
         script = { 
             get-process $parameters.name |convertto-json -depth 1
         }
     },@{
         path   = '/prettyprocess'
         method = 'get'
         script = { 
             Get-Process | ConvertTo-HTML name, id, path
         }
     }
 )
 .Parameter Path
 This parameter runs the PSWebServer web server in that directory. 

 
 By default, PSWebServer will set Path to be your current directory.

 .Parameter Public
 This allows you to use have your web server use a hostname other than localhost.  Assuming your firewall is configured correctly, you will be able to serve the web calls over a network. 
 This will require admin privileges to run.  If you do not have admin privs, a prompt will ask you if you would like to elevate.  If you choose to do this, the server will have the following run as admin.  This will allow users to serve on port 8000 from this server:
 
 netsh http urlacl add url='http://+:8000/' user=everyone  
 
 If you have already run your own netsh command, it will not create a new one.  For example, if you want to serve on http://server1:8000 with your service account named "PSWebServerservice", you could run netsh as follows instead of allowing New-PSWebServer to create a "+:8000 user=everyone" urlacl.
 
 netsh http urlacl add url='http://server1:8000/' user=PSWebServerservice
 
 .Parameter Passthru
 Returns the PSWebServer object.  This is generally not needed by the other cmdlets.
 
 .Parameter AuthenticationScheme
 This is the authentication scheme or schemes your app will require. Default is anonymous.
 
 .Inputs
 Collection of hashes containing the schema of the web server
 
 .Outputs
 A Web server 
 
 .Example
 
 PS C:\> New-PSWebServer
 
 Creates a web server listening on http://localhost:8000/.  The server will respond with "Hello World!" when http://localhost:8000 is browsed to.  The server will be unreachable from outside of the server it is running on.
 
 .Example
 
 PS C:\> New-PSWebServer -Public
 
 Creates a web server listening on http://localhost:8000/.  The server will respond with "Hello World!" when http://localhost:8000 is browsed to.  The server will be reachable from outside of the server it is running on.
 This will require admin privileges to run.  If you do not have admin privs, a prompt will ask you if you would like to elevate.  If you choose to do this, the server will have the following run as admin.  This will allow users to serve on port 8000 from this server:
 netsh http urlacl add url='http://+:8000' user=everyone
 
 .Example
 
 PS C:\> New-PSWebServer -url http://localhost:8000/ -webschema @(
    Get '/'              { "Welcome to PSWebServer!" }
    Get '/process'       { get-process |select name, id, path |ConvertTo-Json }
    Get '/prettyprocess' { Get-Process |ConvertTo-HTML name, id, path }
 )

 The above illustrates how you can set up multiple paths in a PSWebServer project.  It also illustrates how to return text, create a web service that returns JSON, and display HTML visually.
 The above creates three routes that can be accessed by a client (run on the server this was run on because the public switch was not used):
 http://localhost:8000/
 http://localhost:8000/process
 http://localhost:8000/prettyprocess
 
 .Example
 
 PS C:\> New-PSWebServer -url http://localhost:8000/ -webschema @(
    Get '/' 
    Post '/startprocessbypost' {
       $processname = $Body.ProcessName
       Start-Process $processname -PassThru | ConvertTo-HTML
    } 
    Get '/startprocessbyparameter/{name}' { start-process $parameters.name -PassThru | ConvertTo-HTML }
 )
 
 The above illustrates how the special variables $request and $parameters can be used in a scriptblock.  The above illustrates how you can start a web server that will start processes based on either the data sent in POST to the route or by leveraging the parameters in a get route.
 The script enables both of the following to work:
 Invoke-RestMethod -Uri http://localhost:8000/startprocessbyparameter/notepad
 Invoke-RestMethod -Uri http://localhost:8000/startprocessbypost -Method Post -Body "Notepad"

  .Example
PS C:\> New-PSWebServer -url 'http://localhost:8080/' -webschema @(
    Post '/startprocessbypost' {
       $processname = $Body.ProcessName
       Start-Process $processname
    } @("Administrators")
    Get '/startprocessbyparameter/{name}' { start-process $parameters.name } @("Users","Administrators")
 ) -AuthenticationScheme [System.Net.AuthenticationSchemes]::Negotiate 

 The last example here shows the use of authentication and authorized roles for each route. The startprocessbypost method will only allow access if you are running the browser as administrator and thus will authenticate as being in the local administrators group.
 .LINK
 https://github.com/tiberriver256/PSWebServer/
#>
    [cmdletbinding()]
    param(
        [Parameter(Position = 0)]
        [string] $url = 'http://localhost:8000/',
        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [object[]] $webschema = @(@{path = '/'; method = 'Get'; script = {"Hello World!"}}),
        [switch] $Public,
        [Parameter(Mandatory = $false)]
        [string] $Path,
        [System.Net.AuthenticationSchemes]$AuthenticationScheme = [System.Net.AuthenticationSchemes]::Anonymous
    )
    if (!$path) {
        $path = join-path ([System.io.path]::gettemppath()) "PSWebServer"
        if (!(Test-Path $path)) {
            mkdir $path |out-null
        }
    }
    elseif (!(Test-Path $path)) {
        throw "The path to start from does not exist"
        break
    }
    if (!$Public -and $url -notmatch '\/\/localhost:') {
        throw "To specify a url other than localhost, you must use the -Public switch"
        break
    }

    if ($url -notmatch "\/$") {
        throw "Only Uri prefixes ending in '/' are allowed"
    }

    $ServerScriptBlock = {

        param(
            [string] $url,
            [object[]] $webschema,
            [bool] $Public,
            [string] $Path,
            [System.Net.AuthenticationSchemes]$AuthenticationScheme
        )

        Register-EngineEvent -SourceIdentifier ConsoleMessageEvents -Forward

        $listener = New-Object System.Net.HttpListener
        $listener.Prefixes.Add($url)
        $listener.AuthenticationSchemes = $AuthenticationScheme
        $listener.Start()

        $null = New-Event -SourceIdentifier ConsoleMessageEvents -MessageData "Listening at $url..."

        while ($listener.IsListening) {
            $context = $listener.GetContext()
            $requestUrl = $context.Request.Url
            $response = $context.Response

            $null = New-Event -SourceIdentifier ConsoleMessageEvents -MessageData "> $requestUrl"

            $localPath = $requestUrl.LocalPath
            $CurrentRoute = $webschema | Where-Object {$localPath -match $_.Path -and $_.Method -eq $context.Request.HttpMethod} | Select-Object -First 1
            $parameters = ([PSCustomObject]$Matches)
            $Route = $CurrentRoute.script
            if ($AuthenticationScheme -ne "Anonymous") {
                $Authorized = $CurrentRoute.AuthorizedGroups | Where-Object {$context.User.IsInRole($_)}
            }

            if ($Route -eq $null) {
                $null = New-Event -SourceIdentifier ConsoleMessageEvents -MessageData "No route found for:  $($context.Request.HttpMethod)  $localpath"
                $response.StatusCode = 404
                $Content = "<h1>404 - Page not found</h1>"
            }
            elseif (-not $Authorized -and $AuthenticationScheme -ne "Anonymous") {
                $null = New-Event -SourceIdentifier ConsoleMessageEvents -MessageData "$($context.User.Identity.Name) is not in any of the following groups:`n$($CurrentRoute.AuthorizedGroups)"
                $response.StatusCode = 401
                $Content = "<h1>401 - Unauthorized</h1>"
            } 
            else {
                try {

                    $content = Invoke-PSWebServerRoute -Route ([scriptblock]::Create($Route)) `
                                                    -Parameters $parameters `
                                                    -Request $context.Request `
                                                    -CurrentUser $context.User `
                                                    -ErrorAction Stop

                    if ([string]::IsNullOrEmpty($content)) {$content = ""}
                } catch {
                    $null = New-Event -SourceIdentifier ConsoleMessageEvents -MessageData (Resolve-Error $_)
                    if($Context.Request.HttpMethod -eq "GET") {
                        $content = Get-UsefulErrorMessage -PowerShellError $_ -Parameters $parameters
                    } else {
                        $Content =  "$($_.InvocationInfo.MyCommand.Name) : $($_.Exception.Message)"
                        $Content +=  "$($_.InvocationInfo.PositionMessage)"
                        $Content +=  "    + $($_.CategoryInfo.GetMessage())"
                        $Content +=  "    + $($_.FullyQualifiedErrorId)"
                    }
                    $response.StatusCode = 500
                }

            }

            $buffer = [System.Text.Encoding]::UTF8.GetBytes($content)
            $response.ContentLength64 = $buffer.Length
            $response.OutputStream.Write($buffer, 0, $buffer.Length)
            $response.Close()

            $responseStatus = $response.StatusCode
            $null = New-Event -SourceIdentifier ConsoleMessageEvents -MessageData "< $responseStatus"

        }
    }

    $InitializationScript = {
        [System.Reflection.Assembly]::LoadWithPartialName("System.Web")
        [System.Reflection.Assembly]::LoadWithPartialName("System.Web.HttpUtility")

        function Write-Host {
            param([object]$Object)
            
            Write-Output $Object
        }

        function Resolve-Error
        {
           param(
            $ErrorRecord=$Error[0]
           )

           $ErrorRecord | Format-List * -Force | Out-String
           $ErrorRecord.InvocationInfo | Format-List * | Out-String
           $Exception = $ErrorRecord.Exception
           for ($i = 0; $Exception; $i++, ($Exception = $Exception.InnerException))
           {   "$i" * 80
               $Exception |Format-List * -Force | Out-String
           }
        }

        function Get-RequestBody {

            param(
                [String]$ContentType,
                [System.Text.Encoding]$ContentEncoding,
                [System.IO.Stream]$Body
            )

            $StreamReader = [System.IO.StreamReader]::new($Body)
            $BodyContents = $StreamReader.ReadToEnd()
            $null = New-Event -SourceIdentifier ConsoleMessageEvents -MessageData "ContentType: $ContentType"
            $null = New-Event -SourceIdentifier ConsoleMessageEvents -MessageData "BodyContents: $BodyContents"

            if($ContentType -match "json") {
                $BodyContents = $BodyContents | ConvertFrom-Json
            }elseif($ContentType -match "x-www-form-urlencoded") { 
                $QueryStringCollection = [System.Web.HttpUtility]::ParseQueryString($BodyContents)
                $null = New-Event -SourceIdentifier ConsoleMessageEvents -MessageData ($QueryStringCollection)
                $BodyContentsHash = [hashtable]@{}
                $QueryStringCollection.AllKeys | foreach { $BodyContentsHash[$_] = $QueryStringCollection[$_] }
                $BodyContents = New-Object -TypeName psobject -Property $BodyContentsHash
            }

            return $BodyContents
        }

        function Invoke-PSWebServerRoute {
            [CmdletBinding()]
            param(
                [scriptblock]$Route,
                [System.Net.HttpListenerRequest]$Request,
                [PSCustomObject]$Parameters,
                [System.Security.Principal.IPrincipal]$CurrentUser
            )
            [PSCustomObject]$Query = [PSCustomObject]$Request.QueryString

            switch ($Request.HttpMethod) {

                "GET" {
                    $Result = & $Route $Parameters
                    return [string]$Result
                }

                "PUT" {
                    $Body = Get-RequestBody -ContentType $Request.ContentType -ContentEncoding $Request.ContentEncoding -Body $Request.InputStream
                    $Result = & $Route $Parameters
                    return [string]$Result
                }

                "POST" {
                    $Body = Get-RequestBody -ContentType $Request.ContentType -ContentEncoding $Request.ContentEncoding -Body $Request.InputStream
                    $Result = & $Route $Parameters
                    return [string]$Result
                }

            }
            
        }

        function Get-UsefulErrorMessage {

            param(
                $PowerShellError,
                $Parameters
            )
            try {
                $JSON = ($PowerShellError | ConvertTo-Json) + ($parameters | ConvertTo-Json )
            } catch {
                $JSON = "JSON serialization of this error failed. Fix this for more detailed response    $($PowerShellError.Exception)" + ($parameters | ConvertTo-Json )
            }

            $WebPage = @"
        <!DOCTYPE HTML>
        <html>
        <head>
        <title>ERROR 500</title>
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <meta http-equiv="X-UA-Compatible" content="IE=edge" />
        <!-- when using the mode "code", it's important to specify charset utf-8 -->
        <meta http-equiv="Content-Type" content="text/html;charset=utf-8">
        <link href="https://cdnjs.cloudflare.com/ajax/libs/jsoneditor/5.5.6/jsoneditor.min.css" rel="stylesheet" type="text/css">
        <script src="https://cdnjs.cloudflare.com/ajax/libs/jsoneditor/5.5.6/jsoneditor.min.js"></script>
        <style type="text/css">
            body {
            font: 10.5pt arial;
            color: #4d4d4d;
            line-height: 150%;
            width: 100%;
            }
            code {
            background-color: #f5f5f5;
            }
            #jsoneditor {
            width: 90%;
            }
        </style>
        </head>
        <body>
        <h1>
        Error 500: PSWebServer encountered an unhandled exception
        </h1>
        <h3 style="color:red;">
        $($PowerShellError.InvocationInfo.MyCommand.Name) : $($PowerShellError.Exception.Message)<br/>
        $($PowerShellError.InvocationInfo.PositionMessage -replace "`n","<br/>")<br/>
        $($PowerShellError.CategoryInfo | ConvertTo-Html -Fragment -As List)<br/>
        $($PowerShellError.FullyQualifiedErrorId)<br/>
        </h3>
        <h3>
        Details
        </h3>
        <div id="jsoneditor"></div>
        <script>
        var container = document.getElementById('jsoneditor');
        var options = {
            mode: 'tree',
            modes: ['code', 'form', 'text', 'tree', 'view'], // allowed modes
            onError: function (err) {
            alert(err.toString());
            },
            onModeChange: function (newMode, oldMode) {
            console.log('Mode switched from', oldMode, 'to', newMode);
            }
        };
        var json = $JSON
        var editor = new JSONEditor(container, options, json);
        </script>
        </body>
        </html>
"@

            return $WebPage

        }

    }
    
    Write-Host "Attempting to start job with the following parameters: $($url, $webschema, $Public, $Path, $AuthenticationScheme)"
    $Job = Start-Job -InitializationScript $InitializationScript -ScriptBlock $ServerScriptBlock -ArgumentList $url, $webschema, $Public, $Path, $AuthenticationScheme

    $EngineEvent = Register-EngineEvent -SourceIdentifier ConsoleMessageEvents -Action {
        Write-Host $event.MessageData;
    }

    $Global:PSWebServer = New-Object -TypeName psobject -Property @{
        "url"=$url
        "ServerJob"=$Job
        "EngineEvent"=$EngineEvent
    }

    return $PSWebServer
}

function Stop-PSWebServer {
    param(
        [psobject]$PSWebServer = $Global:PSWebServer
    )

    $Job = Start-Job -ScriptBlock {
        param($url)
        Start-Sleep -Seconds 1
        #The job will not exit until the httplistener listen() method is closed by calling the URL
        Invoke-RestMethod $url
    } -ArgumentList $PSWebServer.url

    $PSWebServer.ServerJob | Stop-Job
    $PSWebServer.EngineEvent | Stop-Job
    
    $Job | Remove-Job -Force
}

function Convert-PathParameters {

    param(
        [string]$path
    )
    
    $path = "^$path$"
    $path = $path -replace "\{", "(?<"
    $path = $path -replace "\}", ">.*)"

    $path

}

<#
.Synopsis
   Adds an endpoint to handler GET requests.
.DESCRIPTION
   Long description
.EXAMPLE
   Add-GetHandler -Path "/Process" -Script { Get-Process | ConvertTo-Json } 
.EXAMPLE
   Get "/Process" { Get-Process | ConvertTo-Json } 
#>
function Add-GetHandler {
    param(
        [string]$Path, 
        [ScriptBlock]$Script,
        [String[]]$AuthorizedGroups)

    [ScriptBlock]$Script = [scriptblock]::Create('param($parameters)' + $Script.ToString())

    [PSCustomObject]@{
        Path = (Convert-PathParameters -Path $Path)
        Method = "Get"
        Script = $Script
        AuthorizedGroups = $AuthorizedGroups
    }
}

<#
.Synopsis
   Adds an endpoint to handler POST requests.
.DESCRIPTION
   Long description
.EXAMPLE
   Add-PostHandler -Path "/Process" -Script { Start-Process $Name } 
.EXAMPLE
   Post"/Process" { Start-Process $Name } 
#>
function Add-PostHandler {
    param(
        [string]$Path, 
        [ScriptBlock]$Script,
        [String[]]$AuthorizedGroups)

    [ScriptBlock]$Script = [scriptblock]::Create('param($parameters)' + $Script.ToString())

    [PSCustomObject]@{
        Path = (Convert-PathParameters -Path $Path)
        Method = "Post"
        Script = $Script
        AuthorizedGroups = $AuthorizedGroups
    }
}

<#
.Synopsis
   Adds an endpoint to handler DELETE requests.
.DESCRIPTION
   Long description
.EXAMPLE
   Add-DeleteHandler -Path "/Process/{id}" -Script { Stop-Process $Parameters.Id } 
.EXAMPLE
   Delete "/Process/{id}" { Stop-Process $Parameters.Id } 
#>
function Add-DeleteHandler {
    param(
        [string]$Path, 
        [ScriptBlock]$Script,
        [String[]]$AuthorizedGroups)

    [ScriptBlock]$Script = [scriptblock]::Create('param($parameters)' + $Script.ToString())

    [PSCustomObject]@{
        Path = (Convert-PathParameters -Path $Path)
        Method = "Delete"
        Script = $Script
        AuthorizedGroups = $AuthorizedGroups
    }
}


<#
.Synopsis
   Adds an endpoint to handler PUT requests.
.DESCRIPTION
   Long description
.EXAMPLE
   Add-PutHandler -Path "/Service/{name}/{status}" -Script { Set-Service -Name $Parameters.Id -Status $Parameters.Status  } 
.EXAMPLE
   Put "/Service/{name}/{status}" { Set-Service -Name $Parameters.Id -Status $Parameters.Status  } 
#>
function Add-PutHandler {
    param(
        [string]$Path, 
        [ScriptBlock]$Script,
        [String[]]$AuthorizedGroups)

    [ScriptBlock]$Script = [scriptblock]::Create('param($parameters)' + $Script.ToString())

    [PSCustomObject]@{
        Path = (Convert-PathParameters -Path $Path)
        Method = "Put"
        Script = $Script
        AuthorizedGroups = $AuthorizedGroups
    }
}

New-Alias -Name Get -Value Add-GetHandler
New-Alias -Name Put -Value Add-PutHandler
New-Alias -Name Post -Value Add-PostHandler
New-Alias -Name Delete -Value Add-DeleteHandler

Export-ModuleMember -Alias get, put, post, delete `
                    -Function New-PSWebServer, Add-GetHandler, Add-PutHandler, Add-PostHandler, `
                     Add-DeleteHandler