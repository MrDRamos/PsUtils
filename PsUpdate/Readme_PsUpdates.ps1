<#################################################################
Command tp install both Visual Studio Code & PowerShell extension
#################################################################>
{
  #### Install both Visual Studio Code & PowerShell extension by running the following command:
  Invoke-Expression (Invoke-RestMethod 'https://raw.githubusercontent.com/PowerShell/vscode-powershell/master/scripts/Install-VSCode.ps1')

  #### Just Install/Update Powershell 7 with with Explorer integration & WinRm
  Invoke-Expression "& { $(Invoke-RestMethod 'https://aka.ms/install-powershell.ps1') } -UseMSI -Quiet -AddExplorerContextMenu -EnablePSRemoting"
}



<#################################################################
  PowerShellGet & PackageManagement modules.
  After you have installed PowerShell, make sure to update PowerShellGet and the PackageManagement modules.
#################################################################>
{
  # Show installed vs. Latest Version availible of PowerShellGet & PackageManagement modules
  Powershell -noprofile -command "Find-Module PackageManagement, PowerShellGet -Repository PSGallery | Select-Object Version,Name,Repository"
  Powershell -noprofile -command "Get-Module -ListAvailable PackageManagement, PowerShellGet | Select-Object Version,Name,Path"

  # Before updating PowerShellGet or PackageManagement, you should always install the latest NuGet provider.
  [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
  Install-PackageProvider Nuget –force –verbose
  
  # Run from Admin DOS prompt to avoid locked files conflicts because the module was already loaded	
  Powershell -noprofile -command "Install-Module -Name PackageManagement -Force -Scope AllUsers -Repository PsGallery -AllowClobber"
  #Powershell -noprofile -command "Update-Module -Name PackageManagement -Force -Scope AllUsers"  

  # Run from Admin DOS prompt to avoid locked files conflicts because the module was already loaded	
  Powershell -noprofile -command "Install-Module –Name PowerShellGet -Force -Scope AllUsers -Repository PsGallery -AllowClobber"
  #Powershell -noprofile -command "Update-Module -Name PowerShellGet -Force -Scope AllUsers"  
}


<#################################################################
PSReadline modules.
Doc: https://github.com/PowerShell/PSReadLine#install-from-powershellgallery-preferred  
#################################################################>
{
  # Show installed vs. Latest Version availible of PSReadline
  Find-Module PsReadline -Repository PsGallery | Select-Object Version,Name,Repository
  #Find-Module PsReadline | Select-Object Version,Name,Repository
  Get-Module PsReadline -ListAvailable | Select-Object Version,Name,Path

  # There are separate versions:  PowerShell Core & Desktop. From an Admin prompt:
  if ($PSVersionTable.PSEdition -eq "Desktop")
  {
    # Desktop: Run from Admin DOS prompt to avoid locked files conflicts because the module was already loaded	
    Powershell -noprofile -command "Install-Module PSReadLine -AllowClobber -Force -Scope AllUsers -Repository PsGallery -SkipPublisherCheck"
    #Powershell -noprofile -command "Update-Module PSReadLine -Force"
  } else {
    # Core: Run from Admin DOS prompt to avoid locked files conflicts because the module was already loaded	
    pwsh -noprofile -command "Install-Module PSReadLine -AllowClobber -Force -Scope AllUsers -Repository PsGallery -SkipPublisherCheck"
    #pwsh  -noprofile -command "Update-Module PSReadLine -Force"
  }  
}



