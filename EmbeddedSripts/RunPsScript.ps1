Write-Host "Running $PSCommandPath"
Write-Host "PSScriptRoot: $PSScriptRoot"
$PsVersionTable
(Get-PsDrive | Format-Table | Out-String).Trim()
Read-Host "Press enter to continue"
