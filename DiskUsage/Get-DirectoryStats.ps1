
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





function Get-DirectoryStats2($Path)
{
    $RootDir = Get-Item -Path $Path -ErrorAction $ErrorActionPreference
    $InfoStack = New-Object System.Collections.Stack
    $WorkDirStats = [PSCustomObject]@{
        FileLength    = 0
        TotFileLength = 0
        Files         = 0
        TotFiles      = 0
        Dirs          = 0
        TotDirs       = 0
        Name          = $RootDir.FullName
        Parent        = $RootDir.Parent.FullName
    }
    $InfoStack.Push(@{$RootDir.FullName = $WorkDirStats })
    $DirStats = @{}

    [array]$FileS = Get-ChildItem -Path $Path -Recurse -Force -ErrorAction $ErrorActionPreference
    foreach ($File in $FileS) 
    {
        if ($File.PSIsContainer)
        {
            $Dir = $File.Parent.FullName
            $Parent = $File.Parent.Parent.FullName
        }
        else 
        {
            $Dir = $File.Directory.FullName        
            $Parent = $File.Directory.Parent.FullName
        }

        if ($Dir -eq $WorkDirStats.Name)
        {
            # Same WorkDir 
            if ($File.PSIsContainer)
            {
                $WorkDirStats.Dirs++
                $WorkDirStats.TotDirs++
                $SubDirStats = [PSCustomObject]@{
                    FileLength    = 0
                    TotFileLength = 0
                    Files         = 0
                    TotFiles      = 0
                    Dirs          = 0
                    TotDirs       = 0
                    Name          = $File.FullName
                    Parent        = $Dir
                }
                $DirStats[$File.FullName] = $SubDirStats
            }
            else 
            {
                $WorkDirStats.FileLength += $File.Length
                $WorkDirStats.TotFileLength += $File.Length
                $WorkDirStats.Files++
                $WorkDirStats.TotFiles++
            }
        }
        else
        {
            if ($Parent -eq $WorkDirStats.Name)
            {
                # Advance WorkDir deeper into one of its sub-directories = $Dir
                $WorkDirStats = $DirStats[$Dir]
                $InfoStack.Push($DirStats)
                $DirStats = @{}

                if ($File.PSIsContainer)
                {
                    $WorkDirStats.Dirs++
                    $WorkDirStats.TotDirs++
                    $SubDirStats = [PSCustomObject]@{
                        FileLength    = 0
                        TotFileLength = 0
                        Files         = 0
                        TotFiles      = 0
                        Dirs          = 0
                        TotDirs       = 0
                        Name          = $File.FullName
                        Parent        = $Dir
                    }
                    $DirStats[$File.FullName] = $SubDirStats
                }
                else 
                {
                    $WorkDirStats.FileLength += $File.Length
                    $WorkDirStats.TotFileLength += $File.Length
                    $WorkDirStats.Files++
                    $WorkDirStats.TotFiles++
                }
            }
            else 
            {
                # Return WorkDir back to one of its parent directories, or siblings(=Dir with same parent)
                if ($DirStats.Count)
                {
                    foreach ($SubStats in $DirStats.Values)
                    {
                        $WorkDirStats.TotFileLength += $SubStats.TotFileLength
                        $WorkDirStats.TotFiles += $SubStats.TotFiles
                        $WorkDirStats.TotDirs += $SubStats.TotDirs

                        if (($SubStats.Files -eq 0) -and ($SubStats.Dirs -eq 0))
                        {
                            # Because we never step into empty dirs, handle that case here
                            Write-Output $SubStats        
                        }
                    }
                }
                Write-Output $WorkDirStats

                # Case: Set WorkDir to sibling i.e. a directiry with same parent = $Dir
                $WorkDirStats = $InfoStack.Peek()[$Dir]
                if ($WorkDirStats)
                {
                    $DirStats = @{}

                    if ($File.PSIsContainer)
                    {
                        $WorkDirStats.Dirs++
                        $WorkDirStats.TotDirs++
                        $SubDirStats = [PSCustomObject]@{
                            FileLength    = 0
                            TotFileLength = 0
                            Files         = 0
                            TotFiles      = 0
                            Dirs          = 0
                            TotDirs       = 0
                            Name          = $File.FullName
                            Parent        = $Dir
                        }
                        $DirStats[$File.FullName] = $SubDirStats
                    }
                    else 
                    {
                        $WorkDirStats.FileLength += $File.Length
                        $WorkDirStats.TotFileLength += $File.Length
                        $WorkDirStats.Files++
                        $WorkDirStats.TotFiles++
                    }
                }
                else
                {    
                    # Case: Set WorkDir back to a parent thats one or more levels up in the hierarchy
                    do
                    {
                        $DirStats = $InfoStack.Pop()
                        $ParentDirStats = $InfoStack.Peek()
                        foreach ($SubStats in $DirStats.Values)
                        {
                            if (!$WorkDirStats)
                            {
                                $WorkDirStats = $ParentDirStats[$SubStats.Parent]
                            }
                            $WorkDirStats.TotFileLength += $SubStats.TotFileLength
                            $WorkDirStats.TotFiles += $SubStats.TotFiles
                            $WorkDirStats.TotDirs += $SubStats.TotDirs

                            if (($SubStats.Files -eq 0) -and ($SubStats.Dirs -eq 0))
                            {
                                # Because we never step into empty dirs, handle that case here
                                Write-Output $SubStats        
                            }
                        }
                        Write-Output $WorkDirStats              

                        $WorkDirStats = $ParentDirStats[$Dir]
                    } until ($WorkDirStats)
                    $DirStats = @{}

                    if ($File.PSIsContainer)
                    {
                        $WorkDirStats.Dirs++
                        $WorkDirStats.TotDirs++
                        $SubDirStats = [PSCustomObject]@{
                            FileLength    = 0
                            TotFileLength = 0
                            Files         = 0
                            TotFiles      = 0
                            Dirs          = 0
                            TotDirs       = 0
                            Name          = $File.FullName
                            Parent        = $Dir
                        }
                        $DirStats[$File.FullName] = $SubDirStats
                    }
                    else 
                    {
                        $WorkDirStats.FileLength += $File.Length
                        $WorkDirStats.TotFileLength += $File.Length
                        $WorkDirStats.Files++
                        $WorkDirStats.TotFiles++
                    }
                }
            }
        }
    }

    Write-Output $WorkDirStats
    $Dir = $RootDir.FullName
    $WorkDirStats = $null
    do
    {
        $DirStats = $InfoStack.Pop()
        $ParentDirStats = $InfoStack.Peek()
        foreach ($SubStats in $DirStats.Values)
        {
            if (!$WorkDirStats)
            {
                $WorkDirStats = $ParentDirStats[$SubStats.Parent]
            }
            $WorkDirStats.TotFileLength += $SubStats.TotFileLength
            $WorkDirStats.TotFiles += $SubStats.TotFiles
            $WorkDirStats.TotDirs += $SubStats.TotDirs

            if (($SubStats.Files -eq 0) -and ($SubStats.Dirs -eq 0))
            {
                # Because we never step into empty dirs, handle that case here
                Write-Output $SubStats        
            }
        }
        Write-Output $WorkDirStats
        $WorkDirStats = $ParentDirStats[$Dir]
    } until ($WorkDirStats)
}
