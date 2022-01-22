
<#
.SYNOPSIS
Starts a list of physical machines by using Wake On LAN.
 
.DESCRIPTION
sends a Wake On LAN magic packet to a given machine's MAC address.
 
.PARAMETER MacAddress
MacAddress of of one or more target machines to wake.
User is prompted to append new MAC values not found in the lookup file.
Manually edit the csv lookup file to associate a computer name with the new MacAddress entry.

.PARAMETER Computer
One or more computer names to wake up. The csv lookup file must exist, and it must have been 
manually edited to associate computer names with MacAddress entries.

.EXAMPLE
Interactively select one or more computers from the cached values in the lookup file
Send-WakeupOnLanPacket

.EXAMPLE
Specify computer names instead of MAC address's
Send-WakeupOnLanPacket -Computer <Name>,<2nd-Name>

.EXAMPLE
Send-WakeupOnLanPacket 11:22:33:44:55:66

.EXAMPLE
Send-WakeupOnLanPacket "00-15-5D-D7-21-1B"
#>
 
[CmdletBinding(DefaultParameterSetName = "ByMac")]
param( 
    [Parameter(ParameterSetName = "ByMac", HelpMessage = "MAC address of 1 or more target machine to wake up")]
    [string[]] $MacAddress,
    
    [Parameter(ParameterSetName = "ByName")]
    [Alias("Host")]
    [string[]] $Computer 
)
 

function Send-WakeupOnLanPacket([string]$MacAddress)
{
    <#
    .SYNOPSIS
    Send-Packet sends a specified number of magic packets to a MAC address in order to wake up the machine.  
 
    .PARAMETER MacAddress
    A single or array of MAC address's of the machines to wake up.

    .NOTES
    Wiki - Wake-on-LAN
    https://en.wikipedia.org/wiki/Wake-on-LAN

    UdpClient.Send Method
    https://docs.microsoft.com/en-us/dotnet/api/system.net.sockets.udpclient.send?view=net-6.0

    .NOTES
    Inspired by: Ammaar Limbada, https://gist.github.com/alimbada/4949168
    #>
 
    try
    {
        $Broadcast = ([System.Net.IPAddress]::Broadcast)
 
        ## Create UDP client instance
        $UdpClient = New-Object Net.Sockets.UdpClient
 
        ## Create IP endpoints for each port
        $IPEndPoint = New-Object Net.IPEndPoint $Broadcast, 9
 
        ## Construct physical address instance for the MAC address of the machine (string to byte array)
        $MacAddress = $MacAddress.Replace(":", "-")
        $MacAddress = $MacAddress.Replace(".", "-")
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



###### Main ######
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

[array] $HostInfoS = $null

#Region Init HostInfoS
[array] $AllHostInfoS = $null

# Try to find HostInfoS in lookup file
$LookupFile = "Send-WolComputers.csv"
if (Test-Path $LookupFile)
{
    $AllHostInfoS = Import-Csv -Path $LookupFile -ErrorAction Stop
    if ($AllHostInfoS)
    {
        if ($MacAddress)
        {
            $HostInfoS += $AllHostInfoS | Where-Object { $MacAddress -Contains $_.Mac }
        }
        elseif ($Computer)
        {
            $HostInfoS += $AllHostInfoS | Where-Object { $Computer -Contains $_.Computer }
        }        
    }
}

# Add new MacAddress to lookup file
if ($MacAddress)
{
    [array]$NewMacS = $MacAddress
    if ($HostInfoS)
    {
        [array]$NewMacS = $MacAddress | Where-Object { $HostInfoS.Mac -NotContains $_ }    
    }
    if ($NewMacS)
    {
        $NewHostS = $NewMacS | ForEach-Object { [pscustomobject]@{ Mac = $_; Computer = ""; IPv4 ="" } }
        $HostInfoS += $NewHostS
        ($NewHostS | Format-Table | Out-String).TrimEnd() | Write-Host -ForegroundColor Yellow
        $Inp = Read-Host -Prompt "Append new values to lookup file: $LookupFile (Y)es / (N)o"
        if ($Inp -match "Y")
        {
            $AllHostInfoS += $NewHostS
            $AllHostInfoS | Export-Csv -Path $LookupFile -Force                
        }
    }
}

# Abort if an unknown(Not in lookup file) computer was specified
if ($Computer)
{
    [array]$NewComputerS = $Computer
    if ($HostInfoS)
    {
        [array]$NewComputerS = $Computer | Where-Object { $HostInfoS.Computer -NotContains $_ }
    }
    if ($NewComputerS)
    {
        Write-Host "Error: No lookup file:$LookupFile entries found for the following computers:" -ForegroundColor Red
        $NewHostS = $NewComputerS | ForEach-Object { [pscustomobject]@{ Mac = "???"; Computer = "$_"; IPv4 ="" } }
        $NewHostS | ConvertTo-Csv | Write-Host -ForegroundColor Yellow
        return
    }
}


# Let user interactivly select entries from the lookup file
if (!$HostInfoS)
{
    if ($AllHostInfoS)
    {
        $HostInfoS = $AllHostInfoS | Out-GridView -OutputMode Multiple
    }
}
#EndRegion Init HostInfoS


foreach ($HostInfo in $HostInfoS)
{
    Write-Host ("Waking: {0,-12} Mac:{1}   IPv4:{2}" -f $HostInfo.Computer, $HostInfo.Mac, $HostInfo.IPv4)
    Send-WakeupOnLanPacket -MacAddress $HostInfo.Mac
}
