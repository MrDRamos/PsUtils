
<#
PowerShell 4.0 and PowerShell Core do not populate the File.Target property with 
the hard linked files as all the PowerShell 5 versions do. 
This C# code P/Invokes into the native win32 API's FindFirstFileNameW(), FindNextFileNameW()
to retrieve the hardlinks targets.

Credit: Michael Klement Apr 2021
Issue: Powershell v7.2.0-preview.4 file Hard Link .Target get nothing #15139
Uri: https://github.com/PowerShell/PowerShell/issues/15139
#>
Add-Type -Namespace WinUtil -Name NTFS -UsingNamespace System.Text, System.Collections.Generic, System.IO -MemberDefinition @'
    #region WinAPI P/Invoke declarations
    [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    static extern IntPtr FindFirstFileNameW(string lpFileName, uint dwFlags, ref uint StringLength, StringBuilder LinkName);

    [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    static extern bool FindNextFileNameW(IntPtr hFindStream, ref uint StringLength, StringBuilder LinkName);

    [DllImport("kernel32.dll", SetLastError = true)]
    static extern bool FindClose(IntPtr hFindFile);

    [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    static extern bool GetVolumePathName(string lpszFileName, [Out] StringBuilder lpszVolumePathName, uint cchBufferLength);

    public static readonly IntPtr INVALID_HANDLE_VALUE = (IntPtr)(-1); // 0xffffffff;
    public const int MAX_PATH = 65535; // Max. NTFS path length.
    #endregion

    /// <summary>
    //// Returns the enumeration of hardlinks for the given *file* as full file paths, if any,
    //// excluding the input file itself.
    /// </summary>
    /// <remarks>
    /// If the file has only one hardlink (itself) or the target volume doesn't support enumerating hardlinks,
    /// an emtpty sting array is returned.
    /// An exception occurs if you specify a non-existent path or a path to a
    /// directory (directories don't support hardlinks)
    /// </remarks>
    public static string[] GetHardLinks(string filePath)
    {
      string fullFilePath = Path.GetFullPath(filePath);
      if (Directory.Exists(fullFilePath))
      {
        throw new ArgumentException("Only files support hardlinks, \"" + filePath + "\" is a directory.");
      }
      StringBuilder sbPath = new StringBuilder(MAX_PATH);
      uint charCount = (uint)sbPath.Capacity; // in/out character-count variable for the WinAPI calls.
      // Get the volume (drive) part of the target file's full path (e.g., @"C:\")
      GetVolumePathName(fullFilePath, sbPath, (uint)sbPath.Capacity);
      string volume = sbPath.ToString();
      // Trim the trailing "\" from the volume path, to enable simple concatenation
      // with the volume-relative paths returned by the FindFirstFileNameW() and FindFirstFileNameW() functions,
      // which have a leading "\"
      volume = volume.Substring(0, volume.Length > 0 ? volume.Length - 1 : 0);
      // Loop over and collect all hard links as their full paths.
      IntPtr findHandle;
      if (INVALID_HANDLE_VALUE == (findHandle = FindFirstFileNameW(fullFilePath, 0, ref charCount, sbPath)))
      {
        if (! File.Exists(fullFilePath))
        {
          throw new FileNotFoundException("File not found: " + filePath);
        }
        // Otherwise: the target volume doesn't support enumerating hardlinks.
        return Array.Empty<string>();
      }
      List<string> links = new List<string>();
      do
      {
        string fullHardlinkPath = volume + sbPath.ToString();
        if (! fullHardlinkPath.Equals(fullFilePath, StringComparison.OrdinalIgnoreCase)) 
        {
          links.Add(fullHardlinkPath); // Add the full path to the result list.
        }
        charCount = (uint)sbPath.Capacity; // Prepare for the next FindNextFileNameW() call.
      } while (FindNextFileNameW(findHandle, ref charCount, sbPath));
      FindClose(findHandle);
      return links.ToArray();
    }
'@

<#
The following adds a .HardLinks ETS property to System.IO.FileInfo instances (only on for files, 
given that directories don't support hardlinks). Only on Windows, Unix isn't supported.
#>
<#
Update-TypeData -Force -TypeName System.IO.FileInfo -MemberName HardLinks -MemberType ScriptProperty -Value {
    if ($env:OS -ne 'Windows_NT')
    { 
        # Note: throw and Write-Error are quietly ignored in a ScriptProperty script block.
        Write-Warning "The .HardLinks property is only supported on Windows." 
        return [string[]] @()
    }
    [WinUtil.NTFS]::GetHardLinks($this.FullName)  
}
#>


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
        [Parameter(ValueFromPipeline, Position = 0, ParameterSetName = "ByFile")]
        [System.IO.FileInfo[]] $File = $null,

        [Parameter(ValueFromPipeline, Position = 0, ParameterSetName = "ByPath")]
        [string[]] $Path = $null
    )

    # $Input is an automatic variable that references the pipeline value
    if ($Input)
    {
        $InpList = $Input
        if ($InpList[0] -is [System.IO.FileInfo])
        {
            $File = [System.IO.FileInfo[]]$InpList
        }
        else 
        {        
            $Path = [string[]]$InpList
        }
    }
    if ($Path)
    {
        $File = Get-Item -Path $Path
    }

    foreach ($Item in $File) 
    {
        if ($Item -and $Item.LinkType -eq 'HardLink')
        {
            if ($Item.Target)
            {
                Write-Output $Item.Target
            }
            else 
            {
                Write-Output [WinUtil.NTFS]::GetHardLinks($Item.FullName)                
            }
        }        
    }
}



<#
.SYNOPSIS
Deletes the specified file, simular to Remove-Item, with special handling of hard linked files 
which may be locked by external processes. Passing a folder location as the Path argument with
the -Recurse switch will delete all the hard linked files but also all the other folder contents 
just like Remove-Item().

.PARAMETER Path
Specifies one or more locations with files & folders to remove. Wildcard characters are permitted.
Accepeted as pipeline input.

.PARAMETER File
Specifies one or more file objects to remove. The file object are of type: [System.IO.FileInfo]
i.e. the files returned by the Get-ChildItem() or the Get-HardLinks() function. 
Note: Powershell will automatically typecast a filename string to a [System.IO.FileInfo] object.
Pipeline input is also accepted.

.PARAMETER Recurse
Recursively removes all hard lined files in (and under) the specified Path.

.EXAMPLE
Delete all contents in the specified parent folder, but the parent folder itself is not deleted.
Remove-HardLinks -Path C:\Folder_With_Lined_Files\* -Recurse

.EXAMPLE
Delete all parent folder and all its content,
Remove-HardLinks -Path C:\Folder_With_Lined_Files -Recurse

.EXAMPLE
Use Get-HardLinks() to retrieve some hard linked file objects which are then piped to Remove-HardLinks()
Get-HardLinks -Path C:\Folder_With_Lined_Files -Include *.dll,*.ece -Recurse | Remove-HardLinks
#>
function Remove-HardLinks
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline, Position = 0, ParameterSetName = "ByFile")]
        [System.IO.FileInfo[]] $File,

        [Parameter(Mandatory, ValueFromPipeline, Position = 0, ParameterSetName = "ByPath")]
        [string[]] $Path,

        [Parameter()]
        [string[]] $Include = $null,

        [Parameter()]
        [string[]] $Exclude = $null,

        [Parameter()]
        [string] $Filter = $null,

        [Parameter()]
        [switch] $Recurse
    )

    function Delete_File([System.IO.FileInfo] $FileInfo)
    {
        if ($FileInfo.LinkType -eq 'HardLink')
        {
            if ($FileInfo.Target) # PowerShell 5.x
            {                        
                $FileInfo.MoveTo($FileInfo.Target[0])
            }
            else # PowerShell Core
            {
                $TargetS = [WinUtil.NTFS]::GetHardLinks($FileInfo.FullName)
                if ($TargetS)
                {
                    $FileInfo.MoveTo($TargetS[0])
                }                
            }
        }
        else
        {
            $FileInfo.Delete()    
        }
    }


    # $Input is an automatic variable that references the pipeline value
    if ($Input)
    {
        $InpList = $Input
        if ($InpList[0] -is [System.IO.FileInfo])
        {
            $File = [System.IO.FileInfo[]]$InpList
        }
        else 
        {        
            $Path = [string[]]$InpList
        }
    }

    if ($File)
    {
        foreach ($Item in $File)
        {
            Delete_File -FileInfo $Item
        }
        return
    }

    foreach ($PathI in $Path) 
    {
        if ($PathI)
        {   
            # Phase 1 - Remove files, Handling linked files separately
            $ChildFolderS = [System.Collections.ArrayList]::new()
            [array]$ChildItemS = Get-ChildItem -Path $PathI -Include $Include -Exclude $Exclude -Filter $Filter -Recurse:$Recurse
            foreach ($Item in $ChildItemS)
            {
                if ($Item -is [System.IO.FileInfo])
                {
                    Delete_File -FileInfo $Item
                }
                else # Delay removal of folders until all the files have been removed 
                {                    
                    $null = $ChildFolderS.Add($Item)    
                }
            }

            # Phase 2 - Remove any folders included in $ChildItemS (= Wildcard,Filter,Include & Exclude specs)
            if ($ChildFolderS)
            {
                # Delete the deepest child folders first
                # The output from Get-ChildItem returned them in reversed dependency order
                $ChildFolderS.Reverse()
                # $ChildFolderS = $ChildFolderS| Sort-Object -Property FullName -Descending
                foreach ($Folder in $ChildFolderS) 
                {
                    $Folder.Delete()
                }
            }

            # Phase 3 - Include the Parent folder ?
            [array]$Parent = Resolve-Path -Path $PathI -ErrorAction Ignore # Ignore errors if PathI is a deleted file
            if ($Parent -and $Parent.Count -eq 1)
            {
                Remove-Item -Path $Parent -Recurse:$Recurse
            }
        }        
    }
}
