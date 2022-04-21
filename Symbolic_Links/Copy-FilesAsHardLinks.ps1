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
Make hard linked copies of all the files in C:\tmp into the new folder C:\tmp_test
Copy-FilesAsHardlinks -Path 'C:\tmp'   -Destination 'C:\tmp_test'
Copy-FilesAsHardlinks -Path 'C:\tmp\*' -Destination 'C:\tmp_test'

.EXAMPLE
Copy the sub directory structure from C:\tmp to C:\tmp_test and recursively make 
hard link copies of the source files into the respective destination directories.
Copy-FilesAsHardlinks -Path 'C:\tmp' -Destination 'C:\tmp_test' -Recurse

.EXAMPLE
Copy the sub directory structure from C:\tmp to C:\tmp_test and recursively make 
hard link copies of the '*.txt' source files into the respective destination directories.
Copy-FilesAsHardlinks -Path 'C:\tmp' -Include '*.txt' -Destination 'C:\tmp_test' -Recurse

.EXAMPLE
Test what what hard links would be created with -Whatif
Copy-FilesAsHardlinks -Path 'C:\tmp\*.txt' -Destination 'C:\tmp_test' -Whatif

.EXAMPLE
Make hard linked copies of the *.txt files in C:\tmp to the new folder C:\tmp_test
Copy-FilesAsHardlinks -Path 'C:\tmp\*.txt'            -Destination 'C:\tmp_test'
Copy-FilesAsHardlinks -Path 'C:\tmp' -Include '*.txt' -Destination 'C:\tmp_test'



.PARAMETER Path
Specifies, as a string array, the path to the source items to copy. Wildcard characters 
are permitted. The path parameter can specify one or more files or folders or both,
by using wildcard patterns. The default wildcard Path pattern is '*', whoch selects all 
files and folders found in the top level folder of the path.
Note: The Wildcard patterns, Filter, Include & Exclude parameters only apply to the 
top level folder of the path parameter, and do not apply to files & folders discovered
while recursing child folders, just like Copy-Intem().

.PARAMETER Destination
Specifies a path to the folder into which the source files & folders are copied. 
The default is the current directory. The Destination folder should exist before
the call, but new recursed sub-directories are automtically created 'normally' if 
they do not exist, i.e. they are NOT sym-linked to the source folder.
New files are NOT copied but are hard linked to the source file. That is how this
function differs from Copy-Item().

.PARAMETER Include
The Include pattern is a secondary filter that is applied to the files & folders that 
were selected by the wildcard pattern of the Path parameter, note the default wildcard 
Path pattern is '*'. It only applies to the entries found in the top level folder of 
Path parameter, i.e. it is not applied to files & folders discovered when recursing
through child folders.

.PARAMETER Exclude
The Exclude pattern is a secondary filter that is applied to the files & folders that 
were selected by the wildcard pattern of the Path parameter, note the default wildcard 
Path pattern is '*'. It only applies to the entries found in the top level folder of 
Path parameter, i.e. it is not applied to files & folders discovered when recursing
through child folders.

.PARAMETER Filter
An additional wildcard pattern to qualify the files & folders selected by the first
wildcard pattern of the Path parameter, note the default wildcard Path pattern is '*'. 
Note: Using a native file system Filter pattern is more efficient than using Include 
and Exclude lists.

.PARAMETER Recurse
Switch to recursively re-create the file & folder structure of the source Path.
New files under the Destination path are hard linked, i.e not copied. But new folders 
are created normally, i.e. they not sym-linked to the source folder.
Note: This parameter is ignored if the source Path wildcard pattern only selects 
files and no directories, e.g. C:\tmp\*.txt

.PARAMETER Force
Overwrite any pre-existing files in the destination directory with the new hard link.

