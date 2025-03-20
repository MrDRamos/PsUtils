<#
.SYNOPSIS
Much faster than Test-NetConnection
The ComputerName argument can be a DNS name or an IP-Address

.EXAMPLE
Test-TcpPort -ComputerName $ENV:COMPUTERNAME -Port 443 -Verbose
Test-TcpPort -ComputerName '192.168.1.1'      -Verbose # Returns true if local router is running
Test-TcpPort -ComputerName $ENV:COMPUTERNAME  -Verbose #-Port 80 # Returns $true if local WebServer is running
Test-TcpPort -ComputerName '127.0.0.1'        -Verbose #-Port 80 # Returns $true if local WebServer is running
Test-TcpPort -ComputerName 'www.google.com'   -Verbose
Test-TcpPort -ComputerName 'Unknown_Computer' -Verbose
#>
function Test-TcpPort
{
    [CmdletBinding()]
    param (
        [Parameter(ValueFromPipeline = $true)]
        [Alias("Host", "DnsName", 'IpAddress')]
        [String]$ComputerName,

        [Parameter()]
        [Int]$Port = 80,

        [Parameter()]
        [Alias("Timeout")]
        [Int]$TimeoutMsec = 1000
    )


    $PortOpened = $false
    try 
    {
        $TcpClient = New-Object System.Net.Sockets.TcpClient

        $IpAddress = $null        
        if ([System.Net.IPAddress]::TryParse($ComputerName, [ref]$IpAddress))
        {
            $AsyncTask = $TcpClient.ConnectAsync($IpAddress, $Port)
        }
        else 
        {
            $AsyncTask = $TcpClient.ConnectAsync($ComputerName, $Port)
        }        
        $PortOpened = $AsyncTask.Wait($TimeoutMsec)
    }
    catch 
    {
        Write-Verbose $_.Exception.Message
    }
    finally 
    {
        if ($TcpClient)
        {
            $TcpClient.Close()
        }
    }

    return $PortOpened
}
<# Unit Test
Test-TcpPort -ComputerName $ENV:COMPUTERNAME -Port 443 -Verbose
Test-TcpPort -ComputerName '192.168.1.1'      -Verbose # Returns true if local router is running
Test-TcpPort -ComputerName $ENV:COMPUTERNAME  -Verbose #-Port 80 # Returns $true if local WebServer is running
Test-TcpPort -ComputerName '127.0.0.1'        -Verbose #-Port 80 # Returns $true if local WebServer is running
Test-TcpPort -ComputerName 'www.google.com'   -Verbose
Test-TcpPort -ComputerName 'Unknown_Computer' -Verbose
exit
#>

