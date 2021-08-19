$BuildDir = "$PSScriptRoot\build"
$ModuleName = "LockingProcessKiller"
$ModuleDir = "$BuildDir\$ModuleName"

$Psd1File = Get-ChildItem -Path "$ModuleDir\*psd1" -Recurse
$PsdData = Import-PowerShellDataFile -Path $Psd1File
$ModuleVer = $PsdData.ModuleVersion
$ModuleVerDir = Split-Path -Path $Psd1File -Parent
Write-Host "Publishing to PsGallery: $ModuleName   Version: $ModuleVer"
$PkgDir = "$BuildDir\PsGallery\$ModuleName"


# Clean
if (Test-Path -Path $PkgDir)
{
    Remove-Item -Path $PkgDir -Recurse -Force -ErrorAction Stop
}

# Clone the build
Copy-Item -Path $ModuleVerDir -Destination $PkgDir -Recurse -Force -ErrorAction Stop

# We are not allowed to distribute SysInternals handle.exe
if (Test-Path -Path "$PkgDir\handle")
{
    Remove-Item -Path "$PkgDir\handle" -Recurse -Force -ErrorAction Stop
}


$PsGalleryKey = "oy2cesm" #Todo Get using 
Publish-Module -Path $PkgDir -NuGetApiKey $PsGalleryKey
