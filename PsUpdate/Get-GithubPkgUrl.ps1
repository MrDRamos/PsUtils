<#
.SYNOPSIS
Returns the version and download url[s] of the latest release artifacts in a GitHub repo.
See: https://docs.github.com/en/rest/releases/releases?apiVersion=2022-11-28#get-the-latest-release

.PARAMETER AccountName
The organization name of the GitHub repo
Url format of the github api used retrieve the latest version:
"https://api.github.com/repos/$AccountName/$RepoName/releases/latest"

.PARAMETER RepoName
The package name of the GitHub repo
Url format of the github api used retrieve the latest version:
"https://api.github.com/repos/$AccountName/$RepoName/releases/latest"

.PARAMETER Version
The default retrieves the latest version. 
Use this parameter to return a specific version, e.g. v8.6.8

.PARAMETER NoZip
An optional flag that removes zip and 7z files, by using hardcoded NameRegex filter

.PARAMETER NoTar
An optional flag that removes tar files, by using hardcoded NameRegex filter

.PARAMETER NoSig
An optional flag that removes sig signatures files, by using hardcoded NameRegex filter

.PARAMETER NameRegex
Use an optional NameRegex parameter to filter out which release artifact names to return.
The default returns a list of all the published release assets such as:
exe, zip, tar and msi files for x86, x64 and arm platforms and sig and sha signature files.

.EXAMPLE
Get the download url's for all the latest notepad++ artifacts, i.e. zip,exe,sig files
Get-GithubAssetUrl notepad-plus-plus notepad-plus-plus

.EXAMPLE
Get download url for the latest notepad++ exe installers
Get-GithubAssetUrl notepad-plus-plus notepad-plus-plus -NoZip -NoSig

.EXAMPLE
Get download url's for all the Notepad++ 8.7.8 artifacts
Get-GithubAssetUrl notepad-plus-plus notepad-plus-plus -version 8.6.8

.EXAMPLE
Get the Url's for the latest git for windows installers
Get-GithubAssetUrl git-for-windows git exe
#>
#<##DD un-comment for debugging
[CmdletBinding()]
param (
    [Parameter(Mandatory, Position = 1)]
    [ValidateNotNullOrEmpty()]
    [Alias('Account')]
    [string] $AccountName,

    [Parameter(Mandatory, Position = 2)]
    [ValidateNotNullOrEmpty()]
    [Alias('Repo', 'Pkg', 'Package')]
    [string] $RepoName,

    [Parameter()]
    [Alias('Ver', 'TagName')]
    [string] $Version = $null,

    [Parameter(Position = 3)]
    [Alias('Name')]
    [string] $NameRegex = $null, #examples 'windows-x64.exe$','\.msi$','\.zip$'

    [Parameter()]
    [switch] $NoZip,

    [Parameter()]
    [switch] $NoTar,

    [Parameter()]
    [switch] $NoSig
)
#>




<#
.SYNOPSIS
Returns the version and download url[s] of the latest release artifacts in a GitHub repo.
See: https://docs.github.com/en/rest/releases/releases?apiVersion=2022-11-28#get-the-latest-release

.PARAMETER AccountName
The organization name of the GitHub repo
Url format of the github api used retrieve the latest version:
"https://api.github.com/repos/$AccountName/$RepoName/releases/latest"

.PARAMETER RepoName
The package name of the GitHub repo
Url format of the github api used retrieve the latest version:
"https://api.github.com/repos/$AccountName/$RepoName/releases/latest"

.PARAMETER Version
The default retrieves the latest version. 
Use this parameter to return a specific version, e.g. v8.6.8

.PARAMETER NoZip
An optional flag that removes zip and 7z files, by using hardcoded NameRegex filter

.PARAMETER NoTar
An optional flag that removes tar files, by using hardcoded NameRegex filter

.PARAMETER NoSig
An optional flag that removes sig signatures files, by using hardcoded NameRegex filter

.PARAMETER NameRegex
Use an optional NameRegex parameter to filter out which release artifact names to return.
The default returns a list of all the published release assets such as:
exe, zip, tar and msi files for x86, x64 and arm platforms and sig and sha signature files.

.EXAMPLE
Get the download url's for all the latest notepad++ artifacts, i.e. zip,exe,sig files
Get-GithubAssetUrl notepad-plus-plus notepad-plus-plus

.EXAMPLE
Get download url for the latest notepad++ exe installers
Get-GithubAssetUrl notepad-plus-plus notepad-plus-plus -NoZip -NoSig

