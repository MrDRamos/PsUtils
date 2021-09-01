
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
    $InfoStack = New-Object System.Collections.Stack
    $ParentStats = [PSCustomObject]@{
        FileLength    = 0
        TotFileLength = 0
        Files         = 0
        TotFiles      = 0
        Dirs          = 0
        TotDirs       = 0
        Name          = $Dir.FullName
    }
    
    foreach ($Dir in $DirS) 
    {
        [array]$FileS = Get-ChildItem -Path $Dir -File -Include $Include -Exclude $Exclude -ErrorAction $ErrorActionPreference
        $FileLen = 0
        foreach ($File in $FileS) 
        {
            $FileLen += $File.Length
        }

        if ($ParentStats.Name -eq $Dir.Parent.FullName)
        {
            $ParentStats.TotFileLength += $FileLen
            $ParentStats.TotFiles += $FileS.Count
            $ParentStats.Dirs++
            $ParentStats.TotDirs++
            $Usage = [PSCustomObject]@{
                FileLength    = $FileLen
                TotFileLength = $FileLen
                Files         = $FileS.Count
                TotFiles      = $FileS.Count
                Dirs          = 0
                TotDirs       = 0
                Name          = $Dir.FullName
            }    
            Write-Output $Usage
        }
        else
        {
            if ($ParentStats.Name -eq $Dir.FullName)
            {   
                # Comming back to Parent-folder - Accumulate subdir info
                $ParentStats.FileLength += $FileLen
                $ParentStats.TotFileLength += $FileLen
                $ParentStats.Files += $FileS.Count
                $ParentStats.TotFiles += $FileS.Count
                $ParentStats.Dirs++
                $ParentStats.TotDirs++
                Write-Output $ParentStats
                if ($InfoStack.Peek().Name -eq $Dir.Parent.FullName)
                {
                    $BaseParentStats = $InfoStack.Pop()
                    $BaseParentStats.TotFileLength += $ParentStats.TotFileLength
                    $BaseParentStats.TotFiles += $ParentStats.TotFiles
                    $BaseParentStats.Dirs++
                    $BaseParentStats.TotDirs += 1 + $ParentStats.TotDirs
                    $ParentStats = $BaseParentStats    
                }
                else # No parent in stack
                {
                    $BaseParentStats = [PSCustomObject]@{
                        FileLength    = 0
                        TotFileLength = $ParentStats.TotFileLength
                        Files         = 0
                        TotFiles      = $ParentStats.TotFiles
                        Dirs          = 0
                        TotDirs       = $ParentStats.TotDirs
                        Name          = $Dir.Parent.FullName
                    }                        
                    $ParentStats = $BaseParentStats    
                }
            }
            else 
            {
                # Going deeper into Sub-folder
                $InfoStack.Push($ParentStats)              
                $ParentStats = [PSCustomObject]@{
                    FileLength    = $FileLen
                    TotFileLength = $FileLen
                    Files         = $FileS.Count
                    TotFiles      = $FileS.Count
                    Dirs          = 0
                    TotDirs       = 0
                    Name          = $Dir.FullName
                }
                Write-Output $ParentStats
                $ParentStats = [PSCustomObject]@{
                    FileLength    = 0
                    TotFileLength = $FileLen
                    Files         = 0
                    TotFiles      = $FileS.Count
                    Dirs          = 0
                    TotDirs       = 0
                    Name          = $Dir.Parent.FullName
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
    $FileLen = 0
    foreach ($File in $FileS) 
    {
        $FileLen += $File.Length
    }
    $ParentStats.FileLength += $FileLen
    $ParentStats.TotFileLength += $FileLen
    $ParentStats.Files += $FileS.Count
    $ParentStats.TotFiles += $FileS.Count
    Write-Output $ParentStats
}
