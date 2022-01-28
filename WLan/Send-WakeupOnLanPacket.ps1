
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
Returns a list of physical network adapters & their MacAddress's on this computer.
These physical network adapters can be configured to respond to Wake On LAN magic packets.

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
 

<#
    .SYNOPSIS
    Send-Packet sends a specified number of magic packets to a MAC address in order to wake up the machine.  
 
    .PARAMETER MacAddress
    The MAC address of the machine to wake up.

    .PARAMETER Port
    The UDP datagram to port to use. Default - 9
        0 = Rreserved port number
        7 = Echo Protocol
        9 = Discard Protocol

    .NOTES
    Wiki - Wake-on-LAN
    https://en.wikipedia.org/wiki/Wake-on-LAN
    #>
function Send-WakeupOnLanPacket
{
    [CmdletBinding()]
    param (
        [Parameter()]
        [string]$MacAddress, 

        [Parameter()]
        $BroadcastIP = [System.Net.IPAddress]::Broadcast, 

        [Parameter()]
        [int[]] $Port = @(0, 7, 9, 40000)
    )

    $Success = $false
    $UdpClient = $null
    try
    {
        # Convert the MAC string to a .Net object representing the MAC address
        $MacAddress = $MacAddress.Replace(":", "-")
        $MacAddress = $MacAddress.Replace(".", "-")
        $MAC = [Net.NetworkInformation.PhysicalAddress]::Parse($MacAddress.ToUpper())
 
        ## Construct the Magic Packet frame, 17 * 6 = 102 Bytes
        $MagicPacket = [Byte[]](, 0xFF * 6) + ($MAC.GetAddressBytes() * 16)
 
        foreach ($PortI in $Port)
        {
            $UdpClient = New-Object Net.Sockets.UdpClient
            $UdpClient.Connect($BroadcastIP, $PortI)
            $SentLength = $UdpClient.Send($MagicPacket, $MagicPacket.Length)
            $UdpClient.Dispose()
            $UdpClient = $null
            if ($SentLength -ne $MagicPacket.Length)
            {
                Throw "Send bytes: $SentLength / $($MagicPacket.Length)"
            }
            [System.Threading.Thread]::Sleep(2)
        }
        $Success = $true   
    }
    catch
    {
        $ErrMsg = "Failed to send MagicPacket to MAC: $MacAddress on port: $PortI. Error: $($_.Exception.Message)"
        Write-Host $ErrMsg -ForegroundColor Red
        if ($UdpClient)
        {
            $UdpClient.Dispose()
        }
    }
    return $Success
}



###### Main ######
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if ($ShowLookup)
{
    $LookupTable = Import-Csv -Path $LookupFile -ErrorAction Stop
    $LookupTable | Format-Table
    return
}

if ($ShowMac)
{
    Write-Host "Physical network adapters can be configured to respond to Wake On LAN magic packets:"
    Get-NetAdapter -Physical | Format-Table MacAddress, Name, Status, LinkSpeed, InterfaceDescription
    return
}

if ($ShowWakeDevice)
{
    Write-Host "Devices that are currently configured to wake the system from any sleep state:"
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


$Retval = foreach ($HostInfo in $HostInfoS)
{
    $Success = Send-WakeupOnLanPacket -MacAddress $HostInfo.MacAddress #-BroadcastIP $HostInfo.IPv4
    [PSCustomObject]@{
        Sent         = $Success
        MacAddress   = $HostInfo.MacAddress
        ComputerName = $HostInfo.ComputerName
    }
} 
return $Retval
