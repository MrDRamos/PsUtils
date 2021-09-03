
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

    if ($Include -or $Exclude)
    {
        # FileS order: Alphabeticlly sorted in descending order (Sub-Dirs & files), takes ~8x longer
        [array]$FileS = Get-ChildItem -Path $Path -Exclude $Exclude -Recurse -Force -ErrorAction $ErrorActionPreference
    }
    else 
    {
        # FileS order: Dont step into sub-dir until first listing all entries (Sub-Dirs then files) in the work-dir
        [array]$FileS = Get-ChildItem -Path $Path -Recurse -Force -ErrorAction $ErrorActionPreference    
    }

    
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
            <#
            elseif ($Parent.IndexOf($WorkDirStats.Name, [StringComparison]::OrdinalIgnoreCase) -eq 0)
            {
                # Only relavent when $Include paramters caused skipping a subdir
                $WorkDirStats = [PSCustomObject]@{
                    FileLength    = $File.Length
                    TotFileLength = $File.Length
                    Files         = 1
                    TotFiles      = 1
                    Dirs          = 0
                    TotDirs       = 0
                    Name          = $Dir
                    Parent        = $Parent
                }
                $DirStats[$Dir] = $WorkDirStats
                $InfoStack.Push($DirStats)
                $DirStats = @{}
            }
            #>

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

                # Case: File is a new sibling directory i.e. with same parent as $Dir. 
                # Only get this case with -Exclude/Inlcude option -i.e. when proceccing a file before its parent folder
                if ($WorkDirStats.Parent -eq $Dir)
                {
                    if ($File.PSIsContainer)
                    {
                        $DirStats = $InfoStack.Pop()
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

                        $WorkDirStats = $InfoStack.Peek()[$Dir]
                        $WorkDirStats.Dirs++
                        $WorkDirStats.TotDirs++
                        continue
                    }
                }

                # Case: Set WorkDir to sibling i.e. a directiry with same parent as $Dir
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
                        if ($WorkDirStats.Name -ne $Dir)
                        {
                            Write-Output $WorkDirStats
                        }
                        else 
                        {
                            # Dont Write-Output if we are not yet done preccesing all entries in work-dir = $Dir 
                        }

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
    if ($WorkDirStats.Name -ne $RootDir.FullName)
    {
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
}
