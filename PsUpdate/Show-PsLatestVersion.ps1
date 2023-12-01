Write-Host "GitHub Links:" -ForegroundColor Cyan
([psCustomObject]@{
    Downloads =	"https://github.com/powershell/powershell#get-powershell"
    ChangeLog = "https://github.com/PowerShell/PowerShell/tree/master/CHANGELOG"
    Releases  = "https://github.com/PowerShell/PowerShell/releases"
    Install   = 'https://learn.microsoft.com/en-us/powershell/scripting/install/installing-powershell-on-windows'
    MsiPkgUrl = "`"https://github.com/PowerShell/PowerShell/releases/download/v`$VER/PowerShell-`$VER-win-x64.msi`""
} | Format-List | Out-String).Trim()

Write-Host "`nRelease Versions:" -ForegroundColor Cyan
$metadata = Invoke-RestMethod "https://raw.githubusercontent.com/PowerShell/PowerShell/master/tools/metadata.json"
($metadata | Format-List StableReleaseTag, PreviewReleaseTag, LTSReleaseTag | Out-String).Trim()

<#
Write-Host "`nDaily Builds:" -ForegroundColor Cyan
$metadata = Invoke-RestMethod "https://aka.ms/pwsh-buildinfo-daily"
($metadata | Format-List | Out-String).Trim()
#>

Write-Host "`nInstalled Version: " -ForegroundColor Cyan -NoNewline
#([psCustomObject]$PSVersionTable | Format-List -Property PsEdition, PsVersion | Out-String).Trim()
$PwshCmd = Get-Command 'pwsh.exe' -ErrorAction Ignore
$PsVer = ""
if ($PwshCmd)
{
    $PsVer = ($PwshCmd.FileVersionInfo.ProductVersion -split ' ')[0]
}
Write-Host $PsVer

Write-Host "`nInstall stable release using:" -ForegroundColor Cyan
@"
#1) 1-Liner Interactive MSI install:
  Invoke-Expression "& { `$(Invoke-RestMethod 'https://aka.ms/install-powershell.ps1') } -UseMSI"

#2) Download Stable MSI Release: $($metadata.StableReleaseTag)

#3) Install using winget:
  winget install --id Microsoft.Powershell --source winget

#4) Download installer script: (see https://www.thomasmaurer.ch/2019/07/how-to-install-and-update-powershell-7/)
  Invoke-RestMethod -Method Get -Uri "https://aka.ms/Install-Powershell.ps1" -OutFile .\Install-Powershell.ps1
"@ | Write-Host

switch (Read-Host -Prompt "`n? Install now using method #1..4 ") 
{ 
    1 { Invoke-Expression "& { $(Invoke-RestMethod 'https://aka.ms/install-powershell.ps1') } -UseMSI" }
    2 {
        $metadata = Invoke-RestMethod "https://raw.githubusercontent.com/PowerShell/PowerShell/master/tools/metadata.json"
        $release = $metadata.StableReleaseTag -replace '^v'
        $packageName = "PowerShell-${release}-win-x64.msi"
        $downloadURL = "https://github.com/PowerShell/PowerShell/releases/download/v${release}/${packageName}"
        Write-Host "Downloading from: $downloadURL"
        Invoke-WebRequest -Uri $downloadURL -OutFile $packageName
      }
    3 { & winget install --id Microsoft.Powershell --source winget }
    4 {
        Invoke-RestMethod -Method Get -Uri "https://aka.ms/Install-Powershell.ps1" -OutFile .\Install-Powershell.ps1
        Write-Host '#User script to invoke quite install with Explorer integration:' -ForegroundColor Cyan
        Write-Host '.\Install-Powershell.ps1 -UseMSI -AddExplorerContextMenu -Quiet'
      }    
    Default {}
}

