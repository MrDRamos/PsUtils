@(echo off% <#%) &color 07 &title Powershell code embeded within a batch file
SETLOCAL ENABLEDELAYEDEXPANSION &set "0=%~f0" &set "1=%*"& pwsh.exe -nop -c iex ([io.file]::ReadAllText($env:0)) &pause &exit/b ||#>)[1]
# Shared Batch/PowerShell code:
# The batch file sees % <#% as a variable who's content is empty. Powershell sees an array definition: @(echo off <#comment#>) with 1 item='off%'
# The batch has exited & it ignored everything following || 

# PS-Main
Write-Host "Running Powershell: $ENV:0"
Write-Host "Paramters: $ENV:1"
Write-Host "PSScriptRoot: $PSScriptRoot"
$PSScriptRoot = Split-Path -Path $ENV:0 -Parent
Write-Host "PSScriptRoot: $PSScriptRoot"
$PsVersionTable | Format-Table
(Get-PsDrive | Format-Table | Out-String).Trim()
