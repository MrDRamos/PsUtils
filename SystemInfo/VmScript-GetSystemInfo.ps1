<#
.SYNOPSIS
Records various VM system settings such as: Runtime-Paramers, Disk-space, WinRm-Settings, Install Hotfixes ...
#>
[CmdletBinding()]
param ()


#Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$VmScriptVersion = "0.0.0-Dev"
$VmScriptDescr = "SystemInfo"
$VmScriptFile = "VmScript-GetSystemInfo.ps1"

$__INCLUDE_FILES__ = @()
Write-Output "Running: $VmScriptDescr, Script: $VmScriptFile, Ver: $VmScriptVersion, Pid: $PID, Host: $ENV:COMPUTERNAME"


Write-Output "=========== Runtime ==========="
"Date     : $((Get-Date).ToString("F"))"
"Timezone : $((Get-CimInstance Win32_TimeZone).Caption)"
"BootTime : $((Get-CimInstance Win32_OperatingSystem).LastBootUpTime.ToString("F"))"
Try
{
    "HostName : $(([System.Net.Dns]::GetHostByName($env:computerName)).HostName)"
    $OS = Get-CimInstance Win32_OperatingSystem
    "OS       : $($OS.Caption) $($OS.Version)"
}
catch {}

Write-Output "`n=========== Azure VM Managed Identity ==========="
try
{
    $VmInstanceData = Invoke-RestMethod -Headers @{ "Metadata" = "true" } -Method Get -ErrorAction Ignore -Uri "http://169.254.169.254/metadata/instance/compute?api-version=2020-12-01"
    if ($VmInstanceData)
    {
        "SubscriptionId      $($VmInstanceData.subscriptionId)"
        "ResourceGroupName   $($VmInstanceData.resourceGroupName)"
        "Location            $($VmInstanceData.location)"
        "VmSKU               $($VmInstanceData.sku)"
        "VmSize              $($VmInstanceData.vmSize)"
        "`nOS-Profile:"
        ($VmInstanceData.osProfile | Format-List | Out-String).Trim()
        "`nAzure VM-Tags"
        ($VmInstanceData.TagsList | Out-String).Trim()
    }
    else 
    {
        "NA"
    }
}
catch 
{
    "NA"
}

Write-Output "`n=========== Environment Variables ==========="
(Get-ChildItem ENV: | Out-String).Trim()

Write-Output "`n=========== Path ==========="
($ENV:Path -split ';' | Out-String).Trim()

Write-Output "`n=========== PsModulePath ==========="
($ENV:PSModulePath -split ';' | Out-String).Trim()

Write-Output "`n=========== Powershell Version ==========="
($PSVersionTable | Out-String).Trim()

Write-Output "`n=========== Powershell Modules ==========="
$AllModules = Get-Module -ListAvailable | Where-Object { $_.Name -NotMatch "^Az" -or $_.Name -eq "AzureRm" }
$AzModule = Get-InstalledModule -Name 'Az' -AllVersions -ErrorAction SilentlyContinue
if ($AzModule)
{
    Add-Member -InputObject $AzModule -NotePropertyName "ModuleBase" -NotePropertyValue $AzModule.InstalledLocation
    $AllModules += $AzModule
}
$OsModules = $AllModules | Where-Object { $_.ModuleBase -match "C:\\WINDOWS\\system32\\WindowsPowerShell\\v1.0\\Modules" }
$AppModules = $AllModules | Where-Object { $OsModules -notcontains $_ }
($AppModules | Select-Object Name, Version, ModuleBase | Sort-Object Name | Format-Table | Out-String).Trim()
if ($VerbosePreference)
{
    ($OsModules | Select-Object Name, Version, ModuleBase | Sort-Object Name | Format-Table | Out-String).TrimEnd()
}

if (Get-Command Get-CimInstance)
{
    $SericeS = Get-CimInstance -ClassName CIM_Service -Filter "name like '%openlink%'"
    if ($SericeS)
    {
        Write-Output "`n=========== OpenLink Services ==========="
        ($SericeS | Format-Table Name, StartMode, State, ProcessId, Status, ExitCode, PathName | Out-String -Width 1000).Trim()
    }

    Write-Output "`n=========== Windows Update Service ==========="
    (Get-CimInstance win32_service -Filter "name = 'wuauserv'" | Format-List | Out-String).Trim()
    $WUA = New-Object -com "Microsoft.Update.AutoUpdate"
    if ($WUA)
    {
        ($WUA.Results | Format-List | Out-String).Trim()
    }
}

Write-Output "`n=========== WinRm Confg ==========="
if (Get-Command WinRm)
{
    winrm get winrm/config 

    Write-Output "`n=========== WinRm Listener ==========="
    winrm enumerate winrm/config/listener

    Write-Output "`n=========== WinRm CredSSP ==========="
    try
    {
        Get-WSManCredSSP
    }
    catch 
    {
        "NA"
    }

    Write-Output "`n=========== WinRm Firewall ==========="
    (Get-NetFirewallRule -Name WINRM*, WMI* | Format-Table Name, DisplayGroup, Enabled, Profile, Direction, Action | Out-String).Trim()
}
else 
{
    "NA"    
}

Write-Output "`n=========== WinHttp Proxy ==========="
(netsh winhttp show proxy | Out-String).TrimEnd()

Write-Output "`n=========== IpConfig ==========="
& ipconfig /all

Write-Output "`n=========== Drives ==========="
(Get-PSDrive -PSProvider FileSystem | Out-String).Trim()

Write-Output "`n=========== SystemInfo ==========="
SystemInfo
