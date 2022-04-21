<#
.SYNOPSIS
Returns a list of fully qualified file names that are linked to this file.
This function is only needed when running with Powhershell 4.0 or Core
because they do not populate the File.Target property with the hard linked
files as all the powershell 5 versions do.
#>
function Get-HardLinkTarget
{
    param (
        [Parameter(ValueFromPipeline)]
        [System.IO.FileInfo] $File
    )

    if ($File -and $File.LinkType -eq 'HardLink')
    {
        if ($File.Target)
        {
            return $File.Target
        }

        $FullName = $File.FullName
        $Drive = $FullName.Substring(0, 2) 

        # See Faster PS Workaround using FindFirstFileNameW(), FindNextFileNameW() win32 API's:
        # https://github.com/PowerShell/PowerShell/issues/15139
        [array]$AllLinkS = & fsutil.exe hardlink list $FullName
        foreach ($Link in $AllLinkS) 
        {
            if ([string]::Compare($FullName, 2, $Link, 0, $Link.Length, $true) -ne 0)
            {
                $Drive + $Link
            }
        }
    }
}


<#
.SYNOPSIS
Deletes the specified file(s) taking into account that hard linked files can be locked by some external process

.PARAMETER Path
Parameter description
#>
function Remove-HardLink
{
    [CmdletBinding()]
    param (
        [Parameter(ValueFromPipeline, Position =0)]
        [System.IO.FileInfo[]] $Path,

        # Only needed for Powhershell 4.0 or Core
        [Parameter()] 
        [System.IO.FileSystemInfo[]] $TargetDir = $null
    )

    if ($Input)
    {
        # $Input is an automatic variable that references the pipeline objects
        $Path = [System.IO.FileInfo[]]$Input
    }

    foreach ($File in $Path)
    {
        if ($File.LinkType -eq 'HardLink')
        {
            if ($File.Target)
            {
                $File.MoveTo($File.Target[0]) # 2x faster than Move-Item()
                #Move-Item -Path $File.FullName -Destination $File.Target[0]
            }
            else
            {
                # Powhershell 4.0 or Core do not populate the Target property !@#$
                # Get-HardLinkTarget() spawns the time comsuming fsutil.exe process for each file.
                # We try to optimize if $TargetDir was specified, by assuming that all the files to be removed
                # are hard linked to files that reside in the $TargetDir folder, and have the same filename.
                if (!$TargetDir -or $TargetDir.FullName -eq $File.DirectoryName)
                {
                    [array]$LinkS = Get-HardLinkTarget -File $File
                    $File.MoveTo($LinkS[0])
                    continue
                }

                $TargetFile = $TargetDir.FullName + [System.IO.Path]::DirectorySeparatorChar + $File.Name
                if (!(Test-Path -Path $TargetFile))
                {
                    # The file names did not match
                    [array]$LinkS = Get-HardLinkTarget -File $File
                    $File.MoveTo($LinkS[0])
                    continue
                }
                $File.MoveTo($TargetFile)
            }
        }
        else 
        {
            $File.Delete()    
        }
    }
}

<#
###### Unit test Remove-HardLink ######
$TargetDir = Get-Item -Path 'C:\tmp'
"$TargetDir\testL.txt", "$TargetDir\more\testL.txt", "$TargetDir\test.txt" | Remove-Item -ErrorAction Ignore
"test" > "$TargetDir\test.txt"
$null = New-Item -ItemType HardLink -Path "$TargetDir\testL.txt" -Target "$TargetDir\test.txt"
$null = New-Item -Path C:\tmp\more -ErrorAction Ignore
$null = New-Item -ItemType HardLink -Path "$TargetDir\more\testL.txt" -Target "$TargetDir\test.txt"

Remove-Hardlink "$TargetDir\testL.txt", "$TargetDir\more\testL.txt", "$TargetDir\test.txt" -TargetDir $TargetDir
#"$TargetDir\testL.txt", "$TargetDir\more\testL.txt", "$TargetDir\test.txt" | Remove-Hardlink -TargetDir $TargetDir
Remove-Hardlink "$TargetDir\testL.txt", "$TargetDir\more\testL.txt", "$TargetDir\test.txt" -TargetDir $TargetDir
#>

<#
{
    # Powhershell 4.0 or Core because they still do not populate the Target property !@#$
    # Get-HardLinkTarget() spawns the time comsuming fsutil.exe process for each file
    # Most of the following code is trying to optimize by makeing this call only once
    # if the parameter TargetDir
    # There optimization make 2 assumtions: (Which are true when created by Copy-HardLink() )
    # 1) The hard linked file names are the same
    # 2) All the files 
    if (!$TargetDir)
    {
        [array]$LinkS = Get-HardLinkTarget -File $File
        if (!$FindTargetDir -or $LinkS.Count -gt 2)
        {
            # We can't decide which one is the TargetDir
            $File.MoveTo($LinkS[0])
            continue
        }

        $TargetDirName = Split-Path -Path $LinkS[0] -Parent
        if ($TargetDirName -eq $File.DirectoryName)
        {
            # The hard linked target name and file name must be the same
            # for the TargetDir optimization to be valid
            $File.MoveTo($LinkS[0])
            continue
        }
        $TargetDirLen = $File.DirectoryName.Length
    }
    if (!$TargetDirLen)
    {
        #Note: Assumes all the other target files are under the same target directory
        # And that the hard linked target name is the same as the file name.
        $TargetDirName = $TargetDir.FullName
        $TargetDirLen = $TargetDirName.Length
    }
    $TargetFile = $TargetDirName + $File.FullName.Substring($TargetDirLen)
    $File.MoveTo($TargetFile)
}
#>

<#
.SYNOPSIS
This function removes the hard linked tree structure created by Copy-FilesAsHardlinks()

.PARAMETER Path
A path to the folder containing the files to delete.

.PARAMETER Recurse
Recursively removes all hard lined files in (and under) the specified Path.

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
    [CmdletBinding(DefaultParameterSetName = 'ByTargetDir')]
    param (
        [Parameter(Mandatory, ValueFromPipeline, Position = 0)]
        [string] $Path,

        [Parameter()]
        [switch] $Recurse,

        # Only needed for Powhershell 4.0 or Core
        [Parameter(ParameterSetName = 'ByTargetDir')] 
        [string] $TargetDir = $null,

        # Only needed for Powhershell 4.0 or Core
        [Parameter(ParameterSetName = 'FindTargetDir')]
        [switch] $FindTargetDir
    )

    begin 
    {
        if ($TargetDir)
        {
            $TargetDir = (Resolve-Path -Path $TargetDir).Path
        }
    }

    process 
    {
        if (Test-Path -Path $Path)
        {
            $RPath = (Resolve-Path -Path $Path).Path.TrimEnd([System.IO.Path]::DirectorySeparatorChar)
            $RDrive = Split-Path -Path $RPath -Qualifier # FsUtil does not include the drive in the returned links
            [int]$RPathLen = $RPath.Length
    
            [array]$FileS = Get-ChildItem -Path $RPath -Recurse:$Recurse -File
            $NewMethod = $false
            $NewMethod = $true
            if ($NewMethod)
            {
                Remove-Hardlink -Path $FileS  
            }
            else 
            {
                foreach ($File in $FileS)
                {
                    if ($File.LinkType -eq 'HardLink')
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
                    } # HardLinks only
                    else
                    {
                        $File.Delete()
                    }
                }                 
            }
                        
            if ($Recurse -and (Test-Path -Path $RPath -PathType Container) )
            {
                Remove-Item -Path $RPath -Recurse
            }
        }
    }
}
