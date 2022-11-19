
<#
API's to manage Visual Studio C++ runtimes installed on a computer
#>



<#
.SYNOPSIS
Note Visual C++ 2015, 2017, 2019 & 2022 all share the same redistributable files.
Installing the latest common redistributable will affect older programs built with Visual C++ 2015, 2017 or 2019. 
This is different from all previous Visual C++ versions, as they each had their own distinct runtime files, 
not shared with other versions. 
Ref: https://support.microsoft.com/en-us/topic/the-latest-supported-visual-c-downloads-2647da03-1eea-4433-9aff-95f26a218cc0

Alternate well known download links:
VS Downloads:   https://visualstudio.microsoft.com/downloads/
VS Subsciption: https://my.visualstudio.com/downloads
All runtimes:   https://www.techpowerup.com/download/visual-c-redistributable-runtime-package-all-in-one/

.PARAMETER Outfile
Optional argument to overide the default output filename & directory.
The default is under the current working directory.

.PARAMETER Passthru
Specify the Passthru switch to return the path to the downloaded installer file.
By default this function does not return anything.
#>
function Get-Vc2015_2022Runtime
{
    [CmdletBinding()]
    param (
        [Parameter()]
        [object] $Outfile = "vc_redist2015-2022_x64.exe",

        [Parameter()]
        [switch] $Passthru
    )

    $Uri = "https://download.visualstudio.microsoft.com/download/pr/89a3b9df-4a09-492e-8474-8f92c115c51d/B1A32C71A6B7D5978904FB223763263EA5A7EB23B2C44A0D60E90D234AD99178/VC_redist.x64.exe" # Sep 25 2020
    $Uri = "https://download.visualstudio.microsoft.com/download/pr/d22ecb93-6eab-4ce1-89f3-97a816c55f04/37ED59A66699C0E5A7EBEEF7352D7C1C2ED5EDE7212950A1B0A8EE289AF4A95B/VC_redist.x64.exe" # Jan  5 2022
    $Uri = "https://aka.ms/vs/17/release/vc_redist.x64.exe"  
    Write-Host "Downloading common VC 2015-2022 runtime to:`n$Outfile"
    Invoke-RestMethod -Method Get -Uri $Uri -OutFile $Outfile

    if ($Passthru)
    {
        return $Outfile | Resolve-Path
    }
}


<#
.SYNOPSIS
Downloads the C++ 2015 redistributable installer from Microsoft's well known web site.
Before using this installer consider the more general combined 2015..2019 installer.
2015 original: https://www.microsoft.com/en-us/download/details.aspx?id=48145
2015 Update-3: https://www.microsoft.com/en-us/download/details.aspx?id=53840

.PARAMETER Outfile
Optional argument to overide the default output filename & directory.
The default is under the current working directory.

.PARAMETER Passthru
Specify the Passthru switch to return the path to the downloaded installer file.
By default this function does not return anything.
#>
function Get-Vc2015Runtime
{
    [CmdletBinding()]
    param (
        [Parameter()]
        [object] $Outfile = "vc_redist2015_x64.exe",

        [Parameter()]
        [switch] $Passthru
    )

    $Uri = "https://download.microsoft.com/download/9/3/F/93FCF1E7-E6A4-478B-96E7-D4B285925B00/vc_redist.x64.exe" # Original Redistributable  Jul/10/2015
    $Uri = "https://download.microsoft.com/download/6/A/A/6AA4EDFF-645B-48C5-81CC-ED5963AEAD48/vc_redist.x64.exe" # Redistributable Update-3  Sep/15/2016
    Write-Host "Downloading VC 2015 runtime from Sep/15/2016 to:`n$Outfile"    
    Invoke-RestMethod -Method Get -Uri $Uri -OutFile $Outfile

    if ($Passthru)
    {
        return $Outfile | Resolve-Path
    }
}


<#
.SYNOPSIS
Downloads the installer from Microsoft's well known web site
2010 Original:        https://www.microsoft.com/en-us/download/confirmation.aspx?id=14632
2010 Service Pack 1:  https://www.microsoft.com/en-us/download/details.aspx?id=26999

.PARAMETER Path
Optional argument specifying the directory to store the installer to.
The default is under the current working directory\Vc2010Runtime

