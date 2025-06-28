Param(
    # The $InstallMethod was selected by the user in the parent script.
    # We now use it to install PowerShell while running within the contect of the Desktop edition of PowerShell.
    # Note: PowerShell can not be installed from within the PowerShell Core edition.
    [Parameter(Mandatory = $false)]
    [int]$InstallMethod = 0
)    


function Get-InstalledPowerShellVersion
{
    # Get the currently installed PowerShell version
    $PwshCmd = Get-Command 'pwsh.exe' -ErrorAction Ignore
    if ($PwshCmd)
    {
        $PsVer = ($PwshCmd.FileVersionInfo.ProductVersion -split ' ')[0]
        return $PsVer
    }
    else
    {
        return "PowerShell is not installed."
    }
}


function Get-GitPsReleaseInfo
{
  $metadata = Invoke-RestMethod "https://raw.githubusercontent.com/PowerShell/PowerShell/master/tools/metadata.json"
  return ($metadata | Format-List StableReleaseTag, PreviewReleaseTag, LTSReleaseTag | Out-String).Trim()
}


# Get the latest PowerShell release url
function Get-GitPsReleaseDownloadURL
{
  Param(
    [Parameter(Mandatory = $false)]
    [ValidateSet('Stable', 'Preview', 'LTS')]
    [string]$ReleaseType = 'Stable'
  )

  $metadata = Invoke-RestMethod "https://raw.githubusercontent.com/PowerShell/PowerShell/master/tools/metadata.json"
  $release = $metadata."${ReleaseType}ReleaseTag" -replace '^v'
  $PackageName = "PowerShell-${release}-win-x64.msi"
  $DownloadURL = "https://github.com/PowerShell/PowerShell/releases/download/v${release}/${PackageName}"
  return $DownloadURL
}
<# Test
Get-GitPsReleaseDownloadURL
exit
#>


function Invoke-InstallMethod
{
    Param(
        [Parameter()]
        [int]$InstallMethod = 0
    )

    switch ($InstallMethod) 
    { 
        1 { Invoke-Expression "& { $(Invoke-RestMethod 'https://aka.ms/install-powershell.ps1') } -UseMSI" }
        2 { & winget install --id Microsoft.Powershell --source winget }
        3 { 
            $DownloadURL = Get-GitPsReleaseDownloadURL -ReleaseType 'Stable'
            $PackageName = $DownloadURL | Split-Path -Leaf
            Invoke-WebRequest -Uri $DownloadURL -OutFile $PackageName 
        }
        4 { Invoke-RestMethod -Method Get -Uri "https://aka.ms/Install-Powershell.ps1" -OutFile .\Install-Powershell.ps1 }    
        Default {
            Write-Host "Press <Enter> to conclude this test" -ForegroundColor Magenta
            Read-Host
          }
    }
} 



##### Main script execution starts here #####
#$InstallMethod = 5 ##DD # For testing purposes only
if ($InstallMethod -eq 0)
{
    # Show usefull PowerShell GitHub links
    Write-Host "GitHub Links:" -ForegroundColor Cyan
    ([psCustomObject]@{
        Downloads =	"https://github.com/powershell/powershell#get-powershell"
        ChangeLog = "https://github.com/PowerShell/PowerShell/tree/master/CHANGELOG"
        Releases  = "https://github.com/PowerShell/PowerShell/releases"
        Install   = 'https://learn.microsoft.com/en-us/powershell/scripting/install/installing-powershell-on-windows'
    } | Format-List | Out-String).Trim()

    # Show the latest PowerShell version information
    Write-Host "`nRelease Versions:" -ForegroundColor Cyan
    Get-GitPsReleaseInfo | Write-Host

    # Show the currently installed PowerShell version
    Write-Host "`nInstalled Version: " -ForegroundColor Cyan -NoNewline
    $PsVer = Get-InstalledPowerShellVersion
    Write-Host $PsVer

    # Get the URL for the latest PowerShell release
    $DownloadURL = Get-GitPsReleaseDownloadURL -ReleaseType 'Stable'
    $PackageName = $DownloadURL | Split-Path -Leaf

    # Show user options for installing PowerShell
    Write-Host "`nInstall Options:" -ForegroundColor Cyan
@"
[1] Install using Custom-Installer script:
  Invoke-Expression "& { `$(Invoke-RestMethod 'https://aka.ms/install-powershell.ps1') } -UseMSI"

[2] Install using winget:
  winget install --id Microsoft.Powershell --source winget

[3]* Download Stable MSI-Installer: $($metadata.StableReleaseTag)
  IRM $DownloadURL -Outfile $PackageName

[4]* Download Custom-Installer script: (see https://www.thomasmaurer.ch/2019/07/how-to-install-and-update-powershell-7/)
  Invoke-RestMethod -Method Get -Uri "https://aka.ms/Install-Powershell.ps1" -OutFile .\Install-Powershell.ps1

Note-1: Close all running PowerShell sessions before installing a new version.
Note-*: The installers must run from a DOS or PowerShell-Desktop edition console.
"@ | Write-Host

    Write-Host "Select an install option: 1..4 or 0 to exit: " -ForegroundColor Yellow -NoNewline
    $UsrVal = Read-Host
    [int]$InstallMethod = $UsrVal -as [int]

    if ($InstallMethod -in 1,2,5)
    {
        # Note: PowerShell can not be installed from within the PowerShell Core edition.
        # So we need to run the installation script within the context of PowerShell Desketop edition.
        Write-Host "`nStarting PowerShell Desktop edition to run installation ..." -ForegroundColor Cyan`
        $Cwd = $PSScriptRoot
        $ParamS = @{
            FilePath = 'powershell.exe'
            ArgumentList = '-NoLogo','-NoProfile', '-ExecutionPolicy Bypass', "-Command CD $Cwd; .\Show-PsLatestVersion.ps1 -InstallMethod $InstallMethod"
            Verb = 'RunAs'
            Wait = $true
          #  WindowStyle = 'Minimized'
        }
        Start-Process @ParamS
        Write-Host "`nInstalled Version: " -ForegroundColor Cyan -NoNewline
        $PsVer = Get-InstalledPowerShellVersion
        Write-Host $PsVer
    }
    elseif ($InstallMethod -eq 3)
    {
        Invoke-InstallMethod -InstallMethod $InstallMethod
        Write-Host "Finished downloading MSI-Installer: .\$PackageName"
    }
    elseif ($InstallMethod -eq 4)
    {
        Invoke-InstallMethod -InstallMethod $InstallMethod
        Write-Host 'Finished downloading Custom-Installer script'
        Write-Host 'Options to invoke a quite install with Explorer integration:'
        Write-Host '.\Install-Powershell.ps1 -UseMSI -AddExplorerContextMenu -Quiet'
    }
    exit 0
}
else
{
    Write-Host "Running in: $($PWD.Path)"
    Write-Host "Installing PowerShell using method #$InstallMethod ..."
    Invoke-InstallMethod -InstallMethod $InstallMethod
}
