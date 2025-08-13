<#
.SYNOPSIS
PowerShell script that creates a TcpPort server listening for client connections.
Any client data received is output standard output stream.
Internal status messages are output the the PowerShell Information stream (i.e' Host console)

.Parameter IpAddress
The default IpAddress in 127.0.0.1, i.e. the local loopback address for applications running on the same host

.Parameter Port
The local Port number on which server will listen for client connections

.Parameter PromptForResponse
Setting  this switch allows the user to enter a custom response after 
establishing a new client connection and after receiving client messages

.Parameter Echo
Set the $Echo switch to automatically echo any received data back to the client.

.Parameter OutFile
Save the received client data to an output file

.Notes
 ALternative Apps: 
    Microsoft command-line tool: PortQry
    https://learn.microsoft.com/en-us/troubleshoot/windows-server/networking/portqry-command-line-port-scanner-v2

    TCP Listen 
    https://www.allscoop.com/tcp-listen.html

.EXAMPLE
& .\TcpPortServer.ps1 -Port 9100 -OutFile 'TcpPortData.txt'
#>

param (
    [Parameter()]
    [string]$IPAddress = "127.0.0.1",

    [Parameter()]
    [int]$Port = 9100,

    [Parameter()]
    [Alias('Prompt')]
    [switch]$PromptForResponse,

    [Parameter()]
    [switch]$Echo,

    [Parameter()]
    [string]$OutFile = $null
)


<#
.Example
Test-KeyPressed -Keys @([system.consolekey]::Escape, [system.consolekey]::Enter)
#>
function Test-KeyPressed([array]$KeyS = @([system.consolekey]::Escape), [switch] $AnyKey)
{
    $Retval = $false
    if ($Host.Name -match 'ISE Host')
    {
        $KeyAvailable = $Host.UI.RawUI.KeyAvailable
    }
    else
    {
        $KeyAvailable = [System.Console]::KeyAvailable
    }
    if ($KeyAvailable)
    {
        $InpKey = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown').VirtualKeyCode;        
        if ($AnyKey -or $KeyS -ccontains $InpKey)
        {
            $Retval = $true
        }
    }
    return $Retval
}


function Get-TcpClientCimProc
{
    [CmdletBinding()]
    param (
        [Parameter()]
        #[System.Net.Sockets.<ObfuscatedClass>] where ObfuscatedClass = TcpClient
        [Object] $TcpClient
    )
    $ClientProc = $null
    $ClientPort = $TcpClient.Client.RemoteEndPoint.Port
    $ClientPid = (Get-NetTCPConnection -LocalPort $ClientPort).OwningProcess  | Sort-Object -Unique
    if ($ClientPid)
    {
        $ClientProc = Get-CimInstance -ClassName Win32_Process -Filter "ProcessId = $ClientPid"
    }
    return $ClientProc
}



function Read-TcpStream($TcpStream)
{
    $RecvStr = New-Object System.Text.StringBuilder
    $ByteS = New-Object System.Byte[] -ArgumentList 1024
    $Encoding = New-Object System.Text.AsciiEncoding 
    Start-Sleep -Milliseconds 50 # Allow data to accumulate

    while ($tcpStream.DataAvailable)
    {
        try 
        {
            $BytesRead = $TcpStream.Read($ByteS, 0, $ByteS.Length)
            if ($BytesRead)
            {
                $null = $RecvStr.Append($Encoding.GetString($ByteS, 0, $BytesRead))
                Start-Sleep -Milliseconds 10 # Allow data to accumulate
            }
        }
        catch 
        {
            Write-Host ($_.Exception.Message) -ForegroundColor Red
            break
        }
    }
    return $RecvStr.ToString()
}


################### Main ###################

# Create a TCP listener
Write-Host "Starting TcpListener, Press <ESC> to exit" -ForegroundColor Cyan
$listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Parse($IPAddress), $Port)
$listener.Start()
Write-Host "Listening on: ${IPAddress}:$Port ..." -ForegroundColor Cyan