.EXAMPLE
Get download url's for all the Notepad++ 8.7.8 artifacts
Get-GithubAssetUrl notepad-plus-plus notepad-plus-plus -version 8.6.8

.EXAMPLE
Get the Url's for the latest git for windows installers
Get-GithubAssetUrl git-for-windows git exe
#>
function Get-GithubPkgUrl
{
    [CmdletBinding()]
    [OutputType('Github.AssetInfo')]
    param (
        [Parameter(Mandatory, Position = 1)]
        [ValidateNotNullOrEmpty()]
        [Alias('Account')]
        [string] $AccountName,

        [Parameter(Mandatory, Position = 2)]
        [ValidateNotNullOrEmpty()]
        [Alias('Repo','PkgName','Package')]
        [string] $RepoName,

        [Parameter()]
        [Alias('Ver', 'TagName')]
        [string] $Version = 'latest',

        [Parameter(Position = 3)]
        [Alias('Name')]
        [string] $NameRegex = $null, #examples 'windows-x64.exe$','\.msi$','\.zip$'

        [Parameter()]
        [switch] $NoZip,

        [Parameter()]
        [switch] $NoTar,

        [Parameter()]
        [switch] $NoSig
    )


    # See: https://github.com/PSModule/GitHub/blob/main/src/functions/public/Releases/Releases/Get-GitHubRelease.ps1
    $TagName = ([string]$Version).Trim('Vv ')
    if ([string]::IsNullOrWhiteSpace($TagName) -or $TagName -eq 'latest')
    {
        $RepoUrl = "https://api.github.com/repos/$AccountName/$RepoName/releases/latest"
    }
    else 
    {
        $RepoUrl = "https://api.github.com/repos/$AccountName/$RepoName/releases/tags/v$TagName"
    }
    try 
    {
        $Reply = Invoke-RestMethod -Uri $RepoUrl
        if ($Reply)
        {
            # Define $PSStandardMembers:= The 4 default properties used when calling Format-Table or Format-List
            # https://learn-powershell.net/2013/08/03/quick-hits-set-the-default-property-display-in-powershell-on-custom-objects/
            $DefaultDisplaySet = 'Name', 'Version', 'Size', 'DownloadUrl' # The default property names
            $DefaultDisplayPropertySet = New-Object System.Management.Automation.PSPropertySet('DefaultDisplayPropertySet', [string[]]$DefaultDisplaySet)
            $PSStandardMembers = [System.Management.Automation.PSMemberInfo[]]@($DefaultDisplayPropertySet)

            $Version = ([string]$Reply.tag_name).Trim('Vv ')
            foreach ($Asset in $Reply.assets) 
            {
                if (( !$NameRegex -or $Asset.name -match $NameRegex ) -and
                    ( !$NoZip -or $Asset.name -notmatch '\.(zip|7z)(\.|$)' ) -and
                    ( !$NoTar -or $Asset.name -notmatch '\.tar(\.|$)' ) -and
                    ( !$NoSig -or $Asset.name -notmatch '\.sig$' ))
                {
                    $GithubAsset = [PSCustomObject]@{
                        PsTypename  = 'Github.AssetInfo'    # Give this object a unique typename
                        Name        = $Asset.name
                        Version     = $Version
                        Created     = $Asset.created_at
                        Size        = $Asset.size
                        ContentType = $Asset.content_type
                        DownloadUrl = $Asset.browser_download_url                    
                    } | Add-Member MemberSet PSStandardMembers $PSStandardMembers -PassThru
                    # Alternate way to give this object a unique Typename
                    # $GithubAsset.PSObject.TypeNames.Insert(0, 'User.Information')
                    # Alternate way to give this object PSStandardMembers
                    # Add-Member -InputObject $GithubAsset -MemberType MemberSet -Name PSStandardMembers -Value $PSStandardMembers -PassThru

                    Write-Output $GithubAsset
                }
            }
        }
    }
    catch 
    {
        Write-Error "Error: Failed to retrieve URL for latest GitHub version of '$AccountName/$RepoName' .`n$($_.Exception.Message)"
    }
}

# Examples
# Get-GithubAssetUrl notepad-plus-plus notepad-plus-plus -NoZip -NoSig
# Get-GithubAssetUrl notepad-plus-plus notepad-plus-plus exe -NoSig
# Get-GithubAssetUrl notepad-plus-plus notepad-plus-plus exe -version 8.6.8
# Get-GithubAssetUrl git-for-windows git exe
# Get-GithubAssetUrl microsoft winget-cli | FT # Has a all dependent assets

Get-GithubPkgUrl @PSBoundParameters