.PARAMETER PassThru
Returns the created destiation files. By default, this cmdlet doesn't generate any output
#>
function Copy-FilesAsHardlinks
{
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([System.IO.FileInfo], [System.IO.DirectoryInfo])]
    param (
        [Parameter(Mandatory, ValueFromPipeline, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string] $Path,

        [Parameter(Position = 1)]
        [string] $Destination = $null,

        [Parameter()]
        [string[]] $Include = $null,

        [Parameter()]
        [string[]] $Exclude = $null,

        [Parameter()]
        [string] $Filter = $null,

        [Parameter()]
        [switch] $Recurse,

        [Parameter()]
        [switch] $Force,

        [Parameter()]
        [switch] $PassThru
    )   

    process 
    {
        function Copy_DirsLinkFiles([array]$SrcItemS, [int] $RelRelPathLen)
        {
            if ($SrcItemS)
            {
                # Create new sub-directories
                [array]$SrcDirS = $SrcItemS | Where-Object { $_.PSIsContainer }
                foreach ($SrcDir in $SrcDirS)
                {
                    $DstPath = $DstFolder + $SrcDir.FullName.Substring($RelPathLen)
                    if (!(Test-Path -Path $DstPath))
                    {
                        $NewDir = New-Item -ItemType Directory -Path $DstPath
                        if ($PassThru)
                        {
                            Write-Output $NewDir # foward to pipeline
                        }
                    }
                }
            
                # Create hard linked files
                [array]$SrcFileS = $SrcItemS | Where-Object { !$_.PSIsContainer }
                foreach ($SrcFile in $SrcFileS) 
                {
                    $DstPath = $DstFolder + $SrcFile.FullName.Substring($RelPathLen)
                    $NewLink = New-Item -ItemType HardLink -Path $DstPath -Target $SrcFile.FullName -Force:$Force
                    if ($PassThru)
                    {
                        Write-Output $NewLink # foward to pipeline
                    }
                }
            }
        }
        
        $DstFolder = $Destination
        [array]$BaseDirS = @()
        $PathHasPattern = Test-Path -Path $Path -PathType Leaf
        if ($PathHasPattern -or $Filter -or $Include -or $Exclude)
        {
            $Folder = $Path
            if ($PathHasPattern)
            {
                $Folder = Split-Path -Path $Path -Parent
            }
            $PathFolder = Resolve-Path -Path $Folder
            $RelPathLen = $PathFolder.Path.Length

            # Processs files in root folder specified by the wildcard pattern
            $SrcItemS = Get-ChildItem -Path $Path -Include $Include -Exclude $Exclude -Filter $Filter
            Copy_DirsLinkFiles -SrcItemS $SrcItemS -RelPathLen $RelPathLen

            # Get sub-directories specified by the wildcard pattern
            if ($Recurse)
            {
                $BaseDirS += $SrcItemS | Where-Object { $_.PSIsContainer }
            }
        }
        else 
        {
            $PathFolder = Resolve-Path -Path $Path
            $RelPathLen = $PathFolder.Path.Length
            [array]$BaseDirS = Get-Item -Path $PathFolder
            if (Test-Path -Path $Destination)
            {
                # This logic is for compatibility with Copy-Item()
                $DstFolder = Join-Path -Path $Destination -ChildPath (Split-Path -Path $PathFolder.Path -Leaf)
            }
        }

        if ($BaseDirS)
        {
            if ($Recurse)
            {
                $SubDirS = @()
                foreach ($SrcDir in $BaseDirS)
                {
                    $SubDirS += Get-ChildItem -Recurse -Path $SrcDir.FullName -Directory
                }
                $BaseDirS += $SubDirS
            }

            if (!(Test-Path -Path $DstFolder))
            {
                $NewDir = New-Item -ItemType Directory -Path $DstFolder -Force:$Force
                if ($PassThru)
                {
                    Write-Output $NewDir # foward to pipeline
                }
            }

            foreach ($SrcDir in $BaseDirS)
            {
                [array]$SrcItemS = Get-ChildItem -Path $SrcDir.FullName -Force #include hidden files
                Copy_DirsLinkFiles -SrcItemS $SrcItemS -RelPathLen $RelPathLen
            }
        }
    }
}
