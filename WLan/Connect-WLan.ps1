<#
.SYNOPSIS
Script to connect to a WiFi network.
Connecting to a wireless network requires a WiFi profile associated with that network.
The WiFi profile contains the security information e.g. Password, Authentication. ...
If a profile already exist (From a prior connection attempt) then just specify the ProfileName 
parameter which by default is the same as the SSID of the network.
If no profile exists or to override an old profile (e.g. if the password changed) call this
script using the alternet ParameterSet to specify the new profile parameters: SSID, Password, ...

.NOTES
Inspired by: https://marckean.com/2019/01/01/programmably-connect-to-a-wifi-network-using-a-password/#:~:text=The%20below%20PowerShell%20code%20can%20do%20exactly%20what,details%20for%20the%20WiFi%20network%20%24SSID%20%3D%20%27%3CWiFi_SSID%3E%27?msclkid=5d5e385cb31211ec844357c1340a400c

.NOTES
Also See - Module used for management of wireless profiles:
https://github.com/jcwalker/WiFiProfileManagement
#>
[CmdletBinding(DefaultParameterSetName = "ExistingProfile")]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingPlainTextForPassword", "")]
param (
    [Parameter(Mandatory, ParameterSetName = "ExistingProfile")]
    [Parameter(ParameterSetName = "AddProfile")]
    [string] $ProfileName = $null,

    # Only needed if the computer has more than 1 WiFi adapter
    [Parameter(ParameterSetName = "ExistingProfile")]
    [Parameter(ParameterSetName = "AddProfile")]
    [string] $AdapterName = $null,
    
    [Parameter(Mandatory, ParameterSetName = "AddProfile")]
    [ValidateNotNullOrEmpty()]
    [string] $SSID,

    [Parameter(ParameterSetName = "AddProfile")]
    [Object] $Password = $null, # Plain-Text or SecureString
        
    [Parameter(ParameterSetName = "AddProfile")]
    [ValidateSet("WPA2PSK","WPA2")]
    [string] $Authentication = 'WPA2PSK',
        
    [Parameter(ParameterSetName = "AddProfile")]
    [string] $Encryption = 'AES',
        
    [Parameter(ParameterSetName = "AddProfile")]
    [ValidateSet("auto","manual")]
    [string] $ConnectionMode = "auto",

    # Overwrite existing profile
    [Parameter(ParameterSetName = "AddProfile")]
    [switch] $Force
)


function Add-WlanProfile
{
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingPlainTextForPassword", "")]
    param (
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string] $SSID,

    [Parameter()]
    [Object] $Password = $null, # Plain-Text or SecureString

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string] $ProfileName = $SSID,
    
    [Parameter()]
    [ValidateSet("WPA2PSK","WPA2")]
    [string] $Authentication = 'WPA2PSK',
        
    [Parameter()]
    [string] $Encryption = 'AES',
        
    [Parameter()]
    [ValidateSet("auto","manual")]
    [string] $ConnectionMode = "auto"
    )

    if ($Password -is [SecureString])
    {
        $Password = ConvertFrom-SecureString -SecureString ([SecureString]$Password) -AsPlainText
    }

    # Create the WiFi profile, set the profile to auto connect
    # See examples in: C:\ProgramData\Microsoft\Wlansvc\Profiles\Interfaces
    $WirelessProfile = @'
    <WLANProfile xmlns="http://www.microsoft.com/networking/WLAN/profile/v1">
        <name>{5}</name>
        <SSIDConfig>
            <SSID>
                <name>{0}</name>
            </SSID>
        </SSIDConfig>
        <connectionType>ESS</connectionType>
        <connectionMode>{4}</connectionMode>
        <MSM>
            <security>
                <authEncryption>
                    <authentication>{2}</authentication>
                    <encryption>{3}</encryption>
                    <useOneX>false</useOneX>
                </authEncryption>
                <sharedKey>
                    <keyType>passPhrase</keyType>
                    <protected>false</protected>
                    <keyMaterial>{1}</keyMaterial>
                </sharedKey>
            </security>
        </MSM>
    </WLANProfile>
'@ -f $SSID, $Password, $Authentication, $Encryption, $ConnectionMode, $ProfileName
    $Password = $null

    # Create the XML file locally
    $tempProfileXML = "$env:TEMP\Wi-Fi-${ProfileName}.xml"
    $WirelessProfile | Out-File $tempProfileXML

    # Register the WiFi profile 
    $RetMsg = & netsh wlan add profile filename="`"$tempProfileXML`""
    Remove-Item -Path $tempProfileXML

    if ($RetMsg -notMatch "added on interface")
    {
        Throw "Failed to add WiFi profile: $ProfileName.`n$RetMsg"
    }
    return $RetMsg
}



<#
.SYNOPSIS
Retrieve existing profile names
#>
function Get-WLanProfileNames
{
    [CmdletBinding()]

    $ProfileS = $null
    $CaptureS = ((netsh wlan show profiles) | Select-String "(?:Profile\s+\:\s+)(.*)").Matches.Captures
    if ($CaptureS)
    {
        $ProfileS = $CaptureS | ForEach-Object { $_.Groups[1].Value }
    }
    return $ProfileS
}


########## Main ##########

# Establish the AdapterName (= InterfaceName)
if ([string]::IsNullOrWhiteSpace($AdapterName))
{
    [array]$WiFiAdapterS = Get-NetAdapter -Physical | Where-Object { $_.PhysicalMediaType -match "802.11" }
    if (!$WiFiAdapterS)
    {
        Throw "No WiFi adapters found"
    }
    
    # User must select 1 of the adapters
    if ($WiFiAdapterS.Count -gt 1)
    {
        $WifiInfo =  $WiFiAdapterS | Select-Object Name,Status,AdminStatus,MacAddress,InterfaceDescription
        $Selected = $WifiInfo | Out-GridView -OutputMode Single -Title "Select a WiFi Adapter"
        if ($Selected)
        {
            $AdapterName = $Selected.Name
        }
        else 
        {
            return # The user canceled the operation because no Adapter was selected   
        }
    }
    else 
    {
        $AdapterName = $WiFiAdapterS.Name
    }
}


# Create a new profile
if ($SSID)
{
    # The default ProfileName is the network SSID
    if ([string]::IsNullOrWhiteSpace($ProfileName))
    {
        $ProfileName = $SSID
        $PSBoundParameters["ProfileName"] = $ProfileName
    }

    # Don't overwrite an existing profile unless the $Force switch was specified
    if ($Force)
    {
        $PSBoundParameters.Remove("Force")
    }
    else
    {
        $ProfileNameS = Get-WLanProfileNames
        if ($ProfileNameS -contains $ProfileName)
        {
            Throw "WiFi profile: $ProfileName already exists. Specifiy the -Force option to overwrite this profile"
        }        
    }

    Add-WlanProfile @PSBoundParameters
}


# Connect to the WiFi network
$RetMsg = & netsh wlan connect name="`"$ProfileName`"" interface="`"$AdapterName`""
return $RetMsg
