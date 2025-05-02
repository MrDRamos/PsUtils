<#
.SYNOPSIS
  A wrapper around Invoke-WebRequest to download a file from a URL
  Its designed to take objects returned by Get-GithubPkgUri

.EXAMPLE
Downloads 2 files: The latest x64 version of Notepad++ and the SHA signature check file 
into a VersionFolder sub directory.
Get-GithubAssetUrl notepad-plus-plus notepad-plus-plus '(x64|sha)' -NoZip -NoSig | Get-GithubPkg
#>
#<##DD un-comment for debugging
[CmdletBinding(DefaultParameterSetName = 'ByPipe')]
param (
    [Parameter(ValueFromPipeline, ParameterSetName = "ByPipe")]
    [ValidateNotNullOrEmpty()]
    [array] $InputObject,

    [Parameter(ParameterSetName = "Direct")]
    [Alias('Url', 'Uri')]
    [ValidateNotNullOrEmpty()]
    [string] $DownloadUrl,

    [Parameter(ParameterSetName = "Direct")]
    [string] $ContentType = $null,

    [Parameter(ParameterSetName = "Direct")]
    [ValidateNotNullOrEmpty()]
    [string] $Destination = $PWD.ProviderPath,
    
    [Parameter()]
    [Alias('Version')]
    [string] $VersionFolder = $null,

    [Parameter(ParameterSetName = "Direct")]
    [Alias('Pkg', 'Package')]
    [ValidateNotNullOrEmpty()]
    [string] $Name,

    [Parameter()]
    [switch] $HideProgress
)
#>



 <#
.SYNOPSIS
  A wrapper around Invoke-WebRequest to download a file from a URL
  Its designed to take objects returned by Get-GithubPkgUri

.EXAMPLE
Downloads 2 files: The latest x64 version of Notepad++ and the SHA signature check file 
into a VersionFolder sub directory.
Get-GithubAssetUrl notepad-plus-plus notepad-plus-plus '(x64|sha)' -NoZip -NoSig | Get-GithubPkg

#>
function Get-GithubPkg
{
    [CmdletBinding(DefaultParameterSetName = 'ByPipe')]
    param (
        [Parameter(ValueFromPipeline, ParameterSetName = "ByPipe")]
        [ValidateNotNullOrEmpty()]
        [array] $InputObject,

        [Parameter(ParameterSetName = "Direct")]
        [Alias('Url', 'Uri')]
        [ValidateNotNullOrEmpty()]
        [string] $DownloadUrl,

        [Parameter(ParameterSetName = "Direct")]
        [string] $ContentType = $null,

        [Parameter(ParameterSetName = "Direct")]
        [ValidateNotNullOrEmpty()]
        [string] $Destination = $PWD.ProviderPath,
    
        [Parameter()]
        [Alias('Version')]
        [string] $VersionFolder = $null,

        [Parameter(ParameterSetName = "Direct")]
        [Alias('Pkg', 'Package')]
        [ValidateNotNullOrEmpty()]
        [string] $Name,

        [Parameter()]
        [switch] $HideProgress
    )

    if ($Input)
    {
        $InputObject = [array]$Input
    }

    if (!$InputObject)
    {
        [array]$InputObject = @{
            Name          = $Name
            VersionFolder = $VersionFolder
            ContentType   = $ContentType
            DownloadUrl   = $DownloadUrl
        }
    }
    if (!$VersionFolder)
    {
        $VersionFolder = $InputObject[0].Version
    }

    $OrgProgPref = $null
    if ($HideProgress)
    {
        $OrgProgPref = $Global:ProgressPreference
        $Global:ProgressPreference = 'SilentlyContinue'
    }

    foreach ($Inp in $InputObject) 
    {
        try 
        {
            if (![string]::IsNullOrWhiteSpace($Inp.DownloadUrl) -and ![string]::IsNullOrWhiteSpace($Inp.Name))
            {
                $OutDir = Join-Path -Path $Destination -ChildPath $VersionFolder
                $null = New-Item -ItemType Directory -Path $OutDir -Force -ErrorAction Ignore
                $OutFile = Join-Path -Path $OutDir -ChildPath $Inp.Name
                Write-Host "Downloading: $OutFile" -ForegroundColor Cyan
                Invoke-WebRequest -Method Get -Uri $Inp.DownloadUrl -ContentType $Inp.ContentType -OutFile $OutFile
            }            
        }
        catch 
        {
            Write-Host $_.Exception.Message -ForegroundColor Red
        }
    }

    if ($OrgProgPref)
    {
        $Global:ProgressPreference = $OrgProgPref
    }
}
# Examples
# & $PsScriptRoot\Get-GithubPkgUrl.ps1 notepad-plus-plus notepad-plus-plus '(x64|sha)' -NoZip -NoSig | Get-GithubPkg
# & Get-GithubPkgUrl notepad-plus-plus notepad-plus-plus '(x64|sha)' -NoZip -NoSig | Get-GithubPkg -VersionFolder 'TheLatest' -HideProgress

Get-GithubPkg @PSBoundParameters
