
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



class StrCmp
{
    [int] Find_CommonSubStr([string]$Str1, [string]$Str2)
    {
        $MaxLen = [math]::Min($Str1.Length, $Str2.Length)   
        for ($i = 0; $i -lt $MaxLen; $i++) 
        {
            if ($Str1[$i] -ne $Str2[$i])
            {
                return $i
            }
        }
        return $i
    }
}

function Find-CommonSubStr([string]$Str1, [string]$Str2)
{
    $MaxLen = [math]::Min($Str1.Length, $Str2.Length)   
    for ($i = 0; $i -lt $MaxLen; $i++) 
    {
        if ($Str1[$i] -ne $Str2[$i])
        {
            return $i
        }
    }
    return $i
}



function Find-DirNodeConnection([string]$FromPath, [string]$ToPath)
{
    $len = Find-CommonSubStr -Str1 $FromPath -Str2 $ToPath
    $PopCount = 0
    if ($len -lt $FromPath.Length)
    {
        if ($len -and ($FromPath[$len] -eq [System.IO.Path]::DirectorySeparatorChar))
        {
            $len++
        }
        $PopCount = $FromPath.Substring($len).Split([System.IO.Path]::DirectorySeparatorChar).Count
    }

    [string[]]$ToNodeS = $null
    if ($len -lt $ToPath.Length)
    {
        if ($len -and ($ToPath[$len] -eq [System.IO.Path]::DirectorySeparatorChar))
        {
            $len++
        }
        $ToNodeS = $ToPath.Substring($len).Split([System.IO.Path]::DirectorySeparatorChar)
    }
   
    return ($PopCount, $ToNodeS)
}
#<#
$Dir1 = "C:\Users"
$Dir2 = "C:\Users\David\Documents"
$Dir3 = "C:\Users\David\AppData\Local"

$Dir4 = "C:\Users\David\Documents\Repos\LabelPaq\Pascal\FU_Syst"
$Dir5 = "C:\Users\David\Documents\Repos\LabelPaq\Pascal\FU_Shift"
"4==5"
Find-DirNodeConnection -FromPath $Dir4 -ToPath $Dir5

Find-DirNodeConnection -FromPath $Dir1 -ToPath $Dir1
"1==2"
Find-DirNodeConnection -FromPath $Dir1 -ToPath $Dir2
Find-DirNodeConnection -FromPath $Dir2 -ToPath $Dir1
"2==3"
Find-DirNodeConnection -FromPath $Dir2 -ToPath $Dir3
Find-DirNodeConnection -FromPath $Dir3 -ToPath $Dir2

exit
#>



function Get-DirectoryStats
{
    [CmdletBinding()]
    [OutputType([array])]
    param (
        [Parameter(ValueFromPipeline)]
        [object] $Path = ".",

        [Parameter()]
        [array] $Exclude = $null
    )
    
    $RootDir = Get-Item -Path $Path -ErrorAction "Stop"

    $BlockSize = (Get-Volume -FilePath $RootDir).AllocationUnitSize
    $DirStats = [DirStat]::new($RootDir, $BlockSize)

    $InfoStack = New-Object System.Collections.Stack
    $InfoStack.Push($DirStats)

    if ($Include -or $Exclude)
    {
        # FileS order: Alphabeticlly sorted in descending order (Sub-Dirs & files), takes ~8x longer
        [array]$FileS = Get-ChildItem -File -Path $RootDir -Exclude $Exclude -Recurse -Force -ErrorAction $ErrorActionPreference
    }
    else 
    {
        # FileS order: Dont step into sub-dir until first listing all entries (Sub-Dirs then files) in the work-dir
        [array]$FileS = Get-ChildItem -File -Path $RootDir -Recurse -Force -ErrorAction $ErrorActionPreference    
    }

    foreach ($File in $FileS) 
    {
        $NodeDiff = Find-DirNodeConnection -FromPath $DirStats.Name -ToPath $File.Directory.FullName
        for ($i = 0; $i -lt $NodeDiff[0]; $i++) 
        {
            $ParentStats = $InfoStack.Pop()
            $ParentStats.AddDirStat($DirStats)
            Write-Output $DirStats
            $DirStats = $ParentStats
        }
        foreach ($SubDir in $NodeDiff[1]) 
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
}


$Path = "$Home\documents\repos\LabelPaq" #\Pascal"
#$Path = "$Home\documents\repos" #\PsUtils"
#$Path = "C:\Install"
#$Path = "$Home\documents\repos\LabelPaq\Pascal"

(Measure-Command {
        $DirStats = Get-DirectoryStats -Path $Path
    }).Milliseconds
$DirStats.Count
exit

$DirStats = Get-DirectoryStats -Path $Path
$DirStats | Sort-Object -Descending Name | Format-Table FileLength, TotFileLength, Files, TotFiles, Dirs, TotDirs, Name | Out-String -Width 1024 | tee "C:\Users\David\Documents\Repos\PsUtils\Wip\x.txt"
$DirStats | Format-Table FileLength, TotFileLength, Files, TotFiles, Dirs, TotDirs, Name | Out-String -Width 1024 | tee "C:\Users\David\Documents\Repos\PsUtils\Wip\xx.txt"
