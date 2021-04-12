<#
.Synopsis
This script installs or updates the Borland Database Engine (=BDE)
to the last published (2001) version 5.2.0.2. The BDE was designed to 
run on windows XP, but subsequent windows versions added security 
restrictions that are incompatible with the default BDE installation 
procedures.

Windows Vista+ does not allow a standard user account to write to the 
C:\ or C:\Progam Files\ folders. But the DBE and other older Borland 
tools assume write access to their installation folders, e.g. the 
IDAPI32.CFG configuration file, and the global BDE lock file in
C:\PDOXUSRS.NET.

To avoid these issues we install the BDE binaries and IDAPI32.CFG 
to C:\Borland\Shared\BDE\ folder. We also configure the global 
BDE lock file PDOXUSRS.NET to reside in the same folder instead of
in the default root dir.

The BdeAdmin.exe tool needs elevated administrator access to its
Registry settings. So we create a desktop shortcut link to run the
BdeAdmin.exe application as administrator.

You must invoke this installation script from an administrator console.

================================
BDE Redistributable Files:
================================
  Core BDE Files
  --------------
  IDASCI32.DLL   For accessing ASCII files
  IDBAT32.DLL    For batch movement of data
  IDDA3532.DLL   For accessing Microsoft Access databases
  IDDAO32.DLL    For accessing Microsoft Access databases
  IDDBAS32.DLL   For accessing dBASE databases
  IDDR32.DLL     For Data Repository (Paradox only)
  IDODBC32.DLL   For BDE access to ODBC drivers
  IDPDX32.DLL    For accessing Paradox databases
  IDQBE32.DLL    QBE query engine
  IDR20009.DLL   BDE resources
  IDAPI32.DLL    Main BDE system DLL
  IDSQL32.DLL    SQL query engine (including local SQL)

  Language Driver Files
  ---------------------
  BANTAM.DLL     Internationalization engine
  *.CVB          Character set conversion files
  *.BTL          Locales
  BLW32.DLL      Expression engine

  Files for Microsoft Transaction Server (MTS)
  --------------------------------------------
  DISP.DLL       MTS dispensor DLL
  DISP.PAK

  Auxiliary Tools/Utilities
  -------------------------
  BDEADMIN.*     BDE Administrator utility
  DATAPUMP.*     Data Pump data migration tool

================================
SQL Links Redistributable Files:
================================
  Interbase
  -------------------------------------------------------
  SQLINT32.DLL    InterBase SQL Links driver
  SQL_INT.CNF     Default BDE configuration file for INT 
                  SQL Links

  For other files associated with InterBase deployment,
  consult the InterBase documentation.

  Oracle
  -------------------------------------------------------
  SQLORA32.DLL    Oracle 7 SQL Links driver
  SQL_ORA.CNF     Default BDE configuration file for ORA
                  SQL Links (Oracle 7)
  SQLORA8.DLL     Oracle 8 SQL Links driver
  SQL_ORA8.CNF    Default BDE configuration file for ORA8
                  SQL Links (Oracle 8)

  Sybase Db-Lib
  -------------------------------------------------------
  SQLSYB32.DLL    Sybase Db-Lib SQL Links driver
  SQL_SYB.CNF     Default BDE configuration file for SYB
                  Db-Lib SQL Links

  Sybase Ct-Lib
  -------------------------------------------------------
  SQLSSC32.DLL    Sybase Ct-Lib SQL Links driver
  SQL_SSC.CNF     Default BDE configuration file for SYB
                  Ct-Lib SQL Links

  Microsoft SQL Server
  -------------------------------------------------------
  SQLMSS32.DLL    Microsoft SQL Server SQL Links driver
  SQL_MSS.CNF     Default BDE configuration file for MSS
                  SQL Links

  Informix
  -------------------------------------------------------
  SQLINF32.DLL    Informix 7 SQL Links driver
  SQL_INF.CNF     Default BDE configuration file for INF
                  SQL Links (Informix 7)
  SQLINF9.DLL     Informix 9 SQL Links driver
  SQL_INF9.CNF    Default BDE configuration file for INF
                  SQL Links (Informix 9)

  DB/2
  -------------------------------------------------------
  SQLDB232.DLL    DB/2 version 2.x SQL Links driver
  SQL_DB2.CNF     Default BDE configuration file for DB/2
                  version 2.x SQL Links
  SQLDB2V5.DLL    DB/2 V5 (UDB) SQL Links driver
  SQL_DBV5.CNF    Default BDE configuration file for DB/2
                  V5 (UDB) SQL Links
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string] $BorlandSharedDir = "C:\Borland\Shared",

    [Parameter()]
    [switch] $Force
)

$ErrorActionPreference = "STOP"

# Include powrshell library with DBE functions
. "$PSScriptRoot\libs\BdeUtils.ps1"


