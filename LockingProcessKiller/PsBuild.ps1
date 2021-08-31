[CmdletBinding()]
Param 
(
    [Parameter()]
    [Alias('C')]
    [switch] $Clean,

    [Parameter()]
    [Alias('R')]
    [switch] $Rebuild
)


$ErrorActionPreference = "Stop"

$BuildDir = "$PSScriptRoot\build"
$ModuleName = "LockingProcessKiller"
$ModuleDir = "$BuildDir\$ModuleName"

$Psd1File = Get-ChildItem -Path "$PSScriptRoot\src\*psd1" -Recurse
$PsdData = Import-PowerShellDataFile -Path $Psd1File
$ModuleVer = $PsdData.ModuleVersion
$ModuleVerDir = "$ModuleDir\$ModuleVer"
Write-Host "Building $ModuleName   Version: $ModuleVer"

[bool]$Build = !$Clean
if ($Rebuild)
{
    $Clean = $true
    $Build = $true
}


if ($Clean)
{
    if (Test-Path -Path $BuildDir)
    {
        Remove-Item -Path $BuildDir -Recurse -Force
    }
}


if ($Build)
{
    if (Test-Path -Path $ModuleVerDir)
    {
        Remove-Item -Path $ModuleVerDir -Recurse -Force
    }
    $null = New-Item -ItemType Directory -Path $ModuleVerDir #-ErrorAction Ignore

    function DownloadHandleApp($Path)
    {
        $ZipFile = "Handle.zip"
        $ZipFilePath = "$Path\$ZipFile"
        $Uri = "https://download.sysinternals.com/files/$ZipFile"
        try 
        {
            Remove-Item -Path $Path -Recurse -Force -ErrorAction SilentlyContinue
            $null = New-Item -ItemType Directory -Path $Path -Force -ErrorAction Stop
            Invoke-RestMethod -Method Get -Uri $Uri -OutFile $ZipFilePath -ErrorAction Stop
            Expand-Archive -Path $ZipFilePath -DestinationPath $Path -Force -ErrorAction Stop
            Remove-Item -Path $ZipFilePath -ErrorAction SilentlyContinue
        }
        catch 
        {
            Remove-Item -Path $Path -Recurse -Force -ErrorAction SilentlyContinue
            Throw "Failed to download dependency: handle.exe from: $Uri"
        }
    }

    Copy-Item -Path "$PSScriptRoot\src\*" -Destination $ModuleVerDir -Recurse
    DownloadHandleApp -Path "$ModuleVerDir\handle"
    Compress-Archive -Path $ModuleDir -DestinationPath "$BuildDir\$ModuleName`.$ModuleVer`.zip" -ErrorAction Stop -Force
}
