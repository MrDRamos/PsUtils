[CmdletBinding()]
param (
    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string] $MacAddress
)

<#
.Synopsis
Get the associated manufacturer for a MAC address by querying the API of http://macvendors.co

.EXAMPLE
Get-MacManufacturer -MacAddress 1c-4d-66-3c-XX-XX
    company    : Amazon Technologies Inc.
    mac_prefix : 1C:4D:66
    address    : P.O Box 8102,Reno  NV  89507,US
    start_hex  : 1C4D66000000
    end_hex    : 1C4D66FFFFFF
    country    :
    type       : MA-L
#>
function Get-MacManufacturer
{
    [CmdletBinding()]
    param (
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string] $MacAddress
    )

    $MacAddress = $MacAddress.Trim().Remove(11).ToUpper().Replace("-", ":").Replace(".", ":") + ":00:00"
    $Response = Invoke-RestMethod "https://macvendors.co/api/$MacAddress"
    if ($Response)
    {
        return $Response.Result
    }
}

Get-MacManufacturer $MacAddress