[CmdletBinding()]
param (
    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string] $MacAddress,

    [Parameter()]
    [string] $ApiKey = ''
)


<#
.Synopsis
Get the associated manufacturer for a MAC address by querying the API of https://macaddress.io/

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
function Get-MacManufacturerFromUrl
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string] $MacAddress,

        [Parameter(Mandatory)]
        [string] $ApiKey
    )

    # see: https://macaddress.io/api/documentation/making-requests
    $Url = "https://api.macaddress.io/v1?apiKey=$ApiKey&output=json&search=$MacAddress"

    try
    {
        $Response = Invoke-RestMethod -Uri $Url -Method Get
        return $Response.vendorDetails
    }
    catch
    {
        Write-Warning "API lookup failed: $($_.Exception.Message)"
        return $null
    }
}


function Get-MacManufacturerFromIEEEdb
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string] $MacAddress
    )

    $OUIPath = "$env:ProgramData\MacLookup\oui.csv"

    # Ensure directory exists
    if (-not (Test-Path (Split-Path $OUIPath)))
    {
        New-Item -ItemType Directory -Path (Split-Path $OUIPath) | Out-Null
    }

    # Download OUI file if missing
    if (-not (Test-Path $OUIPath))
    {
        Write-Verbose "Downloading IEEE OUI database..."
        Invoke-WebRequest -Uri "https://standards-oui.ieee.org/oui/oui.csv" -OutFile $OUIPath
    }

    # OUI = Organizationally Unique Identifier, encoded in the first 3 bytes of a MAC address
    $MacPrefix = ($MacAddress.Substring(0, 8))

    # Load OUI table
    $OUI_DB = Import-Csv $OUIPath
    $Match = $OUI_DB | Where-Object { $_.'Assignment' -eq $MacPrefix }

    if ($Match)
    {
        return [PSCustomObject]@{
            company    = $Match.'Organization Name'
            mac_prefix = $MacPrefix
            address    = $Match.'Organization Address'
        }
    }
    else
    {
        Write-Warning "No local OUI match found for prefix $Prefix"
        return $null
    }
}


function Get-MacManufacturer
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string] $MacAddress,

        [Parameter()]
        [string] $ApiKey = ''
    )

    # Normalize MAC to standard format
    $Mac = $MacAddress.Trim().ToUpper().Replace("-", ":").Replace(".", ":")

    if ($ApiKey)
    {
        return Get-MacManufacturerFromUrl -MacAddress $Mac -ApiKey $ApiKey
    }
    else
    {
        return Get-MacManufacturerFromIEEEdb -MacAddress $Mac
    }
}


Get-MacManufacturer -MacAddress $MacAddress -ApiKey $ApiKey