$ReConnect = $true
$RecvMore = $true
try 
{
    $Task = $null
    while ($ReConnect -and $RecvMore) 
    {
        # Accept incoming client connections
        $client = $null #[System.Net.Sockets.<ObfuscatedClass>] where ObfuscatedClass = TcpClient
        if (!$Task)
        {
            $Task = $listener.AcceptTcpClientAsync()
        }
        if ($Task.Wait(500))
        {
            if ($Task.IsCompleted)
            {
                $client = $Task.Result
            }            
            $Task = $null
        }

        if ($client)
        {
            Write-Host "Connection accepted from: " -NoNewline  -ForegroundColor Green
            $ClientProc = Get-TcpClientCimProc -TcpClient $client            
            if ($ClientProc)
            {
                $ClientProcName = $ClientProc.Name 
            }
            else 
            {
                $ClientProcName = $client.Client.RemoteEndPoint.ToString()
            }
            $ClientProcName | Write-Host -ForegroundColor Green
    
            $tcpStream = $client.GetStream()
            $tcpStream.ReadTimeout = 1000
            $tcpStream.WriteTimeout = 1000
            $writer = New-Object System.IO.StreamWriter($tcpStream)
            $writer.AutoFlush = $true

            if ($client.Connected -and $PromptForResponse)
            {
                Write-Host -NoNewline "Enter connection response> " -ForegroundColor Yellow
                $response = Read-Host            
                if (![string]::IsNullOrEmpty($response))
                {
                    $null = $writer.WriteLine($response)
                }                        
            }
            $IsConnected = $client.Connected # Was Updated by last read & write operations
    
            while ($RecvMore -and $IsConnected) 
            {            
                if ($tcpStream.DataAvailable)
                {
                    Write-Host 'Received:' -ForegroundColor Yellow
                    $clientData = Read-TcpStream -TcpStream $tcpStream
    
                    if ($client.Connected)
                    {
                        $clientData | Write-Output 

                        if (![string]::IsNullOrWhiteSpace($OutFile))
                        {
                            try 
                            {
                                $clientData | Add-Content -Path $OutFile    
                            }
                            catch 
                            {
                                Write-Host ($_.Exception.messages)
                            }                            
                        }
    
                        # Echo data back to client
                        if ($client.Connected -and $Echo)
                        {
                            $null = $writer.Write($clientData, 0, $clientData.Length)
                        }
                    }
    
                    
                    if ($client.Connected -and $PromptForResponse)
                    {
                        Write-Host -NoNewline "Enter response> " -ForegroundColor Yellow
                        $response = Read-Host            
                        if (![string]::IsNullOrEmpty($response))
                        {
                            $null = $writer.WriteLine($response)
                        }                        
                    }
                    $IsConnected = $client.Connected # Was Updated by last read & write operations
                }
                else 
                {
                    # Poll the socket to check the state of the connection
                    $IsConnected = !($client.Client.Poll(0, [System.Net.Sockets.SelectMode]::SelectRead) -and $client.Client.Available -eq 0)
                    if ($IsConnected)
                    {
                        if (Test-KeyPressed)
                        {
                            $RecvMore = $false    
                        }
                        else 
                        {
                            Start-Sleep -Milliseconds 500
                        }
                    }
                }
            }
    
            # Release all the system resources
            $tcpStream.Close(100)
            if ($IsConnected)
            {
                Write-Host "Closing the connection" -ForegroundColor Magenta
                $client.Close()
                $IsConnected = $false
            }
            else 
            {
                Write-Host "$ClientProcName closed the connection" -ForegroundColor Magenta
            }
            $writer = $tcpStream = $client = $null
    
            $ReConnect = !(Test-KeyPressed)
            if ($Reconnect -and $RecvMore)
            {
                Write-Host "`nListening on: ${IPAddress}:$Port ..." -ForegroundColor Cyan
            }    
        }
        else 
        {
            if (Test-KeyPressed)
            {
                $ReConnect = $false    
            }
        }
    }
} 
catch 
{
    Write-Host "An error occurred: $($_.Exception.Message)" -ForegroundColor Red
} 
finally 
{
    $listener.Stop()
    Write-Host "Stopped TcpListener"  -ForegroundColor Cyan
}
