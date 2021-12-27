
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
function Find-DirNodeConnection2([string]$FromPath, [string]$ToPath, [int]$Offset)
{
    [string[]]$FromDirS = $FromPath.Substring($Offset).Split([System.IO.Path]::DirectorySeparatorChar, [StringSplitOptions]::RemoveEmptyEntries)
    [string[]]$ToDirS = $ToPath.Substring($Offset).Split([System.IO.Path]::DirectorySeparatorChar, [StringSplitOptions]::RemoveEmptyEntries)
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
function Find-DirNodeConnection3([string]$FromPath, [string]$ToPath, [int]$RootDirCount)
{

    [string[]]$FromDirS = $FromPath.Split([System.IO.Path]::DirectorySeparatorChar)
    [string[]]$ToDirS = $ToPath.Split([System.IO.Path]::DirectorySeparatorChar)
    [int]$PopCount = 0
    [int]$MatchCount = [math]::Min($FromDirS.Count, $ToDirS.Count)
    for ([int]$i = $RootDirCount; $i -lt $MatchCount; $i++) 
    {
        if ($FromDirS[$i] -ne $ToDirS[$i])
        {
            $MatchCount = $RootDirCount + $i
            $PopCount = $FromDirS.Count - $MatchCount
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
function Find-DirNodeConnection4([string]$FromPath, [string]$ToPath, [int]$Offset)
{
    [int]$StartPosTo = $Offset
    [int]$MaxPos = [math]::Min($FromPath.Length, $ToPath.Length)
    while ($StartPosTo -lt $MaxPos)
    {
        [int]$EndPos = $FromPath.IndexOf([System.IO.Path]::DirectorySeparatorChar, $StartPosTo)
        [int]$EndPosTo = $ToPath.IndexOf([System.IO.Path]::DirectorySeparatorChar, $StartPosTo)
        if ($EndPos -eq $EndPosTo)
        {
            if (($EndPos -gt 0) -and ([string]::Compare($FromPath, $StartPosTo, $ToPath, $StartPosTo, $EndPos - $StartPosTo) -eq 0))
            {
                $StartPosTo = $EndPos + 1
            }
            else 
            {
                # Improve performance for special case where $FromPath & $ToPath have same parent
                return (1, @($ToPath.Substring($StartPosTo)))
            }
        }
        else 
        {
            break    
        }
    }

    [int]$StartPosFrom = $StartPosTo
    [int]$PopCount = 0
    while ($StartPosFrom -lt $FromPath.Length)
    {
        $PopCount++
        [int]$EndPos = $FromPath.IndexOf([System.IO.Path]::DirectorySeparatorChar, $StartPosFrom)
        if ($EndPos -ge 0)
        {
            $StartPosFrom = $EndPos + 1
        }
        else 
        {
            break    
        }
    }

    [string[]]$PushDirS = $null
    if ($StartPosTo -lt $ToPath.Length)
    {
        $PushDirS = $ToPath.Substring($StartPosTo).Split([System.IO.Path]::DirectorySeparatorChar)
    }

    return ($PopCount, $PushDirS)
}


Add-Type -Language CSharp @"
using System; 
using System.Collections.Generic;

namespace CSharpCode
{
    public static class Helper
    {
        public static (int, string[]) GetNodeRoute(string from, string dest, int offset = 0)
        {
          int matchPos = 0;
          int maxPos = Math.Min(from.Length, dest.Length);
          int i = offset;
          for (; i < maxPos; i++)
          {
            if (from[i] != dest[i])
            {
              break;
            }
            if (from[i] == System.IO.Path.DirectorySeparatorChar)
            {
              matchPos = i +1;
            }
          }
          if (i == maxPos)
          {
            matchPos = maxPos +1;
          }
    
          int popCount = 0;
          if (matchPos < from.Length)
          {
            for (i = matchPos; i < from.Length; i++)
            {
              if (from[i] == System.IO.Path.DirectorySeparatorChar)
              {
                popCount++;
              }
            }
            popCount++;
          }
    
          List<string> pushDirS = new List<string>();
          if (matchPos < dest.Length)
          {
            for (i = matchPos; i < dest.Length; i++)
            {
              if (dest[i] == System.IO.Path.DirectorySeparatorChar)
              {
                pushDirS.Add(dest.Substring(matchPos, i - matchPos));
                matchPos = i +1;
              }
            }
            pushDirS.Add(dest.Substring(matchPos, i - matchPos));
          }
    
          return (popCount, pushDirS.ToArray());
        }
    }
}
"@;
     


<#
$Dir1 = "C:\Users"
$Dir2 = "C:\Users\David\Documents"
$Dir3 = "C:\Users\David\AppData\Local"
$Dir4 = "C:\Users\David\Documents\Repos\LabelPaq\Pascal\FU_Syst"
$Dir5 = "C:\Users\David\Documents\Repos\LabelPaq\Pascal\FU_Shift"

$Offset = $Dir1.Length
$NodeRoute = [CSharpCode.Helper]::GetNodeRoute($Dir3, $Dir4, $Offset)
$PopCount = $NodeRoute[0]; $PushDirS = $NodeRoute[1]
$PopCount; $PushDirS
exit

"-- 1 - 1"
Find-DirNodeConnection4 -FromPath $Dir1 -ToPath $Dir1 -Offset $Offset
"-- 2 - 2"
Find-DirNodeConnection4 -FromPath $Dir1 -ToPath $Dir1 -Offset $Offset
"-- 1 - 2"
Find-DirNodeConnection4 -FromPath $Dir1 -ToPath $Dir2 -Offset $Offset
Find-DirNodeConnection4 -FromPath $Dir2 -ToPath $Dir1 -Offset $Offset
"-- 2 - 3"
Find-DirNodeConnection4 -FromPath $Dir2 -ToPath $Dir3 -Offset $Offset
Find-DirNodeConnection4 -FromPath $Dir3 -ToPath $Dir2 -Offset $Offset
"-- 4 - 5"
Find-DirNodeConnection4 -FromPath $Dir4 -ToPath $Dir5 -Offset $Offset
Find-DirNodeConnection4 -FromPath $Dir5 -ToPath $Dir4 -Offset $Offset

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
    [int]$RootDirLen = $RootDir.FullName.Length +1
    [int]$RootDirCount = $RootDir.FullName.Split([System.IO.Path]::DirectorySeparatorChar).Count
    $BlockSize = 4096
    ##// $BlockSize = (Get-Volume -FilePath $RootDir).AllocationUnitSize ##//TODO Takes 40ms. Find faster API
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

[int] $DirCount = 0 ##// 
    foreach ($File in $FileS)
    {
        #if ($DirStats.Name -ne $File.Directory.FullName)
        if ($DirStats.Name -ne $File.DirectoryName)
        {
            $DirCount++ ##// 
            #<#
            ##//TODO: Find-DirNodeConnection() takes 50% of the total process time
            # $PopCount = 0; $PushDirS = $null; $InfoStack.Push($DirStats); $Null = $InfoStack.Pop(); if (($DirCount % 4) -eq 0) { Write-Output $DirStats }
            # $PopCount, $PushDirS = Find-DirNodeConnection -FromPath $DirStats.Name -ToPath $File.Directory.FullName
            # $PopCount, $PushDirS = Find-DirNodeConnection -FromPath $DirStats.Name -ToPath $File.DirectoryName
            # $PopCount, $PushDirS = Find-DirNodeConnection2 -FromPath $DirStats.Name -ToPath $File.DirectoryName -Offset $RootDirLen
            # $PopCount, $PushDirS = Find-DirNodeConnection3 -FromPath $DirStats.Name -ToPath $File.DirectoryName -RootDirCount $RootDirCount
            # $PopCount, $PushDirS = Find-DirNodeConnection4 -FromPath $DirStats.Name -ToPath $File.DirectoryName -Offset $RootDirLen
            
            $NodeRoute = [CSharpCode.Helper]::GetNodeRoute($DirStats.Name, $File.DirectoryName)#, $RootDirLen)
            $PopCount = $NodeRoute[0]; $PushDirS = $NodeRoute[1]

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
            #>
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
    Write-Host "DirCount: $DirCount/$($FileS.Count)" -ForegroundColor Yellow ##// 
}


$Path = "$Home\documents\repos\LabelPaq" #\Pascal"
#$Path = "$Home\documents\repos" #\PsUtils"
#$Path = "C:\Install"
#$Path = "$Home\documents\repos\LabelPaq\Pascal"

#<#
(Measure-Command {
        $DirStats = Get-DirectoryStats_0 -Path $Path
    }).TotalMilliseconds
$DirStats.Count
exit
#>

$DirStats = Get-DirectoryStats_0 -Path $Path #-Include "*.pas"
$DirStats | Sort-Object -Descending Name | Format-Table FileLength, TotFileLength, Files, TotFiles, Dirs, TotDirs, Name | Out-String -Width 1024 > "C:\Users\David\Documents\Repos\PsUtils\Wip\x.txt"
$DirStats | Format-Table FileLength, TotFileLength, Files, TotFiles, Dirs, TotDirs, Name | Out-String -Width 1024 > "C:\Users\David\Documents\Repos\PsUtils\Wip\xx.txt"
$DirStats | Format-Table