.PARAMETER Passthru
Specify the Passthru switch to return the path to the downloaded installer file.
By default this function does not return anything.
#>
function Get-Vc2010Runtime
{
    [CmdletBinding()]
    param (
        [Parameter()]
        [object] $Outfile = "vc_redist2010_x64.exe",

        [Parameter()]
        [switch] $Passthru
    )

    $Uri = "https://download.microsoft.com/download/3/2/2/3224B87F-CFA0-4E70-BDA3-3DE650EFEBA5/vcredist_x64.exe"
    $Uri = "https://download.microsoft.com/download/A/8/0/A80747C3-41BD-45DF-B505-E9710D2744E0/vcredist_x64.exe"  #SP1 May/12/2021
    Write-Host "Downloading VC 2010 runtime SP1 from May/12/2021 to:`n$Outfile"    
    Invoke-RestMethod -Method Get -Uri $Uri -OutFile $Outfile

    if ($Passthru)
    {
        return $Outfile | Resolve-Path
    }
}


function Install-Vc2010Runtime
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [object] $FilePath,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [object] $LogDir = $PWD,

        [Parameter()]
        [object] $TempDir = $null
    )

    $FilePath = Resolve-Path -Path $FilePath
    if (!$TempDir)
    {
        $TempDir = $FilePath -replace ".exe", "_setup"
    }
    & $FilePath /extract:$TempDir /q

    $LogFile = ($FilePath | Split-Path -Leaf) -replace "\.exe", ".log"
    $LogFilepath = "$LogDir\$LogFile"
    # run setup.exe /? for help
    Start-Process -FilePath "$TempDir\Setup.exe" -ArgumentList "/norestart", "/q", "/log", "$LogFilepath" -Wait -PassThru
}


function Install-Vc2015_2022Runtime
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [object] $FilePath,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [object] $LogDir = $PWD
    )

    $FilePath = Resolve-Path -Path $FilePath -ErrorAction Stop
    $LogFile = ($FilePath | Split-Path -Leaf) -replace "\.exe", ".log"
    $LogFilepath = "$LogDir\$LogFile"

    #operation: "/install","/repair","/uninstall","/layout"
    #verbosity: /quiet /passive
    & $FilePath /install /quiet /norestart /log "$LogFilepath"
}


<#
.SYNOPSIS
Returns VisualStudio C++ runtime uninstall information. This information is stored in the registry by the MSI installer.
One of the returned properties is: UninstallString like: MsiExec.exe /I{8A3F7D5B-422D-49D9-84F7-8DC1B7782967}

.PARAMETER VerRegex
A regular expression used to filter out which C++ runtime versions to return.
The default returns all runtime uninstaller objects

.Example
Get-VcRuntimeUninstaller 2010

.Example
Get-VcRuntimeUninstaller (2015|2019|2022)
#>
function Get-VcRuntimeUninstaller($VerRegex = $null)
{
    $RegKeyUninstall = "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*"
    $UninstableS = Get-ItemProperty $RegKeyUninstall | Where-Object { $_.PsObject.Properties.Name -match "DisplayName" }
    if ($VerRegex)
    {
        $Retval = $UninstableS | Where-Object { $_.DisplayName -match "C\+\+\s+$VerRegex" }
    }
    else 
    {
        $Retval = $UninstableS | Where-Object { $_.DisplayName -match "C\+\+\s+\d+\s+" }
    }
    return $Retval
}


<#
.SYNOPSIS
Returns a list of all VisualStudion C++ runtime names installed on this Computer
#>
function Get-VcRuntime($VerRegex = $null)
{
    $UninstableS = Get-VcRuntimeUninstaller -VerRegex $VerRegex
    if ($UninstableS)
    {
        $UninstableS.DisplayName
    }
}


<#
.SYNOPSIS
Returns the number of VisualStudion C++ runtimes installed on this Computer
#>
function Test-VcRuntime($VerRegex = $null)
{
    [array] $Found = Get-VcRuntimeUninstaller -VerRegex $VerRegex
    return $Found.Count
}

function Test-Vc2010Runtime
{
    Test-VcRuntime -VerRegex "2010"
}

function Test-Vc2015Runtime
{
    Test-VcRuntime -VerRegex "(2015|2019|2022)"
}

function Test-Vc2019Runtime
{
    Test-VcRuntime -VerRegex "2019"
}


function Show-VcRuntimeUninstall($VerRegex = $null)
{
    [array]$RuntimeS = Get-VcRuntimeUninstaller -VerRegex $VerRegex
    foreach ($Runtime in $RuntimeS) 
    {
        "Uninstall $($Runtime.DisplayName)" | Write-Host
        Write-Host $Runtime.UninstallString -ForegroundColor red
    }
}


#### main ####
Get-Vc2015_2022Runtime ".\vc_redist2015-2022_x64.exe"
#Get-Vc2010Runtime ".\vc_redist2010Sp1_x64.exe"
