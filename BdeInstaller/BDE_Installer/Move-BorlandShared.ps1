
<#
.SYNOPSIS
 Moves all the Borland Shared\application folders from
 C:\Program Files\Common Files\Borland Shared\  =>  C:\Borland\Shared\
 The new folder locations are writable by a standard user account. 
 It also modifies the associated registry entries to point to
 the new folder locations.

.DESCRIPTION
 The default installation directories for the BDE (Borland Database Endine)
 and related tools are under C:\Program Files\Common Files\Borland Shared\

 These older applications were written before Windows 8 and therefore assume
 that writing to the system installation directories is allowed. 
 But since Windows 8 writing to the system folders: 
    C:\Windows
    C:\Program Files\
    C:\Program Files (x86)\ 
 is no longer allowed for a standerd user account. 

 The Windows workaround for this problem is to transparently map write requests to
 the locked down system folders to a new virtual directory under the user account.
 e.g. C:\ -> C:\users\<name>\AppData\Local\VirtualStore\

 This only works for programs that are not shared by other users. 
 But applications like the BDE require that all users have access to comman shared
 configuration file: idapi32.cfg, And to the BDE lock files:
    PDOXUSRS.NET    // For global network locks
    PARADOX.LCK     // For directory locks
    PDOXUSRS.LCK    // For file locks
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string] $NewSharedDir = "C:\Borland\Shared",

    [Parameter()]
    [switch] $SkipRegistry,

    [Parameter()]
    [switch] $SkipFiles,

    [Parameter()]
    [switch] $SkipShortcuts,

    [Parameter()]
    [switch] $KeepOldFiles,

    [Parameter()]
    [switch] $AllRegistryKeys
)

$ErrorActionPreference = "STOP"

# Dot Source needed libs
. "$PSScriptRoot\libs\BdeUtils.ps1"


# Check prerequisites for running this program
if ($ENV:PROCESSOR_ARCHITECTURE -eq "x86" -and ![Environment]::Is64BitProcess)
{
    # This script was not tested in this configuration
    Write-Host "Error: Please open a 64bit Powershell session and try again." -ForegroundColor Red
    return
}

$OldSharedDir = Get-BorlandSharedDir
if ([string]::IsNullOrWhiteSpace($OldSharedDir))
{
    Write-Host "Error: Failed to locate the \Borland Shared\ folder definition in the registry." -ForegroundColor Red
    Exit 1
}

