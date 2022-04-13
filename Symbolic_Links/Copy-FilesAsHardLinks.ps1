<#
.SYNOPSIS
This function can clone a source directory structure similar to Copy-Item() but instead of copying the 
files it will make hard links to the source files. The destination folder will not consume additional
hard disk space for the files, only for the new directory entries. Using hard linked files has the 
advantage that deleting the original source file will not effect the hard linked copy. Contrast that 
to the action of deleting the original file pointed to by a symbolic directory or file link which will 
invalidate/break the symlink file in the destination directory.

.DESCRIPTION
A hard link is a directory entry for a file. Every file can be considered to have at least one hard link.
On NTFS volumes, each file can have multiple hard links, so a single file can appear in many directories 
(or even in the same directory with different names). Because all of the links reference the same file, 
programs can open any of the links and modify the file. A file is deleted from the file system only after 
all links to it have been deleted. After you create a hard link, programs can use it like any other file name.

NOTE:
Winsows hard links only work for files in the same logical disk volume, i.e the same NTFS file system.

NOTE:
The file to link to must have write permissions or else the link attempt will fail with an exception

NOTE:
Hard link ACL's & attributes are properties of the actual file system entry, which is the same for all 
linked references. That means if you change the permissions/owner/attributes on one hard link, you will 
immediately see the changes on all the other hard links.

NOTE:
The windows FileSystem utility: fsutil.exe can be used to manage hard linked files:
https://docs.microsoft.com/en-us/windows-server/administration/windows-commands/fsutil-hardlink

.EXAMPLE
Copy-FilesAsHardlinks -SourceDir "$ENV:LOCALAPPDATA\Microsoft\Media Player" -DestinationDir "$ENV:TMP\HardLink_Test\Media Player" -Recurse

.PARAMETER SourceDir
Path to the directory containing the orignal files which are the target of the new hard link.

.PARAMETER DestinationDir
The directory in which the new hard link file entries will be made. 
The destination directory is created if it does not exist, (like Copy-Item)

.PARAMETER Include
An optional file filter to use (like Copy-Item) example: @('*.dll' , '*.exe'), 

.PARAMETER Exclude
An optional file exlusion filter to use (like Copy-Item) example: example: @('*.config' , '*.ini')

.PARAMETER Recurse
Recursively hard link all the files in subfolders

.PARAMETER Force
Overwrite any pre-existing files in the destination directory with the new hard link.
#>
function Copy-FilesAsHardlinks
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [Object] $SourceDir,

        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [Object] $DestinationDir,

        [Parameter()]
        [string[]] $Include = $null,

        [Parameter()]
        [string[]] $Exclude = $null,

        [Parameter()]
        [switch] $Recurse,

        [Parameter()]
        [switch] $Force
    )

    $SourceDir = (Resolve-Path -Path $SourceDir).Path.TrimEnd([System.IO.Path]::DirectorySeparatorChar)
    $SourceDirLen = $SourceDir.Length
    [array]$SrcDirS = Get-Item -Path $SourceDir
    if ($Recurse)
    {
        $SrcDirS += Get-ChildItem -Recurse -Path $SourceDir -Directory
    }

    foreach ($SrcDir in $SrcDirS.FullName)
    {
        $RelPath = $SrcDir.Substring($SourceDirLen)
        $DstDir = $DestinationDir + $RelPath
        if (!(Test-Path -Path $DstDir))
        {
            $null = New-Item -Path $DstDir -ItemType Directory
        }

        $SrcPath = $SrcDir + [System.IO.Path]::DirectorySeparatorChar + '*'
        $SrcFileS = Get-ChildItem -Path $SrcPath -Include $Include -Exclude $Exclude -File -Force #include hidden files
        foreach ($SrcFile in $SrcFileS) 
        {
            $null = New-Item -ItemType HardLink -Path $DstDir -Name $SrcFile.Name -Target $SrcFile.FullName -Force:$Force
        }    
    }
}


<####  Unit test ####
$TestBigDir = $false
#$TestBigDir = $true
if ($TestBigDir)
{
    $SrcDir = "$ENV:USERPROFILE\.vscode"   # Has 10K+ files in 2K+ SubDirectories
    $DstDir = "$ENV:TMP\HardLink_Test\.vscode"
    $Exclude = @('*.dll', '*.exe', '*.pdb')  # Exclude files loaded by vscode runtime so that we can remove the hardlinks when running this test from within VsCode
}
else 
{
    $SrcDir = "$ENV:LOCALAPPDATA\Microsoft\Media Player"    # Has only a few files folders
    $DstDir = "$ENV:TMP\HardLink_Test\Media Player"
}


# Exclude DLL's 
Copy-FilesAsHardlinks -SourceDir $SrcDir -DestinationDir $DstDir -Exclude $Exclude -Recurse -Force -ErrorAction 'Stop' #'SilentlyContinue'
Wait-Debugger  ##DD un-comment to debug
& tree $DstDir
[array]$TestFile = Get-ChildItem -Path $DstDir -File
if ($TestFile)
{
    'Sample file links:'
    & fsutil.exe hardlink list $TestFile[0].FullName
}
Write-Host "Remove-Item -Path '$DstDir' -Recurse -Force" -ForegroundColor Cyan
#>
