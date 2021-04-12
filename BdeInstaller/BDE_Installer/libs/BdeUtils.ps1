
# Dot Source needed libs
. "$PSScriptRoot\RegistryUtils.ps1" # Nneeded for: Move-RegBorlandSharedDir()

# Script Constants
if ([Environment]::Is64BitProcess)
{
  $WOW6432Node = "\WOW6432Node"
}
$HKCU_Borland = "Registry::HKCU\Software\Borland"
$HKLM_Borland = "Registry::HKLM\SOFTWARE$WOW6432Node\Borland"
$HKLM_Bde = "$HKLM_Borland\Database Engine"



Function Get-BdeInfo
{
  $Retval = [PSCustomObject]@{
    "BDE Version" = "Unknown"
    "Borland Shared" = "Not Installed"
    "BDE Folder"  = "Not Installed"
    "BDE ConfigFile" = ""
    NetLockFile= ""
  }
  $BdePath = Get-BdePath
  if ($BdePath)
  {
    $Retval."BDE Folder" = $BdePath
    $IdapiDLL= "$BdePath\idapi32.dll"
    if ($IdapiDLL -and (Test-Path -Path $IdapiDLL))
    {
      $Retval."BDE Version" = (Get-ChildItem -Path $IdapiDLL).VersionInfo.FileVersion
    }
    $Retval."BDE ConfigFile" = Get-BdeIdapiPath
    $NetDir = Get-BdeNetDir
    if ($NetDir)
    {
      $Retval.NetLockFile = "$NetDir\PDOXUSRS.NET"
    }
  }

  $SharedDir = Get-BorlandSharedDir
  if ($SharedDir)
  {
    $Retval."Borland Shared" = $SharedDir
  }
  
  return $Retval
}


<#
.SYNOPSIS
  Returns the path to the DBE folder as defined in the registry.
