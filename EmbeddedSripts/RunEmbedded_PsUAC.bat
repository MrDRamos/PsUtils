@(echo off% <#%) &color 07 &title Powershell code embeded within a batch file
SETLOCAL ENABLEDELAYEDEXPANSION

::# Invoke with elevated UAC
rem First we add a registry key to associate *.Admin files with a cmd shell that runs with elevated privileges
rem Next the fltmc command with no arguments just outputs text, but requires elevated privileges to terminate with error code 0.
rem The || operator executes the following command if the previous command's ERRORLEVEL is NOT 0 (=not running elevated)
rem We create an empty runas.Admin file in the users temp folder and proceed to invoke this file. This spawns the runas command 
rem associated with the .Admin file in a new elevated process (after which the the script just exits). But the new elevated process 
rem starts a 2nd instance of the script including the original arguments (have to escape quotes with extra quotes). 
rem The 2nd instance detects its new special environment and proceeds to execute the remaining script body.
>nul reg add hkcu\software\classes\.Admin\shell\runas\command /f /ve /d "cmd /x /d /r set \"f0=%%2\"& call \"%%2\" %%3"& set _= %*
>nul fltmc || if "%f0%" neq "%~f0" (cd.>"%temp%\runas.Admin" & start "%~n0" /normal "%temp%\runas.Admin" "%~f0" "%_:"=""%" & exit /b)

set "0=%~f0" &set "1=%*"& pwsh.exe -nop -c iex ([io.file]::ReadAllText($env:0)) &pause &exit/b ||#>)[1]
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
