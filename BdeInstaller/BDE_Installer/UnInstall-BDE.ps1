<#
.SYNOPSIS
  Delete BDE Files, Folders & Registry entries
#>
[CmdletBinding(SupportsShouldProcess)]
param()

$ErrorActionPreference = "STOP"

# Include powrshell library with DBE functions
. "$PSScriptRoot\libs\BdeUtils.ps1"


# Check prerequisites for running this program
if (!$WhatIfPreference -and ![Environment]::Is64BitProcess)
{
    # We use hard-coded registry values that are only valid for a 64bit OS
    Write-Host "Error: This program does not work on 32bit systems." -ForegroundColor Red
    return
}
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

Write-Host "BDE settings:" -NoNewline -ForegroundColor Cyan
Get-BdeInfo | Format-List
Write-Warning "Deleting all BDE files and Registry settings."
$reply = Read-Host -Prompt "Continue? [y/n]"
if ($reply -notmatch "[yY]") 
{ 
    return
}
Remove-Bde

Write-Host "`nBDE settings:" -NoNewline -ForegroundColor Cyan
Get-BdeInfo | Format-List