$DirPattern = $OldSharedDir.Replace("\","\\")
$ProcS = Get-CimInstance -ClassName Win32_Process -Filter "CommandLine like '%$DirPattern%' "
if ($ProcS)
{
    Write-Warning "Error: Please close these Borland applications before running this program."
    $ProcS | Format-Table -Property "ProcessId","Name"
    Exit 1
}

if (!$WhatIfPreference -and !([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::`
                            GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator))
{
    Write-Host "Error: This program must be launched from an Admistrator console." -ForegroundColor Red
    return
}



function Set-ShortcutTarget($LinkS, [string] $Parent, [string] $RegexDir, [string] $TargetPath)
{
    $WshShell = New-Object -comObject WScript.Shell
    foreach ($Link in $LinkS)
    {
        $Shortcut = $WshShell.CreateShortcut($Link)
        if ($Shortcut.TargetPath -match $RegexDir)
        {
            $NewTargetPath = $Shortcut.TargetPath -Replace $RegexDir, $TargetPath
            if ($NewTargetPath -ne $Shortcut.TargetPath)
            {
                if ($WhatIfPreference)
                {
                    Write-Host "What if: $Parent\$($Link.Name) -> $NewTargetPath"
                }
                else 
                {                
                    Write-Host "$Parent\$($Link.Name) -> $NewTargetPath"
                    $NewWorkingDirectory = $Shortcut.WorkingDirectory -Replace $RegexDir, $TargetPath
                    $Shortcut.TargetPath = $NewTargetPath
                    $Shortcut.WorkingDirectory = $NewWorkingDirectory
                    $Shortcut.Save()
                }    
            }
        }
    }
}

function Set-BorlandShortcutTarget
{
    [CmdletBinding(SupportsShouldProcess)]
    param(
      [Parameter()]
      [string] $RegexDir,
  
      [Parameter()]
      [string] $TargetPath     
    )
  
    $LinkS = Get-ChildItem -Path "$Home\Desktop" -Include *.lnk -Recurse
    Set-ShortcutTarget -linkS $LinkS -Parent "Desktop" @PSBoundParameters

    $LinkS = Get-ChildItem -Path "$ENV:ProgramData\Microsoft\Windows\Start Menu\Programs" -Include *.lnk -Recurse
    Set-ShortcutTarget -linkS  $LinkS -Parent "Start Menu" @PSBoundParameters
}



#----------- Continue App ----------------
Write-Host "Initial BDE settings:" -NoNewline -ForegroundColor Cyan
Get-BdeInfo | Format-List

if (!($NewSharedDir.EndsWith("\")))
{
    $NewSharedDir += "\"
}

# Copy all files and subfolder under \Borland Shared\ to the new location
# Later we will delete the source (=old) folder.
$NeedToSetBdeNetDir = $false
if ($SkipFiles)
{
    Write-Host "Skipped copying Borland Shared\folders:-> $NewSharedDir" -ForegroundColor Cyan
}
else
{
    # Copy \Borland Shared\ folder to $NewSharedDir
    if ($NewSharedDir.ToLower().Contains($OldSharedDir.ToLower()) )
    {
        Write-Host "Skipped copying files (Source = Destination): $OldSharedDir" -ForegroundColor Cyan
        $SkipFiles = $true
    }
    else
    {
        Write-Host "Copying Borland Shared\folders:-> $NewSharedDir" -ForegroundColor Cyan
        $ShareItemS = Get-ChildItem -Path $OldSharedDir
        New-Item -ItemType Directory -Path $NewSharedDir -ErrorAction SilentlyContinue | Out-Null
        foreach($ShareItem in $ShareItemS)
        {
            if (!$WhatIfPreference)
            {
                Write-Host "`t$($ShareItem.FullName)  ->  $NewSharedDir$($ShareItem.Name)"
            }
            Copy-Item -Path $ShareItem.FullName -Destination $NewSharedDir -Recurse -Force
        }

        $BdeNetDir = Get-BdeNetDir
        if ([string]::IsNullOrWhiteSpace($BdeNetDir))
        {
            $NeedToSetBdeNetDir = $true
        }
        else
        {
            # Don't modify BdeNetDir unless its on the local c:\ drive
            if ($BdeNetDir.ToLower().StartsWith("c:"))
            {
                if (Test-Path -Path "$BdeNetDir\PDOXUSRS.NET")
                {
                    Write-Host "Deleting old 'BDE network lockfile': $BdeNetDir\PDOXUSRS.NET" -ForegroundColor Cyan
                    Remove-Item -Path "$BdeNetDir\PDOXUSRS.NET" -Force -ErrorAction SilentlyContinue    
                }
                $NeedToSetBdeNetDir = $true
            }
        }    
        if ($NeedToSetBdeNetDir)
        {
            Write-Host "Setting new 'BDE network lockfile dir':-> $NewSharedDir`BDE" -ForegroundColor Cyan
            Set-BdeNetDir -NetDir "$NewSharedDir`BDE" -IdapiFile "$NewSharedDir`BDE\IDAPI32.CFG"
        }
    }    
}


# Change Shortcuts to point to $NewSharedDir 
if (!$SkipShortcuts)
{
    Write-Host "`nChanging the target directory of Borland Shortcuts:" -ForegroundColor Cyan
    $RegexDir = $OldSharedDir -Replace "\\", "\\" -replace "\(", "\(" -replace "\)", "\)"
    Set-BorlandShortcutTarget -RegexDir $RegexDir -TargetPath $NewSharedDir
}


# Change registry values to point to $NewSharedDir 
if ($SkipRegistry)
{
    Write-Host "`nSkipped registry changes for \Borland Shared\ folder:-> $NewSharedDir" -ForegroundColor Cyan
}
else
{
    # Check if we need to actually make any changes
    if ($OldSharedDir -eq $NewSharedDir)
    {
        Write-Host "`nSkipped registry changes for \Borland Shared\ folder (Source = Destination): $OldSharedDir" -ForegroundColor Cyan
    }
    else 
    {
        Write-Host "`nMaking registry changes for \Borland Shared\ folder:-> $NewSharedDir" -ForegroundColor Cyan
        Move-RegBorlandSharedDir -Path $NewSharedDir -AllRegistryKeys:$AllRegistryKeys
    }
}


# Finally remove the old share folder
if (!$SkipFiles)
{
    if (!$KeepOldFiles)
    {
        Write-Host "`nDeleting old Borland Share folder: $OldSharedDir" -ForegroundColor Cyan
        Remove-Item -Path $OldSharedDir -Recurse -Force -Confirm:$false
    }
}


Write-Host "`nInitial BDE settings:" -NoNewline -ForegroundColor Cyan
Get-BdeInfo | Format-List
