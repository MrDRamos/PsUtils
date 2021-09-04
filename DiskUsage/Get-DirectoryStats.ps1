
class DirStat
{
    <#
    [int64] $DiskSpace
    [int64] $TotDiskSpace
    [int64] $FileLength
    [int64] $TotFileLength
    [int]   $Files
    [int]   $TotFiles
    [int]   $Dirs
    [int]   $TotDirs
    #>
    [int64] $DiskSpace
    [int64] $FileLength
    [int]   $Files
    [int]   $Dirs
    [int64] $TotDiskSpace
    [int64] $TotFileLength
    [int]   $TotFiles
    [int]   $TotDirs
    [string] $Name
    [System.IO.DirectoryInfo] $Parent

    hidden [int] $BlockSize

    DirStat([System.IO.FileSystemInfo]$DirInfo)
    {
        $this.BlockSize = (Get-Volume -FilePath $DirInfo.FullName).AllocationUnitSize
        $this.InitDirInfo($DirInfo)
    }

    DirStat([System.IO.FileSystemInfo]$DirInfo, [int] $BlockSize)
    {
        $this.BlockSize = $BlockSize
        $this.InitDirInfo($DirInfo)
    }

    DirStat([string]$Parent, [string]$DirName, [int] $BlockSize)
    {
        $this.BlockSize = $BlockSize
        $this.Name = "{0}{1}{2}" -f $Parent, [System.IO.Path]::DirectorySeparatorChar, $DirName
        $this.Parent = $Parent
    }

    hidden [void] InitDirInfo([System.IO.FileSystemInfo]$DirInfo)
    {
        if ($DirInfo.PSIsContainer)
        {
            $this.Name = $DirInfo.FullName
            $this.Parent = $DirInfo.Parent
        }
        else 
        {
            $this.Name = $DirInfo.FullName
            $this.Parent = $DirInfo.Directory
        }

    }


    [void] AddDirStat([DirStat] $SubDirStat)
    {
        $this.TotDiskSpace += $SubDirStat.TotDiskSpace
        $this.TotFileLength += $SubDirStat.TotFileLength
        $this.TotFiles += $SubDirStat.TotFiles
        $this.Dirs++
        $this.TotDirs += 1+ $SubDirStat.TotDirs
    }


    [void] AddDirInfo([System.IO.FileSystemInfo] $DirItem)
    {
        if ($DirItem.PSIsContainer)
        {
            $this.Dirs++
        }
        else 
        {
            [int64] $ByteLen = $DirItem.Length
            [int64] $Space = 0           
            # The data of 'very small' files are stored together with the filename in the MFT, and use no additional storage blocks.
            # The data capacity of the MFT is OS dependent but not very well defined. 600 seems to be a good lower bound on Win10.
            # A file is rewritten (and locked in) to use storage blocks once the data added exceeds the MFT capacity.
            # TODO: Find API that tells us where the data is sored MFT or blocks. Or API that returns the actual space used.
            if (($ByteLen -gt 600) -or ($DirItem.LastWriteTime -ne $DirItem.CreationTime))
            {
                $Space = [int64](($ByteLen + $this.BlockSize - 1) / $this.BlockSize) * $this.BlockSize
            }
            $this.DiskSpace += $Space
            $this.FileLength += $ByteLen
            $this.Files++

            $this.TotDiskSpace += $Space
            $this.TotFileLength += $ByteLen
            $this.TotFiles++
        }
    }

}



function Find-DirNodeConnection([string]$FromPath, [string]$ToPath)
{
    [string[]]$FromDirS = $FromPath.Split([System.IO.Path]::DirectorySeparatorChar)
    [string[]]$ToDirS = $ToPath.Split([System.IO.Path]::DirectorySeparatorChar)
    [int]$PopCount = 0
    [int]$MatchCount = [math]::Min($FromDirS.Count, $ToDirS.Count)
    for ($i = 0; $i -lt $MatchCount; $i++) 
    {
        if ($FromDirS[$i] -ne $ToDirS[$i])
        {
            $PopCount = $FromDirS.Count - $i
            $MatchCount = $i
            break
        }
    }

    [string[]]$PushDirS = $null
    if ($MatchCount -lt $ToDirS.Count)
    {
        $PushDirS = $ToDirS[$MatchCount..$($ToDirS.Count - 1)]
    }

    return ($PopCount, $PushDirS)
}