if (!([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator))
{
  Write-Host "Error: This program must be launched from an Admistrator console." -ForegroundColor Red
  return
}

# Initialize $InstallBdeDir
$InstallBdeDir = "$BorlandSharedDir\BDE"
$OrgIdapiPath = $null
$BdePath = Get-BdePath
if (Test-Path -Path "$BdePath\IDAPI32.DLL")
{
  $Msg = "BDE is already installed at: $BdePath"
  if ($Force)
  {
    Write-Warning $Msg
    $OrgIdapiPath = Get-BdeIdapiPath
    if ($OrgIdapiPath -and !(Test-Path -Path $OrgIdapiPath))
    {
      $OrgIdapiPath = $null
    }  
  }
  else
  {
    Write-Host "Error: $Msg" -ForegroundColor Red
    Get-BdeInfo | Format-List
    Write-Host "Specify the -Force command line option to force a reinstallation." -ForegroundColor Red
    Exit 1
  }
}

# Kill orphaned Regsvr32 instances started by a prior invokation
$ProcS= Get-Process -Name "Regsvr32" -ErrorAction SilentlyContinue
if ($ProcS)
{
  Write-Host "Error: A BDE registration instance is still running. Killing process." -ForegroundColor Red
  $ProcS | Format-Table
  $ProcS.Kill()
  exit 1
}

# Create the install dir to avoid extra prompts from BdeInst.dll  
if (!(Test-Path -Path $InstallBdeDir))
{
  $null = New-Item -ItemType Directory -Path $InstallBdeDir -ErrorAction SilentlyContinue
}
# Create the target folder and Copy V5.2.0.2 files into it
Write-Host "Copying BDE files to $InstallBdeDir`."
Expand-Archive -Path "$PSScriptRoot\libs\BDE_5202.zip" -DestinationPath (Split-Path -Path $InstallBdeDir -Parent) -Force

# Initialize the DLLPATH in the registry, BdeInst.dll will use this as the default install directory
if (!(Test-Path -Path $HKLM_Borland))
{
  $null = New-Item -Path $HKLM_Borland
}
if (!(Test-Path -Path $HKLM_Bde))
{
  $null = New-Item -Path $HKLM_Bde 
}
$null = Set-ItemProperty -Path $HKLM_Bde -Name "DLLPATH" -Value $InstallBdeDir -ErrorAction Stop

<# Install the BDE
 The Borland\Delphi7\Install\Common\Borland Shared\BDE\bdeinst.cab contains a bdeinst.dll insaller 
 for BDE V5.1.1.1. It extracts its files into the BDE folder and initializes the registry settings.
 SHA-256(bdeinst.dll)= C3A55498C8F2B0C685C6279E18B016576A60FD2A1B985E0063CEC8BF7727E976
 SHA-256(bdeinst.cab)= 77B18C13B8E460668FCA5FF37561E223C86DA46FE2F1B2AB52D67A581E1A9A9D
 The Delphi7 installer overlays DBE V5.2.0.2 on top of the version 5.1.1.1 files.
#>
Write-Host "Configuring BDE registry settings."
$Proc = Start-Process -FilePath "regsvr32.exe" -ArgumentList "/s, $PSScriptRoot\libs\BdeInst.dll" -PassThru

# Send keystrokes to the active window, i.e. the regsvr32.exe process, to accept the default path
$WShell = New-Object -ComObject wscript.shell;
Start-Sleep -Milliseconds 1500 # wait for process window to activate
$WShell.SendKeys("{ENTER}")
Start-Sleep -Milliseconds 1000 # wait for 2nd popup (for some OS's only)
$WShell.SendKeys("{ENTER}")
if (!$Proc.WaitForExit(20000))
{
  Write-Host "Error: BDE registration timed out. ExitCode= $($Proc.ExitCode)" -ForegroundColor Red
  Exit 1
}

# Copy V5.2.0.2 over the V5.1.1.1 files, if the user changed the default install folder
$BdePath = Get-BdePath
if ($InstallBdeDir -ne $BdePath)
{
  Copy-Item -Path "$InstallBdeDir\*" -Destination $BdePath -Force -Exclude "*.cfg"
  Remove-Item $InstallBdeDir -Force -Recurse
}

# Register disp.dll
regsvr32.exe "$BdePath\disp.dll"
Start-Sleep -Milliseconds 1500 # wait for confirmation window to activate
$WShell.SendKeys("{ENTER}")

# Attempt to preserve previous BDE settings stored in the idapi32.cfg file
$IdapiPath = "$BdePath\idapi32.cfg"
if ($OrgIdapiPath -and $OrgIdapiPath -ne $IdapiPath)
{
  Write-Warning "Preserving BDE aliases and settings from: $OrgIdapiPath"
  Copy-Item -Path $OrgIdapiPath -Destination $IdapiPath -Force
  $null = Set-ItemProperty -Path $HKLM_Bde -Name "CONFIGFILE01" -Value $IdapiPath -ErrorAction Stop
  $BdeNetDir = Get-BdeNetDir
  if (Test-Path -Path "$BdeNetDir\PDOXUSRS.NET")
  {
    Write-Warning "Deleting old BDE network lock file: $BdeNetDir\PDOXUSRS.NET"
    Remove-Item -Path "$BdeNetDir\PDOXUSRS.NET" -Force -ErrorAction SilentlyContinue
  }
}

# Modify the LOCAL SHARE setting
#$null = Set-ItemProperty -Path "$HKLM_Bde\Settings\SYSTEM\INIT" -Name "LOCAL SHARE" -Value "TRUE" -ErrorAction Stop

# Modify the Paradox NetDir folder where the global PDOXUSRS.NET.net is located
Write-Host "Configuring NetLockFile: $BdePath"
Set-BdeNetDir -NetDir $BdePath

# Create a Shortcut to BdeAdmin tool on the desktop
Write-Host "Creating Desktop shortcut for BdeAdmin."
New-DesktopShortcut  -Name "BdeAdmin" -TargetPath "$BdePath\BDEADMIN.EXE" -RunAsAdmin

Write-Host "`nBDE settings:" -NoNewline -ForegroundColor Cyan
Get-BdeInfo | Format-List
