
function Get-DirectoryStats($Path)
{
    [array] $Include = $null
    [array] $Exclude = $null
    [int]$Depth = -1

    if ($Depth -ge 0)
    {
        $DirS = Get-ChildItem -Depth $Depth -Path $Path -Directory -Recurse -Force -ErrorAction $ErrorActionPreference | Sort-Object -Property FullName -Descending
    }
    else 
    {
        $DirS = Get-ChildItem -Path $Path -Directory -Recurse -Force -ErrorAction $ErrorActionPreference | Sort-Object -Property FullName -Descending
    }

    $Dir = Get-Item -Path $Path -ErrorAction $ErrorActionPreference
    $InfoStack =New-Object System.Collections.Stack
    $ParentStats = [PSCustomObject]@{
        Size = 0
        TotalSize = 0
        Files = 0
        TotalFiles = 0
        Folders = 0
        TotalFolders = 0
        Name = $Dir.FullName
    }
    
    foreach ($Dir in $DirS) 
    {
        [array]$FileS = Get-ChildItem -Path $Dir -File -Include $Include -Exclude $Exclude -ErrorAction $ErrorActionPreference
        $BytesUsed = 0
        foreach ($File in $FileS) 
        {
            $BytesUsed += $File.Length
        }

        if ($ParentStats.Name -eq $Dir.Parent.FullName)
        {
            $ParentStats.TotalSize += $BytesUsed
            $ParentStats.TotalFiles += $FileS.Count
            $ParentStats.Folders++
            $ParentStats.TotalFolders++
            $Usage = [PSCustomObject]@{
                Size = $BytesUsed
                TotalSize = $BytesUsed
                Files = $FileS.Count
                TotalFiles = $FileS.Count
                Folders = 0
                TotalFolders = 0
                Name = $Dir.FullName
            }    
            Write-Output $Usage
        }
        else
        {
            if ($ParentStats.Name -eq $Dir.FullName)
            {   
                # Comming back to Parent-folder - Accumulate subdir info
                $ParentStats.Size += $BytesUsed
                $ParentStats.TotalSize += $BytesUsed
                $ParentStats.Files += $FileS.Count
                $ParentStats.TotalFiles += $FileS.Count
                $ParentStats.Folders++
                $ParentStats.TotalFolders++
                Write-Output $ParentStats
                if ($InfoStack.Peek().Name -eq $Dir.Parent.FullName)
                {
                    $BaseParentStats = $InfoStack.Pop()
                    $BaseParentStats.TotalSize += $ParentStats.TotalSize
                    $BaseParentStats.TotalFiles += $ParentStats.TotalFiles
                    $BaseParentStats.Folders++
                    $BaseParentStats.TotalFolders += 1+ $ParentStats.TotalFolders
                    $ParentStats = $BaseParentStats    
                }
                else # No parent in stack
                {
                    $BaseParentStats = [PSCustomObject]@{
                        Size = 0
                        TotalSize = $ParentStats.TotalSize
                        Files = 0
                        TotalFiles = $ParentStats.TotalFiles
                        Folders = 0
                        TotalFolders = $ParentStats.TotalFolders
                        Name = $Dir.Parent.FullName
                    }                        
                    $ParentStats = $BaseParentStats    
                }
            }
            else 
            {
                # Going deeper into Sub-folder
                $InfoStack.Push($ParentStats)              
                $ParentStats = [PSCustomObject]@{
                    Size = $BytesUsed
                    TotalSize = $BytesUsed
                    Files = $FileS.Count
                    TotalFiles = $FileS.Count
                    Folders = 0
                    TotalFolders = 0
                    Name = $Dir.FullName
                }
                Write-Output $ParentStats
                $ParentStats = [PSCustomObject]@{
                    Size = 0
                    TotalSize = $BytesUsed
                    Files = 0
                    TotalFiles = $FileS.Count
                    Folders = 0
                    TotalFolders = 0
                    Name = $Dir.Parent.FullName
                }
            }
        }    
    }

    if ($InfoStack.Count)
    {
        $ParentStats = $InfoStack.Pop()
    }
    
    # Finally add files root follder
    [array]$FileS = Get-ChildItem -Path $Path -File -Include $Include -Exclude $Exclude -ErrorAction $ErrorActionPreference
    $BytesUsed = 0
    foreach ($File in $FileS) 
    {
        $BytesUsed += $File.Length
    }
    $ParentStats.Size += $BytesUsed
    $ParentStats.TotalSize += $BytesUsed
    $ParentStats.Files+= $FileS.Count
    $ParentStats.TotalFiles+= $FileS.Count
    Write-Output $ParentStats
}