<#
$Dir1 = "C:\Users"
$Dir2 = "C:\Users\David\Documents"
$Dir3 = "C:\Users\David\AppData\Local"

$Dir4 = "C:\Users\David\Documents\Repos\LabelPaq\Pascal\FU_Syst"
$Dir5 = "C:\Users\David\Documents\Repos\LabelPaq\Pascal\FU_Shift"

Find-DirNodeConnection -FromPath $Dir1 -ToPath $Dir1
"1==2"
Find-DirNodeConnection -FromPath $Dir1 -ToPath $Dir2
Find-DirNodeConnection -FromPath $Dir2 -ToPath $Dir1
"2==3"
Find-DirNodeConnection -FromPath $Dir2 -ToPath $Dir3
Find-DirNodeConnection -FromPath $Dir3 -ToPath $Dir2
"4==5"
Find-DirNodeConnection -FromPath $Dir4 -ToPath $Dir5

exit
#>



function Get-DirectoryStats_0
{
    [CmdletBinding()]
    [OutputType([array])]
    param (
        [Parameter(ValueFromPipeline)]
        [object] $Path = ".",

        [Parameter()]
        [array] $Include = $null,

        [Parameter()]
        [array] $Exclude = $null
    )
    
    $RootDir = Get-Item -Path $Path -ErrorAction "Stop"
    $BlockSize = (Get-Volume -FilePath $RootDir).AllocationUnitSize
    $DirStats = [DirStat]::new($RootDir, $BlockSize)
    $InfoStack = New-Object System.Collections.Stack

    if ($Include -or $Exclude)
    {
        # FileS order: Alphabeticlly sorted in descending order (Sub-Dirs & files), takes ~8x longer
        [array]$FileS = Get-ChildItem -File -Path $RootDir -Include $Include -Exclude $Exclude -Recurse -Force -ErrorAction $ErrorActionPreference
    }
    else
    {
        # FileS order: Dont step into sub-dir until first listing all entries (Sub-Dirs then files) in the work-dir
        [array]$FileS = Get-ChildItem -File -Path $RootDir -Recurse -Force -ErrorAction $ErrorActionPreference    
    }

    foreach ($File in $FileS)
    {
        ##//TODO: Find-DirNodeConnection() takes 50% of the total process time
        $PopCount, $PushDirS = Find-DirNodeConnection -FromPath $DirStats.Name -ToPath $File.Directory.FullName

        for ($i = 0; $i -lt $PopCount; $i++)
        {
            $ParentStats = $InfoStack.Pop()
            $ParentStats.AddDirStat($DirStats)
            Write-Output $DirStats
            $DirStats = $ParentStats
        }
        foreach ($SubDir in $PushDirS)
        {
            $InfoStack.Push($DirStats)
            $DirStats = [DirStat]::new($DirStats.Name, $SubDir, $BlockSize)
        }
        $DirStats.AddDirInfo($File)
    }

    while ($InfoStack.Count)
    {
        $ParentStats = $InfoStack.Pop()
        $ParentStats.AddDirStat($DirStats)
        Write-Output $DirStats
        $DirStats = $ParentStats         
    }
    Write-Output $DirStats
}


$Path = "$Home\documents\repos\LabelPaq" #\Pascal"
#$Path = "$Home\documents\repos" #\PsUtils"
#$Path = "C:\Install"
#$Path = "$Home\documents\repos\LabelPaq\Pascal"

<#
(Measure-Command {
        $DirStats = Get-DirectoryStats_0 -Path $Path
    }).Milliseconds
$DirStats.Count
exit
#>

$DirStats = Get-DirectoryStats_0 -Path $Path #-Include "*.pas"
$DirStats | Sort-Object -Descending Name | Format-Table FileLength, TotFileLength, Files, TotFiles, Dirs, TotDirs, Name | Out-String -Width 1024 > "C:\Users\David\Documents\Repos\PsUtils\Wip\x.txt"
$DirStats | Format-Table FileLength, TotFileLength, Files, TotFiles, Dirs, TotDirs, Name | Out-String -Width 1024 > "C:\Users\David\Documents\Repos\PsUtils\Wip\xx.txt"
$DirStats | Format-Table