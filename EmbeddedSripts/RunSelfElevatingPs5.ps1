if (!([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator))
{
  $CommandLine = "-File `"" + $MyInvocation.MyCommand.Path + "`" " + $MyInvocation.UnboundArguments
  Start-Process -Verb RunAs -FilePath powershell.exe -ArgumentList $CommandLine
  return
}

# PS-Main
Write-Host "Running $PSCommandPath"
Write-Host "PSScriptRoot: $PSScriptRoot"
$PsVersionTable | Format-Table
(Get-PsDrive | Format-Table | Out-String).Trim()
Read-Host "Press enter to continue"
