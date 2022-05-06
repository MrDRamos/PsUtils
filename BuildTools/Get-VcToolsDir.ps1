function Get-VcToolsDir
{
    # 2022
    [array]$VsEdition = Get-ChildItem -Path "${Env:ProgramFiles}\Microsoft Visual Studio\2022" -Directory -ErrorAction Ignore
    if ($VsEdition)
    {
        [array]$VCToolsInstallDir = Get-ChildItem -Path "$($VsEdition[0].FullName)\VC\Tools\MSVC" -Directory -ErrorAction Ignore
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
        [array]$VsEdition = Get-ChildItem -Path "${Env:ProgramFiles(x86)}\Microsoft Visual Studio\2019" -Directory -ErrorAction Ignore
        if ($VsEdition)
        {
            [array]$VCToolsInstallDir = Get-ChildItem -Path "$($VsEdition[0].FullName)\VC\Tools\MSVC" -Directory -ErrorAction Ignore
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
    $VcTool = Get-ChildItem -Path "$(Get-VcToolsDir)\$($FileName).exe" -ErrorAction Ignore
    if ($VcTool)
    {
        return $VcTool.FullName
    }

    throw "Can't find $FileName"
}



######### Main #########
Get-VcToolsDir
