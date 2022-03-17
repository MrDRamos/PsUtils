[CmdletBinding()]
param (
    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [alias("IpAddress")]
    [string] $ComputerName
)


<#
.Synopsis
  Finds the MacAddress associated with a Computer on the local lan.
  Returns the found MacAddress if found

.PARAMETER ComputerName  
The computer name or its ip address
#>
function Resolve-MacAddressFromArpCache
{
    [CmdletBinding()]
    param (
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [alias("IpAddress")]
        [string] $ComputerName
    )

        
    $Mac = $null
    $ComputerName = $ComputerName.Trim()
    if ($ComputerName -Match "^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$" -or     # IPv4
        $ComputerName -Match "^(?:[0-9A-F]{1,4}:)(:[0-9A-F]{1,4}){4}$")             # IPv6
    {
        $IpAddress = $ComputerName
    }
    else
    {
        $DnsRecord = Resolve-DnsName -Name $ComputerName -Type A -ErrorAction Ignore
        if ($DnsRecord)
        {
            $IpAddress = $DnsRecord.IpAddress
        }
        else 
        {
            Write-Warning "No DNS A-Record found for: $ComputerName`nTry again by specifing an IpAddress instead of the computer name."            
        }
    }

    if ($IpAddress)
    {
        if ($IpAddress -is [array])
        {
            Write-Error "$ComputerName has mutliple IpAddress's: $($IpAddress -join "  ")`nTry again by specifing an IpAddress instead of the computer name."
        }
        # Ping to update the local ARP-Table
        $ArpInfo = Get-NetNeighbor -IPAddress $IpAddress -ErrorAction Ignore
        if (!$ArpInfo -or $ArpInfo.State -eq "Unreachable")
        {
            # Ping to update the local ARP-Table
            if (!(Test-NetConnection -ComputerName $ComputerName -InformationLevel Quiet *>%1))
            {
                Write-Warning "$ComputerName is not reachable via ICMP. ARP-Cache could not be refreshed!"
            }
            $ArpInfo = Get-NetNeighbor -IPAddress $IpAddress           
        }
        if ($ArpInfo -and $ArpInfo.State -ne "Unreachable")
        {
            $Mac = $ArpInfo.LinkLayerAddress
        }
    }

    return $Mac
}


Resolve-MacAddressFromArpCache -ComputerName $ComputerName

