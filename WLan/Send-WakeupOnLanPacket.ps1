<#######################################################
Forked from: Ammaar Limbada
https://gist.github.com/alimbada/4949168

See also:
Wiki - Wake-on-LAN
https://en.wikipedia.org/wiki/Wake-on-LAN

UdpClient.Send Method
https://docs.microsoft.com/en-us/dotnet/api/system.net.sockets.udpclient.send?view=net-6.0

$Mac_Kepler     = "62:36:DD:DA:04:31"
$Mac_Feynman    = "00:24:8C:8A:0C:34"
$Mac_Einstein   = "5C:80:B6:5A:8A:25"
$Mac_Curie      = "2C:6D:C1:EC:73:77"
$Mac_Maxwell    = "24-77-03-51-E8-70"

#######################################################>
 
<#
.SYNOPSIS
Starts a list of physical machines by using Wake On LAN.
 
.DESCRIPTION
Wake sends a Wake On LAN magic packet to a given machine's MAC address.
 
.PARAMETER MacAddress
MacAddress of target machine to wake.
 
.EXAMPLE
Send-WakeupOnLanPacket A0DEF169BE02

.EXAMPLE
Send-WakeupOnLanPacket 11:22:33:44:55:66

.EXAMPLE
Send-WakeupOnLanPacket "00-15-5D-D7-21-1B"
#>
 
 
param( 
    [Parameter(Mandatory = $true, HelpMessage = "MAC address of target machine to wake up")]
    [string] $MacAddress 
    )
 
 
Set-StrictMode -Version Latest


function Send-WakeupOnLanPacket([string]$MacAddress)
{
    <#
    .SYNOPSIS
    Sends a number of magic packets using UDP broadcast.
 
    .DESCRIPTION
    Send-Packet sends a specified number of magic packets to a MAC address in order to wake up the machine.  
 
    .PARAMETER MacAddress
    The MAC address of the machine to wake up.
    #>
 
    try
    {
        $Broadcast = ([System.Net.IPAddress]::Broadcast)
 
        ## Create UDP client instance
        $UdpClient = New-Object Net.Sockets.UdpClient
 
        ## Create IP endpoints for each port
        $IPEndPoint = New-Object Net.IPEndPoint $Broadcast, 9
 
        ## Construct physical address instance for the MAC address of the machine (string to byte array)
        $MacAddress = $MacAddress.Replace("-", ":")
        $MacAddress = $MacAddress.Replace(".", ":")
        $MAC = [Net.NetworkInformation.PhysicalAddress]::Parse($MacAddress.ToUpper())
 
        ## Construct the Magic Packet frame
        $Packet = [Byte[]](, 0xFF * 6) + ($MAC.GetAddressBytes() * 16)
 
        ## Broadcast UDP packets to the IP endpoint of the machine
        $UdpClient.Send($Packet, $Packet.Length, $IPEndPoint) | Out-Null
        $UdpClient.Close()
    }
    catch
    {
        $UdpClient.Dispose()
        $Error | Write-Error;
    }
}


Send-WakeupOnLanPacket -MacAddress $MacAddress