#>
Function Get-BdePath
{
  $BdePath = $null
  if ($HKLM_Bde -and (Test-Path $HKLM_Bde))
  {
    $RegProp = Get-ItemProperty -Path $HKLM_Bde -Name "DLLPATH" -ErrorAction SilentlyContinue
    if ($RegProp -and $RegProp.DLLPATH)
    {
      $BdePath = $RegProp.DLLPATH -replace ";.*", "" # Chop off alternate path
      $BdePath = $BdePath.Trim()
      $BdePath = $BdePath.TrimEnd('\') # Remove unwanted trailing \ if present
    }
  }
  return $BdePath
}


<#
.SYNOPSIS
Returns the FilePath to IDAPI32.CFG, as defined in the registry.
This file contains the loction of the global PDOXUSRS.NET lock file
and various database driver configurations and BDE aliases.
Most of these setting can also be found in the BDE registry.
#>
Function Get-BdeIdapiPath
{
  $IdapiPath = $null
  if ($HKLM_Bde -and (Test-Path $HKLM_Bde))
  {
    $RegProp = Get-ItemProperty -Path $HKLM_Bde -Name "CONFIGFILE01" -ErrorAction SilentlyContinue
    if ($RegProp)
    {
      $IdapiPath = $RegProp.CONFIGFILE01
    }
    else
    {      
      $BdePath = Get-BdePath
      if ($BdePath)
      {
        Write-Warning "Failed to find BDE IdapiPath in registry. Falling back to default value."
        $IdapiPath = "$BdePath\IDAPI32.CFG"
      }
    }
  }
  return $IdapiPath
}


<#
.SYNOPSIS
Returns the Paradox NetDir where the global PDOXUSRS.NET lock file 
is located. The NetDir path is stored in the IDAPI32.CFG file.
#>
Function Get-BdeNetDir
{
  $BdeNetDir = $null
  $IdapiPath = Get-BdeIdapiPath
  if ($IdapiPath -and (Test-Path $IdapiPath))
  {
    $OrgText = Get-Content -Path $IdapiPath -Raw -Encoding Ascii
    [int]$p0 = $OrgText.IndexOf("NET DIR`0")
    if ($OrgText[$p0] -eq "N")
    {
      $p0 += 10
      [int]$p1 = $OrgText.IndexOf("`0", $p0)
      $BdeNetDir = $OrgText.Substring($p0, $p1-$p0)
      $BdeNetDir = $BdeNetDir.TrimEnd("\")
      if ($BdeNetDir -match "Location of the app")
      {
        Write-Warning "Failed to find Paradox lockfile location. Falling back to default value."
        $BdeNetDir = $ENV:SystemDrive
      }
    }
  }
  return $BdeNetDir
}


<#
.SYNOPSIS
Modifies the Paradox NetDir where the global PDOXUSRS.NET lock file is located
The new NetDir path is written to the IDAPI32.CFG file.
#>
Function Set-BdeNetDir([string]$NetDir, [string]$IdapiFile)
{
  if (!$IdapiFile)
  {
    $IdapiFile = Get-BdeIdapiPath
  }
  if ($WhatIfPreference)
  {
    Write-Host "What if: Modifying idapi32.cfg file with new 'BDE network lockfile dir': $NetDir"
    return
  }
  if ($IdapiFile -and (Test-Path -Path $IdapiFile))
  {
    $OrgText = Get-Content -Path $IdapiFile -Raw -Encoding Ascii
    [int]$p0 = $OrgText.IndexOf("NET DIR`0")
    if ($OrgText[$p0] -eq "N")
    {
      $p0 += 10
      [int]$p1 = $OrgText.IndexOf("`0", $p0)
      $NewText = $OrgText.Remove($p0, $p1-$p0)
      $NewText = $NewText.Insert($p0, $NetDir)
      Move-Item -Path $IdapiFile -Destination "$IdapiFile`.bak" -Force
      Set-Content -Value $NewText -Path $IdapiFile -Encoding Ascii -NoNewline
      return
    }
    Write-Warning "Failed to write new 'BDE network lockfile dir' into file: $IdapiFile"
  }
  Write-Warning "Failed to write new 'BDE network lockfile dir' because the idapi file was not found: $IdapiFile"
}



function New-DesktopShortcut([string]$Name, [string]$TargetPath, [switch]$RunAsAdmin)
{
  $LinkFile = "$Home\Desktop\$Name.lnk"
  $WshShell = New-Object -comObject WScript.Shell
  $Shortcut = $WshShell.CreateShortcut($LinkFile)
  $Shortcut.TargetPath = $TargetPath
  $Shortcut.Save()

  if ($RunAsAdmin)
  {
    $bytes = [System.IO.File]::ReadAllBytes($LinkFile)
    $bytes[0x15] = $bytes[0x15] -bor 0x20 #set byte 21 (0x15) bit 6 (0x20) ON
    [System.IO.File]::WriteAllBytes($LinkFile, $bytes)
  }
}


<#
.SYNOPSIS
  Deletes all the BDE files and folders.
  Note: We use the Registry settings to figure out where the 
  files & folders are located.
#>
Function Remove-BdeFiles
{
  $BdeNetDir = Get-BdeNetDir
  if (Test-Path -Path "$BdeNetDir\PDOXUSRS.NET")
  {
    Remove-Item -Path "$BdeNetDir\PDOXUSRS.NET" -Force -ErrorAction SilentlyContinue
  }

  $IdapiPath = Get-BdeIdapiPath
  if ($IdapiPath -and (Test-Path -Path $IdapiPath))
  {
    Remove-Item -Path $IdapiPath -Force -ErrorAction SilentlyContinue
  }

  $BdePath = Get-BdePath
  if ($BdePath -and (Test-Path -Path $BdePath))
  {
    if (Test-Path "$BdePath\disp.dll")
    {
      Start-Process -FilePath "regsvr32.exe" -ArgumentList "/s, /u, $BdePath\disp.dll" -Wait
    }
    if (Test-Path "$BdePath\idsql32.dll")
    {
      Start-Process -FilePath "regsvr32.exe" -ArgumentList "/s, /u, $BdePath\idsql32.dll" -Wait
    }
    if (Test-Path "$BdePath\idapi32.dll")
    {
      Start-Process -FilePath "regsvr32.exe" -ArgumentList "/s, /u, $BdePath\idapi32.dll" -Wait
    }  
    Remove-Item -Path $BdePath -Recurse -Force -ErrorAction SilentlyContinue
  }

  # Desktop Shortcuts
  $WshShell = New-Object -comObject WScript.Shell
  foreach ($File in (Get-ChildItem -Path "$Home\Desktop\*.lnk"))
  {
    $Link = $WshShell.CreateShortcut($File.FullName)
    if ($Link.TargetPath -match "BDE")
    {
      $File | Remove-Item -Force -ErrorAction SilentlyContinue
    }
  }
}


<#
.SYNOPSIS
  Delete the registry properties that match the regex expression $NameRegx
#>
Function Remove-RegProperty($Path, [string] $NameRegx)
{
  $Key = Get-Item -Path $Path -ErrorAction SilentlyContinue
  if ($Key)
  {
    $PropS = $Key.Property | Where-Object { $_ -match $NameRegx }
    foreach ($Prop in $PropS)
    {
      $Key | Remove-ItemProperty -Name $Prop
    }
  }
}


<#
.SYNOPSIS
  Delete the BDE Registry settings
#>
Function Remove-BdeRegistry
{
  if (Test-Path "$PSScriptRoot\BdeInst.dll")
  {
    Start-Process -FilePath "regsvr32.exe" -ArgumentList "/s, /u, $PSScriptRoot\BdeInst.dll" -Wait
  }

  #idsql32.dll
  Remove-Item -Path "Registry::HKCR$WOW6432Node\CLSID$WOW6432Node\CLSID\{FB99D700-18B9-11D0-A4CF-00A024C91936}" -Recurse -Force -ErrorAction SilentlyContinue
  Remove-Item -Path "Registry::HKLM\SOFTWARE\Classes$WOW6432Node\CLSID\{FB99D700-18B9-11D0-A4CF-00A024C91936}" -Recurse -Force -ErrorAction SilentlyContinue
  Remove-Item -Path "Registry::HKLM\SOFTWARE$WOW6432Node\Classes\CLSID\{FB99D700-18B9-11D0-A4CF-00A024C91936}" -Recurse -Force -ErrorAction SilentlyContinue

  #idapi32.dll
  Remove-Item -Path "Registry::HKCR$WOW6432Node\CLSID$WOW6432Node\CLSID\{FB99D710-18B9-11D0-A4CF-00A024C91936}" -Recurse -Force -ErrorAction SilentlyContinue
  Remove-Item -Path "Registry::HKLM\SOFTWARE\Classes$WOW6432Node\CLSID\{FB99D710-18B9-11D0-A4CF-00A024C91936}" -Recurse -Force -ErrorAction SilentlyContinue
  Remove-Item -Path "Registry::HKLM\SOFTWARE$WOW6432Node\Classes\CLSID\{FB99D710-18B9-11D0-A4CF-00A024C91936}" -Recurse -Force -ErrorAction SilentlyContinue

  #disp.dll
  Remove-Item -Path "Registry::HKCR\TypeLib\{C20F7C3D-8919-11D1-AA74-00C04FA30E92}" -Recurse -Force -ErrorAction SilentlyContinue
  Remove-Item -Path "Registry::HKCR$WOW6432Node\TypeLib\{C20F7C3D-8919-11D1-AA74-00C04FA30E92}" -Recurse -Force -ErrorAction SilentlyContinue
  Remove-Item -Path "Registry::HKLM\SOFTWARE\Classes\TypeLib\{C20F7C3D-8919-11D1-AA74-00C04FA30E92}" -Recurse -Force -ErrorAction SilentlyContinue
  Remove-Item -Path "Registry::HKLM\SOFTWARE\Classes$WOW6432Node\TypeLib\{C20F7C3D-8919-11D1-AA74-00C04FA30E92}" -Recurse -Force -ErrorAction SilentlyContinue
  Remove-Item -Path "Registry::HKLM\SOFTWARE$WOW6432Node\Classes\TypeLib\{C20F7C3D-8919-11D1-AA74-00C04FA30E92}" -Recurse -Force -ErrorAction SilentlyContinue

  # BDE Config hives
  Remove-Item -Path "Registry::HKCR$WOW6432Node\CLSID\Borland.Database_Engine.4" -Recurse -Force -ErrorAction SilentlyContinue
  Remove-Item -Path "Registry::HKLM\SOFTWARE\Classes\Borland.Database_Engine.4" -Recurse -Force -ErrorAction SilentlyContinue
  Remove-Item -Path "$HKLM_Borland\BLW32" -Recurse -Force -ErrorAction SilentlyContinue
  Remove-Item -Path $HKLM_Bde -Recurse -Force -ErrorAction SilentlyContinue

  #BdeAdmin application
  Remove-Item -Path "$SystemRoot\system\bdeadmin.cpl" -Force -ErrorAction SilentlyContinue
  Remove-Item -Path "$HKCU_Borland\bdeadmin" -Recurse -Force -ErrorAction SilentlyContinue
  $Sid = [Security.Principal.WindowsIdentity]::GetCurrent().user.value
  Remove-RegProperty -NameRegx "bdeadmin" -Path "Registry::HKCU\Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Compatibility Assistant\Store"
  Remove-RegProperty -NameRegx "bdeadmin" -Path "Registry::HKU\$Sid\Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Compatibility Assistant\Store"
  Remove-RegProperty -NameRegx "bdeadmin" -Path "Registry::HKLM\SOFTWARE$WOW6432Node\Microsoft\Windows\Help"
}


<#
.SYNOPSIS
  Delete BDE Files, Folders & Registry entries
#>
Function Remove-Bde
{
  Remove-BdeFiles
  Remove-BdeRegistry
}


<#
.SYNOPSIS
  Returns the path to the "Borland\Common Files" folder as defined in the registry.
#>
function Get-BorlandSharedDir
{
  # 1st try: Clean DBE install - on Windows-10
  $ShareDir = Get-BdePath
  if ($ShareDir)
  {
    $ShareDir = $ShareDir -replace "\\BDE", "\"
  }
  else 
  {
    # 2nd Try: Delphi development environment
    $RegProp = Get-ItemProperty -Path "$HKLM_Borland\Borland Shared" -Name "SharedFilesDir" -ErrorAction SilentlyContinue
    if ($RegProp)
    {
      $ShareDir = $RegProp.SharedFilesDir
    }
  }
  return $ShareDir
}


<#
.SYNOPSIS
  Edits all the registry entries that contain a reference to the "\Borland Shared\"
  directory to the new $Path
#>
function Move-RegBorlandSharedDir
{
  [CmdletBinding(SupportsShouldProcess)]
  param(
    [Parameter()]
    [string] $Path = "C:\Borland\Shared",

    [Parameter()]
    [switch] $AllRegistryKeys     
  )

  # Clean up input
  $NewSharedDir = $Path.Trim()
  if ($NewSharedDir.EndsWith("\"))
  {
    $NewSharedDir = $NewSharedDir.Substring(0, $NewSharedDir.Length -1)
  }

  # Initialize $RegexDir with old OldSharedDir
  $OldSharedDir = Get-BorlandSharedDir
  if (!(Test-Path -Path $OldSharedDir))
  {
    Write-Host "Error: Cannot find the \Borland Shared\ folder: '$OldSharedDir'" -ForegroundColor Red
    return
  }
  if ($OldSharedDir.EndsWith("\"))
  {
    $OldSharedDir = $OldSharedDir.Substring(0, $OldSharedDir.Length -1)
  }
  $RegexDir = $OldSharedDir -Replace "\\", "\\" -replace "\(", "\(" -replace "\)", "\)"

  # Check if we need to actually make any changes
  if ($OldSharedDir -eq $NewSharedDir)
  {
    Write-Host "Error: The Source and Destination are the same: $OldSharedDir" -ForegroundColor Red
    return
  }

  if ($AllRegistryKeys)
  {
    # Search the entier Registry. Note this will take a significant larger amount of time
    $BDE_Roots = @(
      "Registry::HKCR"
      "Registry::HKCU"
      "Registry::HKLM"
    )
  }
  else 
  {
    # Its faster to only search these well known locations that contain a BdePath
    $BDE_Roots = @(
      "Registry::HKCR\TypeLib"
      "Registry::HKCR\Applications"
      "Registry::HKCR\Borland*"
      "Registry::HKCR\Delphi*"
      "Registry::HKCR$WOW6432Node\CLSID"
      "Registry::HKCR$WOW6432Node\TypeLib" #64-
      "Registry::HKCR\VirtualStore\MACHINE\SOFTWARE\Borland" #32

      "Registry::HKCU\SOFTWARE\Borland"
      "Registry::HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion" #64
      "Registry::HKCU\SOFTWARE\Microsoft\Windows NT\CurrentVersion\AppCompatFlags"
      "Registry::HKCU\SOFTWARE\Classes\Applications" #32
      "Registry::HKCU\SOFTWARE\Classes\VirtualStore\MACHINE\SOFTWARE" #32
      
      "Registry::HKLM\SOFTWARE\Classes$WOW6432Node"
      "Registry::HKLM\SOFTWARE\Classes\TypeLib"
      "Registry::HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths"
      "Registry::HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Installer"
      "Registry::HKLM\SOFTWARE$WOW6432Node\Classes\CLSID"
      "Registry::HKLM\SOFTWARE$WOW6432Node\Classes\TypeLib" #64-
      "Registry::HKLM\SOFTWARE$WOW6432Node\Microsoft\Windows\CurrentVersion\SharedDlls"
      "Registry::HKLM\SOFTWARE$WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
      "Registry::HKLM\SOFTWARE$WOW6432Node\Microsoft\Windows\Help"
      "Registry::HKLM\SYSTEM\ControlSet001\Control\Session Manager\Environment"
      "Registry::HKLM\SOFTWARE$WOW6432Node\Borland"
    ) 
    $BDE_Roots = $BDE_Roots | Sort-Object -Unique # Needed when $WOW6432Node=$null, 32bit
  }

  $KeyStack = New-Object -TypeName "System.Collections.Stack"
  $BDE_Roots | Get-RegKey -Recurse -ErrorAction SilentlyContinue | ForEach-Object {
    $ShowKey = $true
    foreach ($Name in $_.GetValueNames())
    {   
      # Rename the Property Value
      $Value = $_.GetValue($Name)
      if ($Value -match $RegexDir)
      {
        if ($ShowKey)
        {
          Write-Host $_.Name -ForegroundColor White
          $ShowKey = $false
        }
        if (!$Name)
        {
          $Name = "(default)"
        }  
        if ($WhatIfPreference)
        {
          Write-Host "What if:    $Name = $Value"
        }
        else 
        {
          $NewValue = $Value -Replace $RegexDir, $NewSharedDir
          Write-Host "    $Name = $NewValue"
          Set-ItemProperty -Path $_.PsPath -Name $Name -Value $NewValue
        }
      }

      # Rename the Property Name
      if ($Name -match $RegexDir)
      {
        if ($ShowKey)
        {
          Write-Host $_.Name -ForegroundColor White
          $ShowKey = $false
        }
        if ($WhatIfPreference)
        {
          Write-Host "What if:    $Name"
        }
        else 
        {
          $NewName = $Name -Replace $RegexDir, $NewSharedDir
          Write-Host "    $NewName" 
          Rename-ItemProperty -Path $_.PsPath -Name $Name -NewName $NewName
        }
      }
    }

    # The Keys must be processed in reversed order (deepest keys first)
    if ($_.PSChildName -match $RegexDir)
    {
      $KeyStack.Push($_)
    }
  }

  # Now we can finally rename the Keys in reversed order (deepest keys first)
  while ($KeyStack.Count) 
  {
    $Key = $KeyStack.Pop()
    if ($WhatIfPreference)
    {
      Write-Host "What if: $($Key.Name)"
    }
    else 
    {
      $NewName = $Key.PSChildName -Replace $RegexDir, $NewSharedDir
      Write-Host "$($Key.Name) -> $NewName"
      Rename-Item -Path $Key.PsPath -NewName $NewName                
    }
  }        
}
