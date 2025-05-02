[CmdletBinding()]
param (
    [Parameter()]
    [string] $Version = $null,

    [Parameter()]
    [string] $PkgType = 'x64\.msi'
)


[array]$GithubAssetS = & "$PsScriptRoot\Get-GithubPkgUrl.ps1" -AccountName 'PowerShell' -RepoName 'PowerShell' -NameRegex $PkgType
if ($GithubAssetS.Count -eq 0)
{
    Throw "Failed to retrieve Github download URL's" 
}
& "$PsScriptRoot\Get-GithubPkg.ps1" -InputObject $GithubAssetS -VersionFolder '.\' #-HideProgress
