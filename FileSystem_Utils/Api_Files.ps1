<#
.SYNOPSIS
Scans the $Path folder, retuning a list of directories matching the various optional criteria.
The default simply return all the sub-directories of $Path folder.

.PARAMETER Path
The root parent folder to process. The default is the current directory

.PARAMETER IncludeDir
Limits the included sub-directories names to only those matching this pattern
The default (if null or '') is to include all recursed sub directories

.PARAMETER ExcludeDir
One or more sub directories names to exclude.
The default (if null or '') is to include all recursed sub directories

.PARAMETER MinDepth
Set to 1 to exclude files in the parent $Path folder.
Default=0 =Include the root $Path

.PARAMETER MaxDepth
Set this parameter to a value greater that 0 to recursively include files in sub directories.
The default value is 0 meaning only files in the parent $Path folder are included.
#>
function Select-Directory
{
    [CmdletBinding()]
    [OutputType([System.IO.DirectoryInfo])]
    param (
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [object] $Path = $PWD,

        [Parameter()]
        [string[]] $IncludeDir = $null,
        
        [Parameter()]
        [string[]] $ExcludeDir = $null,

        [Parameter()]
        [int] $MinDepth = 0,    # Default=0 =Include Root $Path, 1=Exclude Root $Path, ...

        [Parameter()]
        [int] $MaxDepth = 0     # Default=0 =Root $Path only, No Sub-Directories, 1=Include Sub-Directories contained by Root $Path, ...
    )


    # Clip the Depth arguments to valid ranges
    $MaxDepth = [math]::Max(0, $MaxDepth)
    $MinDepth = [math]::Max(0, $MinDepth)
    $MinDepth = [math]::Min($MinDepth, $MaxDepth)

    $RootDir = Get-Item -Path $Path
    if (!$RootDir)
    {
        return $null
    }
    $RootDirNameLen = $RootDir.FullName.Length
    [array]$SubDirS = @($RootDir)
    if ($MaxDepth -ge 1)
    {
        $SubDirS += Get-ChildItem -Path $Path -Directory -Depth ($MaxDepth-1) -Force -ErrorAction Ignore
    }

    if ($MinDepth -ge 1)
    {
        [array]$MinDirS = @($RootDir)
        if ($MinDepth -ge 2)
        {
            $MinDirS += Get-ChildItem -Path $Path -Directory -Depth ($MinDepth -2) -Force -ErrorAction Ignore
        }    
        $MinDirNameS = $MinDirS.FullName
        [array]$SubDirS = [array]$SubDirS | Where-Object { $MinDirNameS -NotContains $_.FullName }
    }

    if ($IncludeDir)
    {
        $IncludeDirRegx = ($IncludeDir -join '|').Replace('.', '\.').Replace('*', '.*')
        $SubDirS = $SubDirS | Where-Object { $_.FullName.SubString($RootDirNameLen) -match $IncludeDirRegx }
    }

    if ($ExcludeDir)
    {
        $ExcludeDirRegx = ($ExcludeDir -join '|').Replace('.', '\.').Replace('*', '.*')
        $SubDirS = $SubDirS | Where-Object { $_.FullName.SubString($RootDirNameLen) -notmatch $ExcludeDirRegx }
    } 

    return $SubDirS
}


<#
.SYNOPSIS
Scans the $Path folder, retuning a list of files matching the various optional criteria.
The default simply return all the files in the $Path folder.

.PARAMETER Path
The root parent folder to process. This parameter is mandatory.

.PARAMETER Include
One or more filename patterns specifying what FileS to consider.
The default (if null or '') is to include/delete all files

.PARAMETER Exclude
One or more filename patterns specifying FileS to exclude.
The default (if null or '') is to not exclude any files
Note: Exclusions are applied after the inclusions, which can affect the final output

.PARAMETER MinLastWriteTime
A DateRime filter used to ignore files older than this DataTime
Default= 0= This filter is not applied

.PARAMETER MaxLastWriteTime
A DateRime filter used to ignore files newer than this DataTime
Default= 0= This filter is not applied

.PARAMETER IncludeDir
Limits the included sub-directories names to only those matching this pattern
The default (if null or '') is to include all recursed sub directories

.PARAMETER ExcludeDir
One or more sub directories names to exclude.
The default (if null or '') is to include all recursed sub directories

.PARAMETER MinDepth
Set to 1 to exclude files in the parent $Path folder.
Default=0 =Include the root $Path

.PARAMETER MaxDepth
Set this parameter to a value greater that 0 to recursively include files in sub directories.
The default value is 0 meaning only files in the parent $Path folder are included.
#>
function Select-File
{
    [CmdletBinding()]
    [OutputType([System.IO.FileInfo])]
    param (
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [object] $Path = $PWD,

        [Parameter()]
        [string[]] $Include = $null,

        [Parameter()]
        [string[]] $Exclude = $null,

        [Parameter()]
        [datetime] $MinLastWriteTime = 0,

        [Parameter()]
        [datetime] $MaxLastWriteTime = 0,

        [Parameter()]
        [string[]] $IncludeDir = $null,
        
        [Parameter()]
        [string[]] $ExcludeDir = $null,

        [Parameter()]
        [int] $MinDepth = 0,    # Default=0 =Include Root $Path, 1=Exclude Root $Path, ...

        [Parameter()]
        [int] $MaxDepth = 0     # Default=0 =Root $Path only, No Sub-Directories, 1=Include Sub-Directories contained by Root $Path, ...
    )

    [array]$FileS = $null
    $DirS = Select-Directory -Path $Path -MinDepth $MinDepth -MaxDepth $MaxDepth -IncludeDir $IncludeDir -ExcludeDir $ExcludeDir
    $DirSpecS = $DirS | ForEach-Object { "$($_.FullName)\*" }
    if ($DirSpecS)
    {
        [array]$FileS = Get-ChildItem -Path $DirSpecS -File -Include $Include -Exclude $Exclude -Force -ErrorAction Ignore

        if ($MinLastWriteTime.Ticks)
        {
            [array]$FileS = $FileS | Where-Object { $_.LastWriteTime -ge $MinLastWriteTime }
        }
    
        if ($MaxLastWriteTime.Ticks)
        {
            [array]$FileS = $FileS | Where-Object { $_.LastWriteTime -le $MaxLastWriteTime }
        }    
    }

    return $FileS
}
