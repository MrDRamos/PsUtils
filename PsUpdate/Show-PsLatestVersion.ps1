Write-Host "GitHub Links:" -ForegroundColor Cyan
([psCustomObject]@{
    Downloads =	"https://github.com/powershell/powershell#get-powershell"
    ChangeLog = "https://github.com/PowerShell/PowerShell/tree/master/CHANGELOG"
    Releases  = "https://github.com/PowerShell/PowerShell/releases"
} | Format-List | Out-String).Trim()

Write-Host "`nRelease Versions:" -ForegroundColor Cyan
$metadata = Invoke-RestMethod "https://raw.githubusercontent.com/PowerShell/PowerShell/master/tools/metadata.json"
($metadata | Format-List | Out-String).Trim()

Write-Host "`nDaily Builds:" -ForegroundColor Cyan
$metadata = Invoke-RestMethod "https://aka.ms/pwsh-buildinfo-daily"
($metadata | Format-List | Out-String).Trim()

Write-Host "`nInstalled Version:" -ForegroundColor Cyan
([psCustomObject]$PSVersionTable | Format-List -Property PsEdition, PsVersion | Out-String).Trim()

Write-Host "`nUpdate stable release using: Install-Powershell.ps1`:" -ForegroundColor Cyan
@"
Reference = https://www.thomasmaurer.ch/2019/07/how-to-install-and-update-powershell-7/
# Quiet install with Explorer integration and WinRm:
  Invoke-RestMethod -Method Get -Uri "https://aka.ms/Install-Powershell.ps1" -OutFile .\Install-Powershell.ps1
  .\Install-Powershell.ps1 -UseMSI -AddExplorerContextMenu -EnablePSRemoting -Quiet

# 1-Liner Interactive MSI install:
  Invoke-Expression "& { `$(Invoke-RestMethod 'https://aka.ms/install-powershell.ps1') } -UseMSI"

"@ | Write-Host
