
<#
.SYNOPSIS
Recursively removes all hard lined files in (and under) the specified Path.
This function removes the hard linked tree structure created by Copy-FilesAsHardlinks()
It only removes the files. The directories are left untouched.

.PARAMETER Path
A path to the folder containing the files to delete.

.PARAMETER AllFiles
Optional switch which will remove all files even if they are not hard linked

.PARAMETER TargetDir
Only needed for Powhershell 4.0 or Core because they still do not populate the Target property !@#$
Optional path to a target folder that has the same sub directory tree structure as Path
and to which the files in Path are hard linked.
It helps speed up the removal process by not running fsutil.exe against each file.

.PARAMETER FindTargetDir
Only needed for Powhershell 4.0 or Core because they still do not populate the Target property !@#$
Optional switch to optimize the removal process by automatically finding the TargetDir.
Specify this switch if you know that the hard linked files have the same tree structure
but you don't know the TargetDir path.
#>
function Remove-Hardlinks
{
    [CmdletBinding(DefaultParameterSetName = "ByTargetDir")]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        $Path,

        [Parameter(ParameterSetName = "ByTargetDir")]
        $TargetDir = $null,

        [Parameter(ParameterSetName = "FindTargetDir")]
        [switch]$FindTargetDir,

        [Parameter()]
        [switch]$AllFiles
    )

    if (!(Test-Path -Path $Path))
    {
        return
    }
    if ($TargetDir)
    {
        $TargetDir = (Resolve-Path -Path $TargetDir).Path
    }

    $RPath = (Resolve-Path -Path $Path).Path.TrimEnd([System.IO.Path]::DirectorySeparatorChar)
    $RDrive = Split-Path -Path $RPath -Qualifier # FsUtil does not include the drive in the returned links
    [int]$RPathLen = $RPath.Length
    
    [array]$FileS = Get-ChildItem -Path $RPath -Recurse -File
    foreach ($File in $FileS)
    {
        if ($File.LinkType -eq "HardLink")
        {
            if ($File.Target)
            {
                $File.MoveTo($File.Target[0]) # 2x faster than Move-Item()
                #Move-Item -Path $File.FullName -Destination $File.Target[0]
            }
            else
            {
                # Powhershell 4.0 or Core because they still do not populate the Target property !@#$
                # See nice PS Workaround using FindFirstFileNameW(), FindNextFileNameW() win32 API's:
                # https://github.com/PowerShell/PowerShell/issues/15139
                if (!$TargetDir)
                {
                    $FullName = $File.FullName
                    [array]$LinkS = & fsutil.exe hardlink list $FullName
                    if (!$FindTargetDir -or $LinkS.Count -gt 2)
                    {
                        # We can't decide which one is the TargetDir
                        Move-Item -Path $FullName -Destination "$RDrive$($LinkS[0])"
                        continue
                    }
                    $RFile = $FullName.Substring($RPathLen)
                    if ("$RDrive$($LinkS[0])" -eq $FullName)
                    {
                        $TargetDir = "$RDrive$($LinkS[1].Substring(0, $LinkS[1].Length- $RFile.Length))"
                    }
                    else 
                    {
                        $TargetDir = "$RDrive$($LinkS[0].Substring(0, $LinkS[0].Length- $RFile.Length))"
                    }                    
                }
                $RFile = $File.FullName.Substring($RPathLen)
                $File.MoveTo("$TargetDir$RFile")
                #Move-Item -Path $File.FullName -Destination "$TargetDir$RFile"
            }
        }
        elseif ($AllFiles)
        {
            Remove-Item -Path -$File.FullName    
        }
    }
}
