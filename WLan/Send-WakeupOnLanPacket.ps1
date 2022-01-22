
<#
.SYNOPSIS
Sends a Wake On LAN magic packet to a given machine's MAC address.
MacAddress's are harder to remember than ComputerName's. The script will alternatively accept
a ComputerName, but only if the associated MacAddress can be found in a lookup-file.
The lookup-file contains CSV formatted entries, and is automatically seeded with new MacAddress's.
Mote: You must manually edit the lookup-file to supply the associated ComputerName.
 
.PARAMETER MacAddress
The network adapter MacAddress of one or more target computers to wake.
PowerShell command the retrieve the MacAddress: Get-NetAdapter
The lookup-file is parsed for a matching MacAddress entry. If no match is found then the user 
is prompted to append new MacAddress to the lookup-file. 
Mote: You must manually edit the lookup-file to supply the associated ComputerName.

.PARAMETER ComputerName
The name of one or more computers to wake up. 
The ComputerName specified is used to find an associated MacAddress entry in the lookup-file. 
The script will abort if the lookup-file does not exist or the ComputerName was not found.
Mote: You must manually edit the lookup-file to supply the associated ComputerName.

.PARAMETER ShowMac
Retrieves a list of all the network adapter MacAddress's on this computer

.PARAMETER ShowLookupTable
Retrieves a list of all the network adapter MacAddress's on this computer

.PARAMETER ShowWakeDevice
List devices that are currently configured to wake the system from any sleep state

.EXAMPLE
Interactively select one or more computers from the cached values in the lookup-file
Send-WakeupOnLanPacket

.EXAMPLE
Specify computer names instead of MAC address's
Send-WakeupOnLanPacket -ComputerName <Name1>,<Name2>

.EXAMPLE
Send-WakeupOnLanPacket -MacAddress "00-15-5D-D7-21-1B"

.EXAMPLE
Send-WakeupOnLanPacket -MAC 11:22:33:44:55:66
#>
 
[CmdletBinding(DefaultParameterSetName = "ByName")]
param( 
    [Parameter(ParameterSetName = "ByMac",
               HelpMessage = "MAC address of one or more target computers to wake up.")]
    [Alias("MAC")]
    [string[]] $MacAddress,
    
    [Parameter(ParameterSetName = "ByName", Position = 1)]
    [Alias("Host", "MachineName")]
    [string[]] $ComputerName,

    [Parameter(ParameterSetName = "ShowLookup")]
    [switch] $ShowLookup,

    [Parameter(ParameterSetName = "ByMac")]
    [Parameter(ParameterSetName = "ByName")]
    [Parameter(ParameterSetName = "ShowLookup")]
    [string] $LookupFile = "$PSScriptRoot\Send-WolComputers.csv",

    [Parameter(ParameterSetName = "ShowMac")]
    [switch] $ShowMac,

    [Parameter(ParameterSetName = "ShowWakeDevice")]
    [switch] $ShowWakeDevice
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

if ($ShowMac)
{
    Get-NetAdapter | Format-Table MacAddress, Status, Name, InterfaceDescription
    return
}

if ($ShowLookup)
{
    $LookupTable = Import-Csv -Path $LookupFile -ErrorAction Stop
    $LookupTable | Format-Table
    return
}

if ($ShowWakeDevice)
{
    "Devices that are currently configured to wake the system from any sleep state."
    & powercfg.exe -devicequery wake_armed
    return
}


#Region Init HostInfoS
[array] $HostInfoS = $null
[array] $LookupTable = $null

# Try to find HostInfoS in lookup-file
if (Test-Path $LookupFile)
{
    $LookupTable = Import-Csv -Path $LookupFile -ErrorAction Stop
    if ($LookupTable)
    {
        if ($MacAddress)
        {
            $HostInfoS += $LookupTable | Where-Object { $MacAddress -Contains $_.MacAddress }
        }
        elseif ($ComputerName)
        {
            $HostInfoS += $LookupTable | Where-Object { $ComputerName -Contains $_.ComputerName }
        }        
    }
}

# Add new MacAddress to lookup-file
if ($MacAddress)
{
    [array]$NewMacS = $MacAddress
    if ($HostInfoS)
    {
        [array]$NewMacS = $MacAddress | Where-Object { $HostInfoS.MacAddress -NotContains $_ }    
    }
    if ($NewMacS)
    {
        Write-Host "MacAddress(s) not found lookup-file: '$LookupFile'" -ForegroundColor Red
        $NewHostS = $NewMacS | ForEach-Object { [pscustomobject]@{ MacAddress = $_; ComputerName = ""; IPv4 = "" } }
        $HostInfoS += $NewHostS
        ($NewHostS | Format-Table | Out-String).Trim() | Write-Host
        $Inp = Read-Host -Prompt "Append new MacAddress(s) to lookup-file - Enter (Y)es (N)o (C)ancel"
        if ($Inp -match "Y")
        {
            $LookupTable += $NewHostS
            $LookupTable | Export-Csv -Path $LookupFile -Force                
        }
        elseif ($Inp -match "C")
        {
            return
        }
    }
}

# Abort if an unknown(Not in lookup-file) computer was specified
if ($ComputerName)
{
    [array]$NewComputerS = $ComputerName
    if ($HostInfoS)
    {
        [array]$NewComputerS = $ComputerName | Where-Object { $HostInfoS.ComputerName -NotContains $_ }
    }
    if ($NewComputerS)
    {
        Write-Host "Error: ComputerName(s) not found in lookup-file: '$LookupFile'" -ForegroundColor Red
        $NewHostS = $NewComputerS | ForEach-Object { [pscustomobject]@{ MacAddress = "--:--:--:--:--:--"; ComputerName = "$_"; IPv4 = "" } }
        $NewHostS | ConvertTo-Csv | Write-Host -ForegroundColor Yellow
        return
    }
}


# Let user interactivly select entries from the lookup-file
if (!$HostInfoS)
{
    if ($LookupTable)
    {
        $HostInfoS = $LookupTable | Out-GridView -OutputMode Multiple
    }
}
#EndRegion Init HostInfoS


foreach ($HostInfo in $HostInfoS)
{
    Write-Host ("Waking: {0,-12} Mac: {1}   IPv4: {2}" -f $HostInfo.ComputerName, $HostInfo.MacAddress, $HostInfo.IPv4)
    Send-WakeupOnLanPacket -MacAddress $HostInfo.MacAddress
}
