<#
.SYNOPSIS
Programmably connect to a WiFi network using a password
Connecting to a wireless network using a password requires creating a WiFi ‘profile’.

.NOTES
Inspired by: https://marckean.com/2019/01/01/programmably-connect-to-a-wifi-network-using-a-password/#:~:text=The%20below%20PowerShell%20code%20can%20do%20exactly%20what,details%20for%20the%20WiFi%20network%20%24SSID%20%3D%20%27%3CWiFi_SSID%3E%27?msclkid=5d5e385cb31211ec844357c1340a400c

.NOTES
Also See - Module used for management of wireless profiles:
https://github.com/jcwalker/WiFiProfileManagement
#>
[CmdletBinding(DefaultParameterSetName = "UseExistingProfile")]
param (
    [Parameter(Mandatory, ParameterSetName = "UseExistingProfile")]
    [Parameter(ParameterSetName = "UseNewProfile")]
    [string] $ProfileName = $null,
    
    [Parameter(Mandatory, ParameterSetName = "UseNewProfile")]
    [ValidateNotNullOrEmpty()]
    [string] $SSID,

    [Parameter(ParameterSetName = "UseNewProfile")]
    [string] $Password = "",
        
    [Parameter(ParameterSetName = "UseNewProfile")]
    [ValidateSet("WPA2PSK","WPA2")]
    [string] $Authentication = 'WPA2PSK',
        
    [Parameter(ParameterSetName = "UseNewProfile")]
    [string] $Encryption = 'AES',
        
    [Parameter(ParameterSetName = "UseNewProfile")]
    [ValidateSet("auto","manual")]
    [string] $ConnectionMode = "auto"
    )


function Add-WiFiProfile
{
    param (
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string] $SSID,

    [Parameter()]
    [string] $Password = "",

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

    # Create the WiFi profile, set the profile to auto connect
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



# Create a new profile
if ($SSID)
{
    if ([string]::IsNullOrWhiteSpace($ProfileName))
    {
        $ProfileName = $SSID
        $PSBoundParameters["ProfileName"] = $ProfileName
    }
    Add-WiFiProfile @PSBoundParameters
}

# Connect to the WiFi network
$RetMsg = & netsh wlan connect name="`"$ProfileName`""
return $RetMsg
