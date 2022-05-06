<#
.SYNOPSIS
Inspects a DLL or EXE for the DLL's that it depends on.
Outputs an array of objects with the following properties:
{
    File    = The input file 
    Depends = A string[] array of the dependant DLL names
}

.EXAMPLE
Generate a list of DLL dependencies for each *.exe file in the current directory
.\DumpDepends -Path *.EXE

.EXAMPLE
Don't include typical C-Runtime DLL's or Windows DLL's
.\DumpDepends.ps1 -Path *.EXE,*.DLL -$FilterWin | Format-List

.EXAMPLE
Format results as an outline
$DepS = .\DumpDepends.ps1 -Path *.DLL
$DepS | ForEach-Object { $_.File ; $_.Depends | ForEach-Object { "`t$_" } }
#>
[CmdletBinding()]
param (
    [Parameter(Mandatory, ValueFromPipeline)]
    [object] $Path,

    [Parameter()]
    [switch] $FilterWin,

    [Parameter()]
    [string] $DumpBinTool = $null
)


function Get-VcToolsDir
{
    # 2022
    [array]$VsEdition = Get-ChildItem -Path "${Env:ProgramFiles}\Microsoft Visual Studio\2022" -Directory
    if ($VsEdition)
    {
        [array]$VCToolsInstallDir = Get-ChildItem -Path "$($VsEdition[0].FullName)\VC\Tools\MSVC" -Directory
        if ($VCToolsInstallDir)
        {
            return "$($VCToolsInstallDir[0].FullName)\bin\Hostx64\x64"
        }
    }

    # 2019
    if ($ENV:VCToolsInstallDir)
    {
        return "$Env:VCToolsInstallDir\bin\Hostx64\x64"
    }
    else
    {
        [array]$VsEdition = Get-ChildItem -Path "${Env:ProgramFiles(x86)}\Microsoft Visual Studio\2019" -Directory
        if ($VsEdition)
        {
            [array]$VCToolsInstallDir = Get-ChildItem -Path "$($VsEdition[0].FullName)\VC\Tools\MSVC" -Directory
            if ($VCToolsInstallDir)
            {
                return "$($VCToolsInstallDir[0].FullName)\bin\Hostx64\x64"
            }
        }
    }

    # 2015
    if ($ENV:VS140COMNTOOLS)
    {
        return "$ENV:VS140COMNTOOLS" -replace 'Common7\\Tools\\', 'VC\bin'
    }
    else
    {
        $VCToolsInstallDir = "${Env:ProgramFiles(x86)}\Microsoft Visual Studio 14.0\VC\bin"
        if (Test-Path -Path $VCToolsInstallDir)
        {
            return $VCToolsInstallDir
        }
    }

    # 2010
    $VCToolsInstallDir = "C:\Program Files (x86)\Microsoft Visual Studio 10.0\VC\bin\amd64"
    if (Test-Path -Path $VCToolsInstallDir)
    {
        return $VCToolsInstallDir
    }

    return $null
}


function Get-VcTool([string] $FileName)
{
    $VcTool = Get-Command $FileName -ErrorAction Ignore
    if ($VcTool)
    {
        return $VcTool.Source
    }

    $FileName = [System.IO.Path]::GetFileNameWithoutExtension($FileName)
    $VcTool = Get-ChildItem -Path "$(Get-VcToolsDir)\$($FileName).exe"
    if ($VcTool)
    {
        return $VcTool.FullName
    }

    throw "Can't find $FileName"
}


######## Main ########
if (!$DumpBinTool)
{
    $DumpBinTool = Get-VcTool -FileName "dumpbin"
}

$DllFilter = @("\*")
if ($FilterWin)
{
    $DllFilter = $('api-ms-win', 'VCRUNT', 'MSVC', 'MFC', 'KERNEL32', 'SHELL32', 'USER32', 'GDI32', 'COMDLG32', 'ODBC32'
        'MAPI32', 'ole32', 'OLEAUT32', 'WSOCK32', 'VERSION', 'ADVAPI32', 'MSWSOCK', 'WS2_32', 'RPCRT4', 'mscoree' )
}

if ($Input)
{
    $Path = $Input # an automatic variable that references the pipeline value
}

# Outpout simple dependency list
#(Get-ChildItem *.dll, *.exe) | ForEach-Object { "`n$($_.ToString()):"; & $DumpBinTool /NoLogo /Dependents $_ | Select-String -Pattern '^(?!Dump of)\s*(.*(\.dll|\.exe))$' | ForEach-Object { $_.Matches.Groups[1].value | Where-Object { $_ -notmatch ($DllFilter -join '|') } } }

# Return dependency objects
$Path = Resolve-Path -Path $Path
$DependS = $Path | ForEach-Object { [PSCustomObject]@{File = $_.ToString(); Depends = & $DumpBinTool /NoLogo /Dependents $_ | 
            Select-String -Pattern '^(?!Dump of)\s*(.*(\.dll|\.exe))$' | ForEach-Object { $_.Matches.Groups[1].value } |
            Where-Object { $_ -notmatch ($DllFilter -join '|^') } | Sort-Object } }
return $DependS
