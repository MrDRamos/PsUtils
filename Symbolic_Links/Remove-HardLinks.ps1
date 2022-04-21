
<#
PowerShell 4.0 and PowerShell Core di not populate the File.Target property with 
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
        [Parameter(ValueFromPipeline)]
        [System.IO.FileInfo] $File
    )

    if ($File -and $File.LinkType -eq 'HardLink')
    {
        if ($File.Target)
        {
            return $File.Target
        }
        return [WinUtil.NTFS]::GetHardLinks($File.FullName)
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
                # PowerShell 5.x
                $File.MoveTo($File.Target[0])
            }
            else 
            {
                $TargetS = [WinUtil.NTFS]::GetHardLinks($File.FullName)
                if ($TargetS)
                {
                    $File.MoveTo($TargetS[0])
                }                
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
.SYNOPSIS
This function removes the hard linked tree structure created by Copy-FilesAsHardlinks()

.PARAMETER Path
A path to the folder containing the files to delete.

.PARAMETER Recurse
Recursively removes all hard lined files in (and under) the specified Path.
#>
function Remove-Hardlinks
{
    [CmdletBinding(DefaultParameterSetName = 'ByTargetDir')]
    param (
        [Parameter(Mandatory, ValueFromPipeline, Position = 0)]
        [string] $Path,

        [Parameter()]
        [switch] $Recurse
    )

    process 
    {
        if (Test-Path -Path $Path)
        {   
            [array]$FileS = Get-ChildItem -Path $Path -Recurse:$Recurse -File
            Remove-Hardlink -Path $FileS
                        
            if ($Recurse -and (Test-Path -Path $Path -PathType Container) )
            {
                Remove-Item -Path $Path -Recurse
            }
        }
    }
}
